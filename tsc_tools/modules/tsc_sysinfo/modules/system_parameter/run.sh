#!/bin/bash
#
# 系统参数调优检查
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="系统参数调优检查"
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
    logerror "主配置文件不存在或为空: ${CONF_FILE}"
    exit 1
fi

read_conf "${CONF_FILE}" "${module_name}" max_processes_cnt
read_conf "${CONF_FILE}" "${module_name}" max_fd_cnt

sysctl -a -p --system &>"${result_dir}"/sysctl.log
[[ -f /etc/security/limits.conf ]] && \cp /etc/security/limits.conf "${result_dir}"/
[[ -f /etc/systemd/system.conf ]] && \cp /etc/systemd/system.conf "${result_dir}"/
[[ -f /etc/profile ]] && \cp /etc/profile "${result_dir}"/
[[ -d /etc/profile.d/ ]] && \cp -r /etc/profile.d/ "${result_dir}"/
[[ -d ~/.bashrc ]] && \cp -r /etc/profile.d/ "${result_dir}"/bashrc
[[ -d ~/.bash_profile ]] && \cp -r /etc/profile.d/ "${result_dir}"/bash_profile
[[ -d ~/.bash_history ]] && \cp -r /etc/profile.d/ "${result_dir}"/bash_history

ret=0
if [[ "$(sysctl -n kernel.pid_max)" -lt "${max_processes_cnt}" ]]; then
    logwarning "${module_cname}": "sysctl -n kernel.pid_max 小于 ${max_processes_cnt}, 请检查!"
    ((ret += 1))
fi

if [[ "$(sysctl -n fs.file-max)" -lt "${max_fd_cnt}" ]]; then
    logwarning "${module_cname}": "sysctl -n fs.file-max 小于 ${max_fd_cnt}, 请检查!"
    ((ret += 1))
fi

if [[ "$(ulimit -u)" -lt "${max_processes_cnt}" ]]; then
    logwarning "${module_cname}": "ulimit -u 小于 ${max_processes_cnt}, 请检查!"
    ((ret += 4))
fi

if [[ "$(ulimit -n)" -lt "${max_fd_cnt}" ]]; then
    logwarning "${module_cname}": "ulimit -n 小于 ${max_fd_cnt}, 请检查!"
    ((ret += 8))
fi

if [[ "${ret}" -eq 0 ]]; then
    LOGSUCCESS "${module_cname}"
else
    LOGINFO "${module_cname}": 结束
fi

exit "${ret}"
