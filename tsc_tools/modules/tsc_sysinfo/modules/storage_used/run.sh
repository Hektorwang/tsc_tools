#!/bin/bash
#
# 存储使用情况
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="存储使用量"
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

df -TPl &>"${result_dir}"/cmd_df-TPl
df -TPi &>"${result_dir}"/cmd_df-TPi

read_conf "${CONF_FILE}" "${module_name}" storage_used_percent

dir_used=$(
    df -TPl 2>/dev/null |
        grep -E '[ \t]+(ext[0-9]|nfs|xfs|cifs|fus\.mfs)[ \t]+' |
        awk '{
            split($(NF-1),a,"%")
            if(a[1]>='"${storage_used_percent}"')
                printf $NF "(" $(NF-1) ")" ","
                }' |
        sed '$s/,$/\n/'
)
inode_used=$(
    df -TPi 2>/dev/null |
        grep -E '[ \t]+(ext[0-9]|nfs|xfs|cifs|fus\.mfs)[ \t]+' |
        awk '{
        split($(NF-1),a,"%")
        if(a[1]>='"${storage_used_percent}"')
            printf $NF "(" $(NF-1) ")" ","
        }' |
        sed '$s/,$/\n/'
)

ret=0
#if [ -z "$dir_used" -a -z "$inode_used" ];then
#    LOGSUCCESS "${module_cname}"
#else
if [ -n "$dir_used" ]; then
    #LOGWARNING "${module_cname}": "目录所在磁盘空间使用较高,具体目录为：$dir_used"
    logwarning "目录所在磁盘空间使用较高,具体目录为：$dir_used"
    ((ret += 2))
fi

if [ -n "$inode_used" ]; then
    #LOGWARNING "${module_cname}": "目录所在磁盘inode使用较高,具体目录为：$inode_used"
    logwarning "目录所在磁盘inode使用较高,具体目录为：$inode_used"
    ((ret += 4))
fi

if [[ ${ret} -eq 0 ]]; then
    LOGSUCCESS "${module_cname}"
else
    LOGINFO "${module_cname}": 结束
    exit ${ret}
fi
