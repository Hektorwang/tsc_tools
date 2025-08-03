#!/bin/bash
#
# 检查 pg 中是否存在指定锁类型
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="检查 pg 中是否存在指定锁类型"
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

if [[ ! -s "${CONF_FILE}" ]]; then
    logerror 未找到主配置文件或主配置文件为空
    exit 1
else
    [[ -z "${is_pg}" ]] && read_conf "${CONF_FILE}" "${module_name}" is_pg
    [[ -z "${pg_cmd}" ]] && read_conf "${CONF_FILE}" "${module_name}" pg_cmd
fi

if [[ "${is_pg}" -ne 0 ]]; then
    LOGINFO "${CONF_FILE}": "${module_name}": is_pg 不为 0, 跳过检查.
    exit 0
fi

if eval "${pg_cmd} -c \"\\d\"" &>"${result_dir}/table_names.log"; then
    LOGINFO 检查数据库是否有卡住的独占锁, 等待 30 秒
    pg_deadlock_results1=()
    pg_deadlock_results2=()
    mapfile -t pg_deadlock_results1 < <(
        eval "${pg_cmd} -tf ${CUR_DIR}/pg_deadlock.sql" |
            sed -r '/^\s*$/d'
    )
    for sec in {1..30}; do
        echo -en "\r进度: ${sec} / 30"
        sleep 1
    done
    echo -en "\r"
    mapfile -t pg_deadlock_results2 < <(
        eval "${pg_cmd} -tf ${CUR_DIR}/pg_deadlock.sql" |
            sed -r '/^\s*$/d'
    )
    mapfile -t dup_results < <(comm -12 <(
        for i in "${pg_deadlock_results1[@]}"; do
            echo "${i}"
        done |
            sort -u
    ) <(
        for i in "${pg_deadlock_results2[@]}"; do
            echo "${i}"
        done |
            sort -u
    ))
    if [[ "${#dup_results[@]}" -ne 0 ]]; then
        logwarning 有 30 秒未释放的锁
        for dup_result in "${dup_results[@]}"; do
            logwarning "${dup_result}"
        done
        LOGINFO "${module_cname}: 结束"
        exit 3
    else
        LOGSUCCESS "${module_cname}"
        exit 0
    fi
else
    logerror "查询失败 ${pg_cmd} -c \"\\d\""
    for pg_cmd_result in "${pg_cmd_results[@]}"; do
        logerror "${pg_cmd_result}"
    done
    LOGINFO "${module_cname}: 结束"
    exit 2
fi
