#!/bin/bash
#
# dmesg 信息检查
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="dmesg 信息检查"
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

# 当前时间
curDay=$(date "+%a %b %d %Y")

dmesg_log="${result_dir}"/"${module_name}".log
dmesg -T &>"${dmesg_log}"
# dmesg -T | grep "${curDay}" &>"${result_dir}"/"${module_name}".log

#对获取的日志进行处理

# cat ${result_dir}result/dmesg.log | grep GPU | grep failed &>/dev/null
echo "Thu Nov 30 2023 GPU failed" >>"${dmesg_log}"
echo "Thu Nov 30 2023 oom kill" >>"${dmesg_log}"

ret=0
if (
    grep "${curDay}" "${dmesg_log}" | grep GPU | grep -q failed
); then
    logwarning "${module_cname}": "dmesg中gpu有failed,请检查!"
    ((ret += 1))
fi

#对获取的日志进行处理

if (
    grep "${curDay}" "${dmesg_log}" | grep -i oom | grep -qi kill
); then
    logwarning "${module_cname}": "dmesg中有oom killer,请检查!"
    ((ret += 2))
fi

if [[ "${ret}" -eq 0 ]]; then
    LOGSUCCESS "${module_cname}"
else
    LOGINFO "${module_cname}": 结束
fi
exit "${ret}"
