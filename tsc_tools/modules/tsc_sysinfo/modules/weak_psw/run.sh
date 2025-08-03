#!/bin/bash
#
# 系统用户弱密码
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="系统用户弱密码"
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

:> "${CUR_DIR}"/bin/john.log
:> "${CUR_DIR}"/bin/john.pot
if "${CUR_DIR}"/bin/john-"$(arch)" &>/dev/null; then
    LOGINFO 尝试使用密码字典破解密码, 最多耗时 60 秒
    LOGDEBUG timeout 60 "${CUR_DIR}"/bin/john-"$(arch)" /etc/shadow \
        --wordlist="${CUR_DIR}"/etc/password.lst \
        --format=crypt \
        --fork=$(($(nproc) + 1))
    timeout 60 "${CUR_DIR}"/bin/john-"$(arch)" /etc/shadow \
        --wordlist="${CUR_DIR}"/etc/password.lst \
        --format=crypt \
        --fork=$(($(nproc) + 1)) &>"${result_dir}"/john.log
    "${CUR_DIR}"/bin/john-"$(arch)" --show /etc/shadow &>"${result_dir}"/"${module_name}".pot
    cracked_psw_cnt=$(
        grep -oP "^\d+(?= password hashes cracked)" \
            "${result_dir}"/"${module_name}".pot
    )
    if [[ "${cracked_psw_cnt}" -gt 0 ]]; then
        logwarning "${module_cname}": 存在 "${cracked_psw_cnt}" 个弱密码
        LOGDEBUG "查看 ${result_dir}/${module_name}.pot"
        LOGDELIVERY "${module_cname}" "异常" "$(cat "${result_dir}"/"${module_name}".pot)" \
            >"${result_dir}"/"${module_name}"_delivery.log
    else
        LOGSUCCESS "${module_cname}"
        LOGDELIVERY "${module_cname}" "正常" "" >"${result_dir}"/"${module_name}"_delivery.log
    fi
else
    logwarning 密码破解工具无法执行, 跳过检查
    LOGDELIVERY "${module_cname}" "异常" "密码破解工具无法执行, 跳过检查 " >"${result_dir}"/"${module_name}"_delivery.log
fi
