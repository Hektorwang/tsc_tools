#!/bin/bash
#
# 检查内存使用情况
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="检查内存使用情况"
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

check_huge() {
    LOGINFO "检查大内存页"
    hugesize=$(
        grep -iE "HugePages_Total|Hugepagesize" /proc/meminfo |
            awk 'BEGIN{multi=1}{multi*=$2}END{print multi}'
    )
    if [ "$hugesize" -gt "0" ]; then
        logwarning "系统存在大内存页,需要注意;PR、RDP设备请忽略"
    else
        LOGSUCCESS "系统无大内存页"
        \cp /proc/meminfo "${result_dir}"/
    fi
}

check_swap() {
    LOGINFO "检查swap,请等待 10 秒"
    swapinout=$(sar -W 1 10 | tail -n 1 | awk '{print $2,$3}')
    swapin=$(echo "$swapinout" | awk '{print $1}')
    swapout=$(echo "$swapinout" | awk '{print $2}')
    resultin=$(echo "$swapin > 0" | bc -l)
    resultout=$(echo "$swapout > 0" | bc -l)
    if [ "$resultin" -eq 1 ] || [ "$resultout" -eq 1 ]; then
        logwarning "系统存在 swap 的读取和写入"
    else
        LOGSUCCESS "系统无 swap 读取和写入"
    fi
}

check_huge
check_swap
