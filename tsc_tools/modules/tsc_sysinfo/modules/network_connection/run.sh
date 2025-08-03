#!/bin/bash
#
# 重要节点联通性
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="重要节点联通性"
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

if [[ -s "${WORK_DIR}"/etc/important_hosts ]]; then
    conf_file="${WORK_DIR}"/etc/important_hosts
elif [[ -s "${CUR_DIR}"/etc/important_hosts ]]; then
    conf_file="${CUR_DIR}"/etc/important_hosts
else
    logerror 未找到配置文件: important_hosts
    exit 1
fi

if [[ ! -f "${CONF_FILE}" ]]; then
    logerror 未找到主配置文件: globe.common.conf
    exit 1
fi

read_conf "${CONF_FILE}" "${module_name}" fork

important_hosts=()
mapfile -t important_hosts < <(grep -vP "^\s*;|^\s*#|^\s*$" "${conf_file}" | sort -u)

if [[ ${#important_hosts[@]} -eq 0 ]]; then
    logerror 配置为空: "${conf_file}"
    exit 2
fi
# set -x
fifo_file=${CUR_DIR}/tmp/$$.fifo
rm -f "${fifo_file}"
mkfifo "${fifo_file}"
exec 6<>"${fifo_file}"
rm -f "${fifo_file}"

LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8

for ((i = 0; i < "${fork}"; i++)); do
    echo "${i}"
done >&6
# set -x

test_cnt=0
echo -en "进度: ${test_cnt} / ${#important_hosts[@]}"
for important_host in "${important_hosts[@]}"; do
    read -ru6
    {
        if (LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
            ping "${important_host}" -c3 -w3 |
            grep -q "100% packet loss"); then
            logwarning "${important_host}" &>/dev/null
        fi
        echo "" >&6
    } &
    ((test_cnt++))
    echo -en "\r进度: ${test_cnt} / ${#important_hosts[@]}"
done
wait
echo ""
exec 6<>/dev/null

while read -r line; do
    failed_hosts+=("$(echo "${line}" | awk '{print $NF}')")
done <"${WARN_DIR}"/"${module_name}".log

if [[ "${#failed_hosts[@]}" -ne 0 ]]; then
    logwarning "有重要节点 ping 失败( ${#failed_hosts[*]} / ${#important_hosts[@]} )"
    logwarning "${failed_hosts[*]}"
    exit 255
else
    LOGSUCCESS "${module_cname}"
fi
