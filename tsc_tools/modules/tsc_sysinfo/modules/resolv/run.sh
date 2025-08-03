#!/bin/bash
#
# 采集 /etc/resolv.conf 文件
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="检查 /etc/resolv.conf"
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

if [[ -z "${RESULT_DIR}" ]]; then
    result_dir=${CUR_DIR}/log/${datetime}/
else
    result_dir="${RESULT_DIR}"/"${module_name}"
fi
mkdir -p "${result_dir}"
if [[ -f /etc/resolv.conf ]]; then
    \cp /etc/resolv.conf "${result_dir}"/
    if ! grep -qE "^\s*nameserver" /etc/resolv.conf; then
        LOGSUCCESS "${module_cname}"
        exit 0
    else
        nslookup_result="$(nslookup 127.0.0.1 -timeout=2 -retry=1 2>&1)"
        if echo "${nslookup_result}" | grep -q "no servers could be reached"; then
            echo "${nslookup_result}" >"${result_dir}"/nslookup.err
            logerror "${module_cname}": 无法使用 /etc/resolv.conf 中配置的 DNS 服务器: "${result_dir}"/nslookup.err
            LOGINFO "${module_cname}": 结束
            exit 1
        else
            LOGSUCCESS "${module_cname}"
        fi
    fi
else
    logwarning 不存在域名解析服务器配置文件: /etc/resolv.conf
    LOGINFO "${module_cname}": 结束
    exit 2
fi
