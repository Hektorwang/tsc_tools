#!/bin/bash
#
# 检查 cpu 节能
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="检查 cpu 节能"
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

if [[ $(arch) != "x86_64" ]]; then
    LOGSUCCESS "${module_cname}": "处理器非 x86_64 架构, 跳过检查"
    LOGDELIVERY "${module_cname}" "跳过" "处理器非 x86_64 架构, 跳过检查" \
        >"${result_dir}"/"${module_name}"_delivery.log
    exit 0
fi

if [[ $(grep "cpu MHz" </proc/cpuinfo | sort -u | wc -l) -eq 1 ]]; then
    LOGSUCCESS "${module_cname}"
    LOGDELIVERY "${module_cname}" "已关闭" "" \
        >"${result_dir}"/"${module_name}"_delivery.log
else
    if [[ -z "${WARN_DIR}" ]]; then
        warn_dir=${CUR_DIR}/log/${datetime}/
    else
        warn_dir="${WARN_DIR}"/
    fi
    mkdir -p "${warn_dir}"
    LOGWARNING "${module_cname}": "CPU 节能开启" &>/dev/null
    log_file="${warn_dir}"/"${module_name}".log LOGWARNING "${module_cname}": "CPU 节能开启"
    LOGDELIVERY "${module_cname}" "未关闭" "" \
        >"${result_dir}"/"${module_name}"_delivery.log
    exit 1
fi
