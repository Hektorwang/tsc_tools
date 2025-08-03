#!/bin/bash
#
# selinux运行状态
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="SELINUX状态检查"
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

if [ -f "/etc/sysconfig/selinux" ]; then
    conf=$(grep ^SELINUX= /etc/sysconfig/selinux | awk -F '=' '{print $2}')
    \cp /etc/sysconfig/selinux "${result_dir}"
else
    logwarning "配置文件：/etc/sysconfig/selinux 文件不存在"
    LOGDELIVERY "${module_cname}" "异常" "配置文件：/etc/sysconfig/selinux 文件不存在" >"${result_dir}"/"${module_name}"_delivery.log
fi

ret=0
if [ "$conf" != "disabled" ]; then
    logwarning "/etc/sysconfig/selinux：SELINUX配置未关闭"
    LOGDELIVERY "${module_cname}" "异常" "/etc/sysconfig/selinux：SELINUX配置未关闭" >"${result_dir}"/"${module_name}"_delivery.log
    ((ret += 2))
fi

runstat=$(getenforce)
if [ "${runstat}" != "Disabled" ]; then
    logwarning "当前SELINUX状态为：${runstat}"
    getsebool -a &>"${result_dir}"/getsebool.log
    LOGDELIVERY "${module_cname}" "异常" "当前SELINUX状态为：${runstat}" >"${result_dir}"/"${module_name}"_delivery.log
    ((ret += 4))
fi

if [[ "${ret}" -eq 0 ]]; then
    LOGSUCCESS "${module_cname}"
    LOGDELIVERY "${module_cname}" "正常" "已关闭" >"${result_dir}"/"${module_name}"_delivery.log
else
    LOGINFO "${module_cname}": 结束
fi
exit "${ret}"
