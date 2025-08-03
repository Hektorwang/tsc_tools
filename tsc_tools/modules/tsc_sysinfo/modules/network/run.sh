#!/bin/bash
#
# 采集网络配置, 包括 `ip a`, `ip r`, `ethtool`, `/proc/net/dev`
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="采集网络配置"
module_name=$(basename "${CUR_DIR}")
datetime="$(date +'%Y%m%d%H%M%S')"

# test
[[ -n $* ]] && echo 位置参数: "$*".

# 检查引入 func
if [[ ! "$(type -t LOGINFO)" == "function" ]]; then
    if [[ -d "${WORK_DIR}" ]]; then
        source "${WORK_DIR}"/bin/func &>/dev/null
    else
        source "${CUR_DIR}"/../../bin/func &>/dev/null
    fi
fi
LOGINFO "${module_cname}"

# 检查引入结果目录
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

ip a &>"${result_dir}"/ipa.log
ip r &>"${result_dir}"/ipr.log
\cp /proc/net/dev "${result_dir}"/proc_net_dev.log
command -v ifconfig &>/dev/null && ifconfig -a &>"${result_dir}"/ifconfig.log
(
    IFS=$'\n'
    while read -r nic; do
        echo "ethtool ${nic}"
        ethtool "${nic}"
        ethtool -i "${nic}"
        ethtool -d "${nic}"
        echo ""
    done < <(awk '{if(NR>=3){gsub(/:$/,"",$1);print $1}}' /proc/net/dev)
) &>"${result_dir}"/ethtool.log

LOGSUCCESS "${module_cname}"
