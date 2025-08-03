#!/bin/bash
#
# 使用 stress-ng 进行压测
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="使用 stress-ng 压测"
module_name=$(basename "${CUR_DIR}")
datetime="$(date +'%Y%m%d%H%M%S')"

# 检查引入 func
if [[ ! "$(type -t LOGINFO)" == "function" ]]; then
    if [[ -d "${WORK_DIR}" ]]; then
        source "${WORK_DIR}"/bin/func &>/dev/null
    else
        WORK_DIR=$(readlink -f "${CUR_DIR}"/../../)
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

if [[ ! -f "${CONF_FILE}" ]]; then
    logerror 未找到主配置文件
    exit 1
fi

[[ -z "${stress_time}" ]] && read_conf "${CONF_FILE}" "${module_name}" stress_time
[[ -z "${stress_dir}" ]] && read_conf "${CONF_FILE}" "${module_name}" stress_dir

# if [[ ${get_os_arch_flag} -ne 0 ]] || [[ -z "${arch}" ]]; then
#     logerror "${module_cname}": 未获取到处理器架构
#     exit 2
# fi
# if [[ ! -f ${WORK_DIR}/bin/stress-ng-${arch} ]]; then
#     logerror "${module_cname}": 无法找到对应处理器架构的 stress-ng 工具
#     exit 3
# fi
LOGINFO "${module_cname}": 成功运行结束视为通过压测, 若压测过程中死机视为无法通过压测.
LOGINFO "压测时间持续: ${stress_time}"
LOGINFO "压测磁盘目录为: ${stress_dir}"
LOGINFO "如需调整请修改 globe.common.conf"

free_mem="$(free -m | awk '/Mem/{print int($NF/2)}')"
workers="$(($(nproc) + 1))"
half_disk_available=$(df -Plk "${stress_dir}" | awk 'NR==2{print int($4/2)"K"}')
if (
    cd "${stress_dir}" &&
        /bin/stress-ng -v \
            -c "${workers}" \
            --vm "${workers}" --vm-bytes "${free_mem}"M \
            -d "${workers}" --hdd-bytes "${half_disk_available}" --hdd-opts direct \
            --iomix "${workers}" --smart \
            -t "${stress_time}" &>"${result_dir}"/"${module_name}".log
); then
    LOGSUCCESS "${module_cname}"
else
    logerror "${module_cname}": 执行失败. 命令: \
        /bin/stress-ng -v \
        -c "${workers}" \
        --vm "${workers}" --vm-bytes "${free_mem}"M \
        -d "${workers}" --hdd-bytes "${half_disk_available}" --hdd-opts direct \
        --iomix "${workers}" --smart \
        -t "${stress_time}"
    exit 4
fi
