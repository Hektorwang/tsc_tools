#!/bin/bash
#
# 系统启动级别检查
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="系统启动级别检查"
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

#LOGINFO "操作系统：$os_distribution"
#LOGINFO "系统版本：$os_version"
#LOGINFO "处理器架构：$arch"
#LOGINFO "是否支持：$get_os_arch_flag"

runlevel &>"${result_dir}"/runlevel
rl=$(runlevel 2>/dev/null | awk '{print $2}')

ret=0
if [ "$get_os_arch_flag" == "1" ]; then
    logwarning "操作系统不支持"
else
    if [ "$(echo "${os_version}" | awk -F '.' '{print $1}')" == "6" ]; then
        stlevel=$(cat /etc/inittab 2>/dev/null | grep ^id: | awk -F ':' '{print $2}')
        \cp /etc/inittab "${result_dir}"
        if [[ "$rl" != "3" ]] || [[ "$stlevel" != "3" ]]; then
            logwarning "当前系统运行级别非多用户模式，请修改 /etc/inittab 并重启操作系统"
            ((ret += 2))
            LOGDELIVERY "${module_cname}" "异常" "当前系统运行级别非多用户模式，请修改 /etc/inittab 并重启操作系统" >"${result_dir}"/"${module_name}"_delivery.log
        fi
    else
        systemctl get-default &>"${result_dir}"/systemctl-get-default
        systemctl get-default | grep -q multi-user && stlevel=3 || stlevel=9
        if [[ "$rl" != "3" ]] || [[ "$stlevel" != "3" ]]; then
            logwarning "当前系统运行级别非多用户模式，请执行命令systemctl set-default multi-user.target 并重启操作系统"
            ((ret += 2))
            LOGDELIVERY "${module_cname}" "异常" "当前系统运行级别非多用户模式，请执行命令systemctl set-default multi-user.target 并重启操作系统" >"${result_dir}"/"${module_name}"_delivery.log
        fi
    fi
fi

if [[ ${ret} -eq 0 ]]; then
    LOGSUCCESS "${module_cname}"
    LOGDELIVERY "${module_cname}" "正常" "" >"${result_dir}"/"${module_name}"_delivery.log
else
    LOGINFO "${module_cname}": 结束
    exit ${ret}
fi
