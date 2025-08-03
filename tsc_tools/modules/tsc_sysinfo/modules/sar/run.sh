#!/bin/bash
#
# 采集 /var/log/sa 信息
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="采集 /var/log/sa 信息"
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
LOGINFO "${module_cname}"

if [[ -z "${RESULT_DIR}" ]]; then
    result_dir=${CUR_DIR}/log/${datetime}/result
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

check_sar() {
    local _iowait_threshold _cpuidle_threshold file_date
    _iowait_threshold=$1
    _cpuidle_threshold=$2
    rm -f "${CUR_DIR}"/tmp/io_wait.txt 2>/dev/null
    rm -f "${CUR_DIR}"/tmp/cpu_idel.txt 2>/dev/null
    while read -r -d '' sar_log; do
        file_date=$(stat -c %y "${sar_log}" | awk '{print $1}')
        sar -u -f "${sar_log}" |
            awk -v file_date="${file_date}" '
                !/Average/ && NR>3 {
                    if($7 > '"${_iowait_threshold}"')
                        print file_date,$0 >>"'"${result_dir}"/_sar_iowait.log'"
                    if($NF < '"${_cpuidle_threshold}"')
                        print file_date,$0 >>"'"${result_dir}"/_sar_cpuidle.log'"
            }'
    done < <(
        find /var/log/sa -type f -regex "\/var\/log\/sa\/sa[0-9]+" -print0
    )

    # for i in $(ls -1 /var/log/sa/sa[0-9]*); do
    # #检查iowait情况,阈值设置为30
    # sar -f "${i}" -u |
    #     grep -v Average |
    #     awk '{if($7 > 30)print $0}' |
    #     sed '/^$/d' >"${CUR_DIR}"/tmp/io_wait.txt
    # io_wait_count=$(wc -l "${CUR_DIR}"/tmp/io_wait.txt | awk '{print $1}')
    # if [ "$io_wait_count" -gt "1" ]; then
    #     create_wardir
    #     cat "${CUR_DIR}"/tmp/io_wait.txt >>"${warn_dir}"/sar_iowait.text
    # fi
    # #检查cpu空闲情况
    #     sar -f "${i}" -u |
    #         grep -v Average |
    #         awk '{if($NF < 10)print $0}' |
    #         sed '/^$/d' >"${CUR_DIR}"/tmp/cpu_idel.txt
    #     cpu_idel_count=$(
    #         wc -l "${CUR_DIR}"/tmp/cpu_idel.txt |
    #             awk '{print $1}'
    #     )
    #     if [ "$cpu_idel_count" -gt "1" ]; then
    #         create_wardir
    #         cat "${CUR_DIR}"/tmp/cpu_idel.txt >>"${warn_dir}"/sar_cpuidel.text
    #     fi
    # done

    if [ -s "${result_dir}"/_sar_iowait.log ]; then
        title="DATE TIME MERIDIEM CPU %user %nice %system %iowait %steal %idle"
        sed "1i${title}" "${result_dir}"/_sar_iowait.log |
            column -t >"${result_dir}/sar_iowait.log"
        logwarning "设备存在 iowait 情况,详情请查看 ${result_dir}/sar_iowait.log"
    fi
    if [ -s "${result_dir}"/_sar_cpuidle.log ]; then
        title="DATE TIME MERIDIEM CPU %user %nice %system %iowait %steal %idle"
        sed "1i${title}" "${result_dir}"/_sar_cpuidle.log |
            column -t >"${result_dir}"/sar_cpuidle.log
        logwarning "设备存在 cpu 资源不足情况,详情请查看 ${result_dir}/sar_cpuidle.log"
    fi
}

if (read_conf "${CONF_FILE}" common iowait_threshold) &>/dev/null; then
    read_conf "${CONF_FILE}" common iowait_threshold
else
    read_conf "${CONF_FILE}" "${module_name}" iowait_threshold
fi
if (read_conf "${CONF_FILE}" common cpuidle_threshold) &>/dev/null; then
    read_conf "${CONF_FILE}" common cpuidle_threshold
else
    read_conf "${CONF_FILE}" "${module_name}" cpuidle_threshold
fi

if [ -d "/var/log/sa" ]; then
    \cp -r /var/log/sa "${result_dir}"/
    check_sar "${iowait_threshold}" "${cpuidle_threshold}"
else
    logerror "${module_cname}: 未找到 sar 日志: /var/log/sa/sa*"
    LOGINFO "${module_cname}: 结束"
    exit 1
fi

LOGSUCCESS "${module_cname}"
