#!/bin/bash
#
# 用户登录信息
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="用户登录信息"
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

who -a &>"${result_dir}"/who
w &>"${result_dir}"/w
last -wFa &>"${result_dir}"/last
lastb -wFa &>"${result_dir}"/lastb
\cp /var/log/wtmp "${result_dir}"/
\cp /var/log/btmp "${result_dir}"/

time_pattern="$(date +'%b %d (\d{2}:\d{2}:\d{2}) %Y')"
read_conf "${CONF_FILE}" "${module_name}" fail_login_warn_cnt

if [[ $(lastb -awF | grep -cP "${time_pattern}") -gt $((fail_login_warn_cnt + 1)) ]]; then
    if [[ -z "${WARN_DIR}" ]]; then
        warn_dir=${CUR_DIR}/log/${datetime}/
    else
        warn_dir="${WARN_DIR}"/
    fi
    mkdir -p "${warn_dir}"
    LOGWARNING "${module_cname}": "本日登录失败次数超过: ${fail_login_warn_cnt}" &>/dev/null
    log_file="${warn_dir}"/"${module_name}".log LOGWARNING "${module_cname}": "本日登录失败次数超过: ${fail_login_warn_cnt}"
    exit 1
else
    LOGSUCCESS "${module_cname}"
fi
