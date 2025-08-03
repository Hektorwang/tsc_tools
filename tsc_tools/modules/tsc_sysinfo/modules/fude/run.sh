#!/bin/bash
#
# fude运行状态检查
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154,SC1090
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="fude运行状态检查"
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

#LOGINFO "操作系统：$os_distribution"
#LOGINFO "系统版本：$os_version"
#LOGINFO "处理器架构：$arch"
#LOGINFO "是否支持：$get_os_arch_flag"

rnd=$(echo "$RANDOM % 1000" | bc)
tmpfile=${result_dir}/tmp_fude_list
rc=$(cd /opt && ls | grep -E 'FUDE$|FUDE-[0-9]{1,2}\.[0-9]{1,3}$' | head -n1)
ret=0
read_conf "${CONF_FILE}" "${module_name}" fude_warn_cnt
if [ -z "$rc" ]; then
    logwarning "FUDE未安装"
else
    fude_log="/opt/${rc}/fude/var/log/fudeguard.log"
    if [ -f "$fude_log" ]; then
        source /opt/"${rc}"/fude/profile/fude_profile
        # IsRun=$(ps -ef | grep 'fudeguard-inner.py' | wc -l)
        IsRun=$(pgrep -f 'fudeguard-inner.py' | wc -l)
        if [ "${IsRun}" -eq 0 ]; then
            logwarning "FUDE未运行"
        else
            fudeguardmgr.py --l &>"${tmpfile}"
            fude=$(sed -e '1d' "${tmpfile}" | awk '{print $1}' | grep -cEv 'snmpd|snmptrapd|filterquery')
            for ((n = 1; n <= fude; n++)); do
                date1=$(date +"%Y-%m-%d%H:%M:%S.%N")
                date2=$(date --date='1 hours ago' +"%Y-%m-%d%H:%M:%S.%N")
                var[$n]=$(
                    sed -e '1d' "${tmpfile}" |
                        awk '{print $1}' |
                        sed -n ''"$n"'p;'"$n"'q'
                )
                valueout=$(
                    grep "${var[$n]}" "${fude_log}" |
                        grep "not running" |
                        grep -Ev 'snmpd|snmptrapd|filterquery' |
                        awk '{t=$1$2;if(t<"'"$date1"'"&&t>"'"$date2"'") print}' |
                        wc -l
                )
                if [[ "${var[$n]}" != "snmpd" ]] &&
                    [[ "${var[$n]}" != "snmptrapd" ]]; then
                    if [ "${valueout}" -eq 0 ]; then
                        :
                    elif [ "${valueout}" -ge "${fude_warn_cnt}" ]; then
                        logwarning "守护进程${var[$n]},1小时内重启了${valueout}次"
                        ((ret++))
                    else
                        LOGINFO "守护进程${var[$n]},1小时内重启了${valueout}次"
                    fi
                fi
            done
            if [[ $(($(date +%s) - $(stat -c %Y "${fude_log}"))) -gt 3600 ]]; then
                logwarning "fude日志超过一小时未刷新: ${fude_log} -> $(stat -c %y "${fude_log}")"
                ((ret += 2))
            fi
        fi
    else
        logwarning "FUDE运行异常,日志不存在: ${fude_log}"
    fi
fi

if [[ ${ret} -eq 0 ]]; then
    LOGSUCCESS "${module_cname}"
else
    LOGINFO "${module_cname}": 结束
    exit ${ret}
fi
