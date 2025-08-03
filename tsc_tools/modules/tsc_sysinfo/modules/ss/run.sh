#!/bin/bash
#
# 采集网络连接信息
# ss -anoptux
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="采集网络连接信息"
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

ss -sanoptux &>"${result_dir}"/"${module_name}".log

sysctl_fd_max="$(sysctl fs.file-max | awk -F '=' '{print $NF}')"
# 打开 TCP  监听的 pid 们

mapfile -t listening_pids < <(
    awk '$1~/tcp/ && $2~/LISTEN/{print $NF}' <"${result_dir}"/"${module_name}".log |
        grep -oP "(?<=users:\().*(?=\))" |
        sed -r -e 's/\),\(/\n/g' |
        awk -F ',' '{gsub("pid=","",$2);print $2}' |
        sort -u
)

function compare_threshold {
    local _used_fd _max_fd _threshold_fd _pid _hint
    _used_fd=$1
    _max_fd=$2
    _pid=$3
    _hint=$4
    _threshold_fd=$(awk -v m="${_max_fd}" 'BEGIN{print int(m*0.8)}')
    if [[ "${_used_fd}" -gt "${_threshold_fd}" ]]; then
        logwarning "${_hint} ${_used_fd} > ${_threshold_fd}". "$(
            ps -w -o uname:64=,pid=,command= |
                awk '$2=='"${_pid}"' {
                    {for (i=3;i<=NF;i++)c=c" "$i}
                        printf "uname: %s, pid: %s, cmd:%s\n",$1,$2,c
                    }'
        )"
        return 2
    fi
    return 0
}

ret=0
for pid in "${listening_pids[@]}"; do
    proc_fd_max=$(
        awk '/Max open files/{
            c=$4==unlimited ? 2048*1024*1024 : $4
            print c
            }' /proc/"${pid}"/limits
    )
    used_fd="$(find /proc/"${pid}"/fd -type f -o -type l | wc -l)"
    compare_threshold "${used_fd}" "${sysctl_fd_max}" "${pid}" "进程使用文件描述符数量超过系统上限(sysctl fs.file-max)的80%:" || ret=1
    compare_threshold "${used_fd}" "${proc_fd_max}" "${pid}" "进程使用文件描述符数量超过进程上限(/proc/${pid}/limits)的80%:" || ret=1
    uname=$(ps -w -e -o uname:64=,pid= | awk '$2=='"${pid}"'{print $1}')
    if ! grep -qP "^${uname}:" </etc/passwd; then
        # logwarning "${uname}" does not exist in /etc/passwd, check if it is in a container.
        logwarning "/etc/passwd 中不存在用户 ${uname}, 可能为容器中用户, 无法检查进程使用文件描述符是否超过用户上限(ulimit -n)."
    else
        user_fd_max=$(sudo -u "${uname}" bash -c "ulimit -n")
        compare_threshold "${used_fd}" "${user_fd_max}" "${pid}" "进程使用文件描述符数量超过用户上限(ulimit -n)的80%:" || ret=1
    fi
done

if [[ "${ret}" -eq 0 ]]; then
    LOGSUCCESS "${module_cname}"
else
    LOGINFO "${module_cname}": 结束
    exit 1
fi
