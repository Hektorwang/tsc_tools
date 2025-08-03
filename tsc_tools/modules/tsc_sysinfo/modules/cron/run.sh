#!/bin/bash
#
# 采集并检查计划任务配置和日志
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="采集计划任务配置和日志"
module_name=$(basename "${CUR_DIR}")

# test
[[ -n $* ]] && echo 位置参数: "$*".

# 检查引入 func
if [[ ! "$(type -t LOGINFO)" == "function" ]]; then
    if [[ -d "${WORK_DIR}" ]]; then
        source "${WORK_DIR}"/bin/func &>/dev/null
    else
        source "${CUR_DIR}"/../../bin/func &>/dev/null
    fi
fi
LOGINFO "${module_cname}"

datetime="$(date +'%Y%m%d%H%M%S')"
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

input_files="/var/log/cron*"

ts_end="$(date +%s)"
ts_start="$((ts_end - 86400 * secure_log_day_cnt))"
# echo $ts_start "${ts_end}"

# 读取从上一次服务启动以来的 cron 日志
log_data=$(tac ${input_files} |
    awk -v ts_end="${ts_end}" -v ts_start="${ts_start}" -v flag=0 '{
        {
            print
        }
        if ($0 ~ /RANDOM_DELAY/ ){exit}
        }' | tac |
    tee -a "${result_dir}"/cron_laststart)

crontab -l &>"${result_dir}"/crontabl
\cp -r /etc/cron.d "${result_dir}"/
[[ -f /etc/crontab ]] && \cp /etc/crontab "${result_dir}"/

ret=0
if (echo "${log_data}" | grep -q "(CRON) bad"); then
    logwarning 有配置错误的计划任务 "$(echo "${log_data}" | grep -q "(CRON) bad")"
    ret=1
fi

log_file=/var/log/cron
if [[ $(stat -c %s "${log_file}") -lt 104857600 ]]; then
    \cp "${log_file}" "${result_dir}"
else
    logwarning "${log_file} 超过 100m, 若有需要请手动打包提交."
    ret=$((ret + 2))
fi

# 把计划任务执行段都输出到一个文件进行比较
cron_all_file="${result_dir}"/cron_all
(
    crontab -l | awk '/^\s*[0-9|\*]/{
        printf "crontab -l -> "
        for (i=6;i<=NF;i++)
            printf "%s ",$i
            printf "\n"
    }'
    awk '/^\s*[0-9|\*]/{
        printf "%s -> ",FILENAME
        for (i=7;i<=NF;i++)
            printf "%s ",$i
            printf "\n"
    }' /etc/crontab
    # awk '/^\s*[0-9|\*]/{
    #     printf "%s -> ",FILENAME
    #     for (i=7;i<=NF;i++)
    #         printf "%s ",$i
    #         printf "\n"
    # }' /etc/cron.d/*
    find /etc/cron.d/ \( -type f -o -type l \) -readable -exec awk '/^\s*[0-9|\*]/{
        printf "%s -> ",FILENAME
        for (i=7;i<=NF;i++)
            printf "%s ",$i
            printf "\n"
    }' {} \;
) >"${cron_all_file}"

dup_cron=$(awk -F ' -> ' '{
    cmd_cnt[$2]++
    if (!cmd_conf[$2]){cmd_conf[$2]=$1}
    if (index(cmd_conf[$2],$1)==0) {
        cmd_conf[$2]=cmd_conf[$2]", "$1
        }
    }
    END {
        for (i in cmd_cnt) {
            if (cmd_cnt[i]>1)
            printf "配置: %s; 命令: %s\n",cmd_conf[i],i
        }
    }' <"${cron_all_file}")

if [[ -n "${dup_cron}" ]]; then
    (
        logwarning 有重复计划任务命令, 请结合计划任务配置文件变量段人工判断是否为重复计划任务.
        IFS=$'\n'
        for line in ${dup_cron}; do
            logwarning "${line}"
        done
    )
    ret=$((ret + 4))
fi

if [[ ${ret} -eq 0 ]]; then
    LOGSUCCESS "${module_cname}"
else
    LOGINFO "${module_cname}": 结束
    exit ${ret}
fi
