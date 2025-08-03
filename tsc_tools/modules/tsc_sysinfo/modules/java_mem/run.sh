#!/bin/bash
#
# collect java memory info
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="采集 java 进程内存信息"
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

function _collect_java_info {
    local java_bindir=$1 ret_jstat ret_jstack ret=0
    while read -r line; do
        pid=$(echo "${line}" | awk '{print $1}')
        echo "${line}" &>>"${result_dir}"/jps_"${pid}".log
        ret_jstat=$(
            "${java_bindir}"/jstat -gcutil "${pid}" &>>"${result_dir}"/jstat_"${pid}".log
        )
        ret_jstack=$(
            "${java_bindir}"/jstack "${pid}" &>>"${result_dir}"/jstack_"${pid}".log
        )
        ((ret += ret_jstat + ret_jstack))
    done < <(
        "${java_bindir}"/jps -lv 2>&1 | grep -v "sun.tools.jps.Jps"
    )
    if [[ ${ret} -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}
# 采集含 java 的进程信息
pgrep -a java &>"${result_dir}"/java_processes

j_flag=1
if [[ ! -s "${CONF_FILE}" ]]; then
    logwarning 未找到主配置文件, 将自行尝试查找 JAVA_HOME
else
    read_conf "${CONF_FILE}" "${module_name}" java_home
    if [[ -z "${java_home}" ]]; then
        logwarning 主配置文件 JAVA_HOME 为空, 将尝试自行查找.
    elif ! (
        "${java_home}"/bin/jps -l 2>&1 | grep -q "sun.tools.jps.Jps"
    ) &>/dev/null; then
        logwarning "${java_home}"/bin/jps 不可用, 将自行查找可用的 jps
    else
        j_flag=$(_collect_java_info "${java_home}"/bin/)
        if [[ "${j_flag}" -eq 0 ]]; then
            LOGSUCCESS "${module_cname}"
            exit 0
        else
            logwarning "${module_cname}": 采集失败
            LOGINFO "${module_cname}": 结束
            exit 4
        fi
    fi
fi
if ! command -v locate &>/dev/null; then
    logerror 本机缺少 locate 程序, 无法查找
    exit 3
fi

mapfile -t jpses < <(locate bin/jps)
for jps_binfile in "${jpses[@]}"; do
    if ("${jps_binfile}" -l | grep -q "sun.tools.jps.Jps") &>/dev/null; then
        LOGDEBUG 找到可用 jps: "${jps_binfile}"
        j_flag=$(_collect_java_info "$(dirname "${jps_binfile}")")
        [[ "${j_flag}" -eq 0 ]] && break
    fi
done

if [[ "${j_flag}" -eq 0 ]]; then
    LOGSUCCESS "${module_cname}"
    exit 0
else
    logwarning "${module_cname}": 采集失败
    LOGINFO "${module_cname}": 结束
    exit 4
fi
