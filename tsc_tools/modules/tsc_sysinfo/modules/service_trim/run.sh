#!/bin/bash
#
# 服务裁剪
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="服务裁剪"
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

DEFAULT=(sssd sysstat crond irqbalance rsyslog sshd auditd microcode ipmi tuned getty NetworkManager iptables zabbix-agent zabbix-proxy zabbix-server tsc_salt-master tsc_salt-minion)
enabled=$(systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend | awk '{print $1}')
left=${enabled}
for serv in "${DEFAULT[@]}"; do
    left=$(echo "${left}" | grep -vw ${serv})
done
if [[ $(echo "${left}" | wc -l) -gt 0 ]]; then
    logwarning 有超过默认列表的服务, 请确认服务是否需要开启
    LOGDELIVERY "${module_cname}" "请检查是否裁剪" "${left}" >"${result_dir}"/"${module_name}"_delivery.log
else
    LOGSUCCESS "${module_cname}"
    LOGDELIVERY "${module_cname}" "正常" "" >"${result_dir}"/"${module_name}"_delivery.log
fi
