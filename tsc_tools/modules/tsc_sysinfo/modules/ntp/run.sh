#!/bin/bash
#
# 检查对时配置
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="检查对时配置"
module_name=$(basename "${CUR_DIR}")
datetime="$(date +'%Y%m%d%H%M%S')"

# 检查引入 func
if [[ ! "$(type -t LOGINFO)" == "function" ]]; then
    if [[ -d "${WORK_DIR}" ]]; then
        source "${WORK_DIR}"/bin/func &>/dev/null
    else
        source "${CUR_DIR}"/../../bin/func &>/dev/null
    fi
fi
if [[ ! "$(type -t LOGDELIVERY)" == "function" ]]; then
    if [[ -d "${WORK_DIR}" ]]; then
        source "${WORK_DIR}"/bin/tsc_sysinfo_func.sh &>/dev/null
    else
        source "${CUR_DIR}"/../../bin/tsc_sysinfo_func.sh &>/dev/null
    fi
fi
LOGINFO "${module_cname}"

if [[ -z "${RESULT_DIR}" ]]; then
    result_dir=${CUR_DIR}/log/${datetime}/
else
    result_dir="${RESULT_DIR}"/"${module_name}"
fi
mkdir -p "${result_dir}"

function logwarning {
    local warnmsg=$*
    # 检查引入告警目录
    if [[ -z "${WARN_DIR}" ]]; then
        warn_dir=${CUR_DIR}/log/${datetime}/
    else
        warn_dir="${WARN_DIR}"/
    fi
    mkdir -p "${warn_dir}"
    LOGWARNING "${warnmsg}" &>/dev/null
    log_file="${warn_dir}"/"${module_name}".log LOGWARNING "${warnmsg}"
}

function logerror {
    local warnmsg=$*
    # 检查引入告警目录
    if [[ -z "${WARN_DIR}" ]]; then
        warn_dir=${CUR_DIR}/log/${datetime}/
    else
        warn_dir="${WARN_DIR}"/
    fi
    mkdir -p "${warn_dir}"
    LOGERROR "${warnmsg}" &>/dev/null
    log_file="${warn_dir}"/"${module_name}".log LOGERROR "${warnmsg}"
}
ret=0
# check ntpd
if systemctl status ntpd -l &>/dev/null; then
    logwarning "该机器启动了 ntpd, 请注意该机器是否应为授时服务器, 及服务向上游对时情况"
    LOGDELIVERY "${module_cname}" "对时服务开启" "该机器启动了 ntpd, 请注意该机器是否应为授时服务器, 及服务向上游对时情况" >"${result_dir}"/"${module_name}"_delivery.log
    ret=1
fi
if systemctl status chronyd -l &>/dev/null; then
    logwarning "该机器启动了 chronyd, 请注意该机器是否应为授时服务器, 及服务向上游对时情况."
    LOGDELIVERY "${module_cname}" "对时服务开启" "该机器启动了 ntpd, 请注意该机器是否应为授时服务器, 及服务向上游对时情况" >"${result_dir}"/"${module_name}"_delivery.log
    ret=1
fi

# parse cron file to get ntpdate command

# 把计划任务执行段都输出到一个文件进行比较
cron_all_file="${result_dir}"/cron_ntp
(
    crontab -l | awk '/^\s*[0-9|\*]/{
        printf "crontab -l -> "
        for (i=6;i<=NF;i++)
            printf "%s ",$i
            printf "\n"
    }'
    awk '/^\s*[0-9|\*]/{
        printf "%s -> ",FILENAME
        for (i=7;i<=NF;i++)
            printf "%s ",$i
            printf "\n"
    }' /etc/crontab
    find /etc/cron.d/ \( -type f -o -type l \) -readable -exec awk '/^\s*[0-9|\*]/{
        printf "%s -> ",FILENAME
        for (i=7;i<=NF;i++)
            printf "%s ",$i
            printf "\n"
    }' {} \;
) | grep ntpdate >"${cron_all_file}"

if [[ $(grep -c ntpdate "${cron_all_file}") -gt 1 ]] &&
    [[ "${ret}" -eq 0 ]]; then
    logwarning "该机器配置的 ntpdate 计划任务超过 1 条: $(grep -c ntpdate "${cron_all_file}"), 请修正后再次检查机器时差."
    LOGDELIVERY "${module_cname}" "异常" "该机器配置的 ntpdate 计划任务超过 1 条: $(grep -c ntpdate "${cron_all_file}"), 请修正后再次检查机器时差." >"${result_dir}"/"${module_name}"_delivery.log
    mapfile -t dup_crons <"${cron_all_file}"
    for dup_cron in "${dup_crons[@]}"; do
        logwarning "${dup_cron}"
    done
    ((ret += 2))
elif [[ $(grep -c ntpdate "${cron_all_file}") -lt 1 ]] &&
    [[ "${ret}" -eq 0 ]]; then
    logerror "该机器未配置 ntpdate 计划任务"
    LOGDELIVERY "${module_cname}" "异常" "该机器未配置 ntpdate 计划任务" >"${result_dir}"/"${module_name}"_delivery.log
    ((ret += 4))
fi
mapfile ntp_lines <"${cron_all_file}"

if [[ ${ret} -eq 0 ]]; then
    ret1=0
    for ntp_line in "${ntp_lines[@]}"; do
        ntp_cmd="$(echo "${ntp_line}" | awk -F '->' '{print $NF}')"
        ntp_test_cmd="${ntp_cmd/ntpdate/ntpdate -q}"
        ntp_test_result=$(eval timeout 10 ${ntp_test_cmd} 2>&1)
        # server 10.0.30.250, stratum 1, offset 387678.690488, delay 0.02744 22 Jan 00:00:20 ntpdate[46530]: step time server 10.0.30.250 offset 387678.690488 sec
        time_offset=$(echo "$ntp_test_result" | grep -oP "offset -?\K\d+(?=\.?\d+ \w+$)")
        if [[ -z "${time_offset}" ]]; then
            logerror "对时计划任务执行失败: ${ntp_line}"
            LOGDELIVERY "${module_cname}" "异常" "对时计划任务执行失败: ${ntp_line}" >"${result_dir}"/"${module_name}"_delivery.log
            ((ret1++))
        elif [[ "${time_offset}" -ge 30 ]]; then
            logerror "时差超过 30 秒: ${time_offset}"
            LOGDELIVERY "${module_cname}" "异常" "时差超过 30 秒: ${time_offset}" >"${result_dir}"/"${module_name}"_delivery.log
            ((ret1++))
        fi
    done
fi
[[ "${ret1}" -ne 0 ]] && ((ret += 8))

if [[ "${ret}" -eq 0 ]]; then
    LOGSUCCESS "${module_cname}"
    LOGDELIVERY "${module_cname}" "正常" "该机器对时配置正常" >"${result_dir}"/"${module_name}"_delivery.log
else
    LOGINFO "${module_cname}": 结束
fi
exit "${ret}"
