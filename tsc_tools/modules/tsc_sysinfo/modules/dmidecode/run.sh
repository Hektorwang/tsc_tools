#!/bin/bash
#
# 采集 dmidecode
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="采集 dmidecode 信息"
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
    result_dir=${CUR_DIR}/log/${datetime}/result
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

if dmidecode &>"${result_dir}"/dmidecode.log; then
    LOGSUCCESS "${module_cname}"
else
    logerror "${module_cname}": 采集 dmidecode 失败.
    LOGINFO "${module_cname}": 结束
    exit 1
fi

# 物理内存大小
MemPhySize=$(
    dmidecode -t 17 |
        awk '{
            if($1~/Size/ && $2~/[0-9]/ && $3=="GB")
                {sum+=$2}
            else if($1~/Size/ && $2~/[0-9]/ && $3=="MB")
                {$2=$2/1024 ;sum+=$2}}
            END {printf("%.0f\n",sum)
            }'
)
# 单根内存大小
SinglePhySize=$(
    dmidecode -t 17 |
        awk '{
            if($1~/Size/ && $2~/[0-9]/ && $3=="GB")
                {print $2}
            else if($1~/Size/ && $2~/[0-9]/ && $3=="MB")
                {print int($2 /1024)}
            }' |
        tail -n 1
)

if [[ "$MemPhySize" =~ ^[0-9]+$ ]]; then
    MemLogSize=$(free -g | awk '/^Mem/{print $2}')
    # echo "$MemPhySize - $MemLogSize"
    Diff=$(awk 'BEGIN{print int('"${MemPhySize}"' - '"${MemLogSize}"' )}')
    if [[ "$Diff" -gt "$SinglePhySize" ]]; then
        #if [ "$Diff" -gt "0" ];then
        # logwarning 物理内存为 "${MemPhySize}" GB.
        # logwarning 逻辑内存为 "${MemLogSize}" GB.
        # logwarning 物理内存和系统内存大小不一致.
        logerror "物理内存为 ${MemPhySize} GB. 逻辑内存为 ${MemLogSize} GB. 物理内存和系统内存大小不一致."
    fi
fi
