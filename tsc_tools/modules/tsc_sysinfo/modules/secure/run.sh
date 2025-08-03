#!/bin/bash
#
# 采集 messages 日志
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="采集 secure 日志"
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

read_conf "${CONF_FILE}" "${module_name}" secure_log_day_cnt
read_conf "${CONF_FILE}" "${module_name}" pam_failure_threshold
ts_end="$(date +%s)"
ts_start="$((ts_end - 86400 * secure_log_day_cnt))"
# echo $ts_start "${ts_end}"

# if command -v file &>/dev/null; then
#     logwarning 未安装 file 程序, 若日志被压缩将会极大增加解析时间.
#     file_flag=1
# else
#     file_flag=0
# fi
if command -v zcat &>/dev/null; then
    zcat_flag=0
else
    logwarning 未安装 zcat 程序, 若日志被压缩则会报错.
    zcat_flag=1
fi

while read -r file; do
    if [[ "$(stat -c +%Y "${file}")" -lt "${ts_start}" ]]; then
        break
    elif [[ ! -s "${file}" ]]; then
        continue
    fi
    # if [[ "${file_flag}" -eq 0 ]]; then
    #     if file "${file}" | grep -qw gzip; then
    #         read_file_cmd="zcat \"${file}\" | tac"
    #     elif file "${file}" | grep -qw text; then
    #         read_file_cmd="tac \"${file}\""
    #     fi
    # elif [[ "${zcat_flag}" -eq 0 ]]; then
    #     if zcat -t "${file}" &>/dev/null; then
    #         read_file_cmd="zcat \"${file}\" | tac"
    #     else
    #         read_file_cmd="zcat \"${file}\" | tac"
    #     fi
    # fi
    read_file_cmd="tac \"${file}\""

    if [[ "${zcat_flag}" -eq 0 ]] && zcat -t "${file}" &>/dev/null; then
        read_file_cmd="zcat \"${file}\" | tac"
    fi

    eval "${read_file_cmd}" |
        awk -v ts_end="${ts_end}" -v ts_start="${ts_start}" -v flag=0 '{
            month = substr($0, 1, 3)
            day = substr($0, 5, 2)
            time = substr($0, 8, 8)
            cmd = "date -d \""month " " day " "time" \" +\"%s\""
            cmd |getline timestamp
            close(cmd)
            if (timestamp <= ts_end) {
                flag=1
                if ($0 ~ /[Ff]ail/) print $0
            }
            if (flag == 1 && timestamp <= ts_start) {
                exit
            }
            }' | tac |
        tee -a "${result_dir}"/secure_"${secure_log_day_cnt}"day
done < <(ls -t /var/log/secure*)

failures_cnt=$(wc -l <"${result_dir}"/secure_"${secure_log_day_cnt}"day)
# failures_cnt=$(tac ${input_files} |
#     awk -v ts_end="${ts_end}" -v ts_start="${ts_start}" -v flag=0 '{
#         month = substr($0, 1, 3)
#         day = substr($0, 5, 2)
#         time = substr($0, 8, 8)
#         cmd = "date -d \""month " " day " "time" \" +\"%s\""
#         cmd |getline timestamp
#         close(cmd)
#         if (timestamp <= ts_end) {
#             flag=1
#             if ($0 ~ /[Ff]ail/) print $0
#         }
#         if (flag == 1 && timestamp <= ts_start) {
#             exit
#         }
#         }' | tac |
#     tee -a "${result_dir}"/secure_"${secure_log_day_cnt}"day |
#     wc -l)

ret=0
if [[ ${failures_cnt} -ge "${pam_failure_threshold}" ]]; then
    logwarning "${secure_log_day_cnt} 日内 pam 认证失败次数大于等于 ${pam_failure_threshold}" 次.
    LOGWARNING 请检查是否有客户端配置了错误密码或有人正在攻击本机.
    LOGWARNING 可检查日志: "${result_dir}"/secure_"${secure_log_day_cnt}"day
    ret=1
fi

if [[ $(stat -c %s /var/log/secure) -lt 104857600 ]]; then
    \cp /var/log/secure "${result_dir}"
else
    logwarning "/var/log/secure 超过 100m, 若有需要请手动打包提交."
    ret=$((ret + 2))
fi

if [[ $(stat -c %Y /var/log/secure) -lt ${ts_start} ]]; then
    logwarning "/var/log/secure 已经超过 ${secure_log_day_cnt} 天没有刷新."
    ret=$((ret + 4))
fi

if [[ ${ret} -eq 0 ]]; then
    LOGSUCCESS "${module_cname}"
else
    LOGINFO "${module_cname}": 结束
    exit ${ret}
fi
