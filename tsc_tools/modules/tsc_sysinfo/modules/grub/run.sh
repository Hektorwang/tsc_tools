#!/bin/bash
#
# 采集 grub 相关信息
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="采集 grub 信息"
module_name=$(basename "${CUR_DIR}")

# 检查引入 func
if [[ ! "$(type -t LOGINFO)" == "function" ]]; then
    if [[ -d "${WORK_DIR}" ]]; then
        source "${WORK_DIR}"/bin/func &>/dev/null
    else
        source "${CUR_DIR}"/../../bin/func &>/dev/null
    fi
fi
LOGINFO "${module_cname}"

datetime="$(date +'%Y%m%d%H%M%S')"

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

# grub-legacy
if rpm -q grub &>/dev/null && ! (rpm -qa | grep -q "grub2") &>/dev/null; then
    df -PkT /boot/efi &>"${result_dir}"/boot-part.log
    \cp /proc/cmdline "${result_dir}"
    \cp -r /etc/grub.d "${result_dir}"
    \cp /boot/grub/grub.conf "${result_dir}"
    LOGSUCCESS "${module_cname}"
# grub2
elif (rpm -qa | grep -q "grub2") && ! rpm -q grub &>/dev/null; then
    df -PkT /boot/efi &>"${result_dir}"/boot-part.log
    \cp /proc/cmdline "${result_dir}"/
    \cp /etc/default/grub* "${result_dir}"/
    \cp -r /etc/grub.d "${result_dir}"/
    \cp /boot/grub2/grub.cfg "${result_dir}"/
    command -v grub2-mkconfig &>/dev/null &&
        grub2-mkconfig -o "${result_dir}"/grub-mkconfig.cfg &>/dev/null
    command -v grub-mkconfig &>/dev/null &&
        grub-mkconfig -o "${result_dir}"/grub-mkconfig.cfg &>/dev/null
    LOGSUCCESS "${module_cname}"
# 都装了?
elif rpm -q grub &>/dev/null && (rpm -qa | grep -q "grub2") &>/dev/null; then
    logerror "该机器同时部署了 grub-legacy 和 grub2, 无法采集 grub 信息"
    exit 1
# 其他
else
    logerror 未找到服务器上安装 grub 的 rpm 包
    exit 2
fi
