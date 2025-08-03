#!/bin/bash
#
# 采集磁盘信息
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="采集磁盘信息"
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
export -f logwarning

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
export -f logerror

CheckInstall() {
    stat1=$(lspci | grep -iE 'raid|adaptec' | grep -c Adaptec)
    stat2=$(lspci | grep -i raid | grep -c -i -E 'LSI|DELL|Intel')

    if [[ "${stat1}" -ge 1 ]]; then
        LOGINFO "Raid 卡品牌: ADAPTEC"
        if [[ ! -f /usr/Arcconf/arcconf ]]; then
            if rpm -Uvh "${CUR_DIR}"/lib/Arcconf-3.03-23668."${arch}".rpm --force; then
                LOGSUCCESS "Raid 工具安装完成: ${CUR_DIR}/lib/Arcconf-3.03-23668.${arch}.rpm"
            else
                logerror "Raid 工具安装失败: ${CUR_DIR}/lib/Arcconf-3.03-23668.${arch}.rpm"
                exit 2
            fi
        fi
    elif [ "${stat2}" -ge 1 ]; then
        LOGINFO "Raid 卡品牌: LSI"
        if [[ ! -f "/opt/MegaRAID/storcli/storcli64" ]]; then
            if rpm -Uvh "${CUR_DIR}"/lib/storcli-007.2408.0000.0000-1.noarch.rpm --force; then
                LOGSUCCESS "Raid 工具安装完成: ${CUR_DIR}/lib/storcli-007.2408.0000.0000-1.noarch.rpm"
            else
                logerror "Raid 工具安装失败: ${CUR_DIR}/lib/storcli-007.2408.0000.0000-1.noarch.rpm"
                exit 2
            fi
        fi
    else
        LOGINFO 未发现 Raid 卡
        LOGINFO "${module_cname}": 结束
        exit 0
    fi
}

LOGINFO "检查是否需要安装工具"
if [[ ${get_os_arch_flag} -ne 0 ]]; then
    logerror 操作系统不支持.
    exit 1
fi

CheckInstall
LOGINFO "开始收集磁盘信息"
sh "${CUR_DIR}"/lib/collectraid.sh >"${result_dir}"/raidinfo.log
sh "${CUR_DIR}"/lib/RaidStatCheck.sh >"${warn_dir}"/raidwarn.log
if [[ -s "${warn_dir}/raidwarn.log" ]]; then
    logwarning "RAID存在告警,详情请查看${warn_dir}/raidwarn.log"
else
    rm -rf "${warn_dir}"/raidwarn.log
fi
LOGSUCCESS "收集磁盘信息完成"
