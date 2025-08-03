#!/bin/bash
#
# 检查防火墙开启防护规则
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="检查防火墙开启防护规则"
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

LOGINFO "${module_cname}"

# 检查引入结果目录
if [[ -z "${RESULT_DIR}" ]]; then
    result_dir=${CUR_DIR}/log/${datetime}/
else
    result_dir="${RESULT_DIR}"/"${module_name}"
fi
mkdir -p "${result_dir}"

if ! iptables-save 2>&1 | grep -qE "TSC|SAILOR-INPUT|SAILOR-PRE|SAILOR-FORWARD"; then
    logwarning "未使用公司防火墙工具开启防护, 请确认设备网络防护情况."
    LOGDELIVERY "${module_cname}" "异常" "未使用公司防火墙工具开启防护, 请确认设备网络防护情况." \
        >"${result_dir}"/"${module_name}"_delivery.log
else
    LOGSUCCESS "${module_cname}"
    LOGDELIVERY "${module_cname}" "正常" "已使用公司防火墙工具开启防护, 请确认规则是否合理" \
        >"${result_dir}"/"${module_name}"_delivery.log
fi
