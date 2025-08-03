#!/bin/bash
#
# 采集 lsof
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="采集 lsof"
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

# 全量结果
lsof -nPoR &>"${result_dir}"/"${module_name}".log

# 还在打开已删除文件的 pid 分组并查询 pid 信息
open_deleted=$(awk -v title="$(head -n1 "${result_dir}"/"${module_name}".log)" '
    $NF~/(deleted)/{
        if (s[$2]) s[$2]=s[$2]"\n    "$0
        else s[$2]="    "title"\n    "$0
    }
    END {
        for (i in s)
        {
            system("ps -wef | awk '\''$2=="i"'\''")
            print s[i]"\n"
        }
    }' "${result_dir}"/"${module_name}".log)

if [[ -n "${open_deleted}" ]]; then
    echo "${open_deleted}" >"${result_dir}"/"${module_name}".err
    logwarning "存在进程打开了被删除的文件, 详情参考 $(readlink -f "${result_dir}"/"${module_name}".err)"
    LOGINFO "${module_cname}": 结束
else
    LOGSUCCESS "${module_cname}"
fi
