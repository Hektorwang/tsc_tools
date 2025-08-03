#!/bin/bash
#
# ssh服务端口检查
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="sshd 端口检查"
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

# if ss -lnopt sport = :22 2>/dev/null | grep -q sshd; then
port_22_info="$(lsof -noRP -iTCP:22 -sTCP:LISTEN | awk '$1=="sshd" && $3==1')"
if [[ -n "${port_22_info}" ]]; then
    echo "${port_22_info}" &>"${result_dir}"/sshdport
    logwarning "本机上 sshd 服务监听 22 端口, 请修改 /etc/ssh/sshd_config"
    LOGDELIVERY "${module_cname}" "异常" "该机器 sshd 服务监听 22 端口" >"${result_dir}"/"${module_name}"_delivery.log
    LOGINFO "${module_cname}": 结束
    exit 2
else
    LOGSUCCESS "${module_cname}"
    LOGDELIVERY "${module_cname}" "正常" "" >"${result_dir}"/"${module_name}"_delivery.log
fi
