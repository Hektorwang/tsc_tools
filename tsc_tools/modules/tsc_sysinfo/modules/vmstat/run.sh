#!/bin/bash
#
# 采集 30 秒 vmstat 信息
# 当 r, b 列持续大于 cpu 线程数告警
# 当 wa 列持续大于设定阈值告警
# 当交换分区被使用超过 1 次告警
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="采集 vmstat"
module_name=$(basename "${CUR_DIR}")
datetime="$(date +'%Y%m%d%H%M%S')"

ret=0

# 检查引入 func
if [[ ! "$(type -t LOGINFO)" == "function" ]]; then
    if [[ -d "${WORK_DIR}" ]]; then
        source "${WORK_DIR}"/bin/func &>/dev/null
    else
        source "${CUR_DIR}"/../../bin/func &>/dev/null
    fi
fi
LOGINFO "${module_cname}": "等待 30 秒"

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
if [[ ! -f "${CONF_FILE}" ]]; then
    LOGERROR 未找到主配置文件
    exit 1
fi

if (read_conf "${CONF_FILE}" common iowait_threshold) &>/dev/null; then
    read_conf "${CONF_FILE}" common iowait_threshold
else
    read_conf "${CONF_FILE}" "${module_name}" iowait_threshold
fi

cpu_threads=$(lscpu | awk '/^CPU\(s\):/{print $2}')
function trap_int {
    local pid=$1
    kill -9 "${pid}"
    echo ""
    LOGINFO "${module_cname}": 中止
    exit 99
}

vmstat -aw -t 1 30 -n &>"${result_dir}"/"${module_name}".log

vmstat_parsed=$(sed -n '3,$p' "${result_dir}"/"${module_name}".log |
    awk -v c="${cpu_threads}" -v w="${iowait_threshold}" -v si=0 -v so=0 '{
        if (si!=$7) {si=$7;si_cnt+=1}
        if (so!=$8) {si=$8;so_cnt+=1}
        if ($1>c) r++
        if ($2>c) b++
        if ($16>w) wa++
        } END {
          print "[r]="r,"[b]="b,"[wa]="wa,"[si_cnt]="si_cnt,"[so_cnt]="so_cnt
        }')
declare -A result
eval result=\(${vmstat_parsed}\)

if [[ ${result[r]} -ge 30 ]]; then
    logwarning "CPU上等待运行的任务队列长度持续过高(r 列): ${result_dir}/${module_name}.log"
    ((ret += 1))
fi

if [[ ${result[b]} -ge 30 ]]; then
    logwarning "阻塞的任务队列长度持续过高(b 列): ${result_dir}/${module_name}.log"
    ((ret += 2))
fi

if [[ ${result[wa]} -ge 30 ]]; then
    logwarning "消耗在等待 IO 的 CPU 时间持续超过阈值(id 列): 30, ${result_dir}/${module_name}.log"
    ((ret += 4))
fi

if [[ ${result[si_cnt]} -gt 2 ]] || [[ ${result[so_cnt]} -gt 2 ]]; then
    logwarning "系统内存不够, 已开始使用交换分区(si, so 列): ${result_dir}/${module_name}.log"
    ((ret += 8))
fi

if [[ ${ret} -eq 0 ]]; then
    LOGSUCCESS "${module_cname}"
else
    LOGINFO "${module_cname}": 结束
    exit ${ret}
fi
