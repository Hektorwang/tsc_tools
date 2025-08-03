#!/bin/bash
#
# 磁盘性能测试
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="磁盘性能测试"
module_name=$(basename "${CUR_DIR}")
datetime="$(date +'%Y%m%d%H%M%S')"

if [[ ! "$(type -t LOGINFO)" == "function" ]]; then
    if [[ -d "${WORK_DIR}" ]]; then
        source "${WORK_DIR}"/bin/func &>/dev/null
    else
        source "${CUR_DIR}"/../../bin/func &>/dev/null
    fi
fi
if [[ ! "$(type -t LOGDELIVERY)" == "function" ]]; then
    if [[ -d "${WORK_DIR}" ]]; then
        source "${WORK_DIR}"/bin/tsc_sysinfo_func.sh &>/dev/null
    else
        source "${CUR_DIR}"/../../bin/tsc_sysinfo_func.sh &>/dev/null
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
    if [[ -z "${WARN_DIR}" ]]; then
        warn_dir=${CUR_DIR}/log/${datetime}/
    else
        warn_dir="${WARN_DIR}"/
    fi
    mkdir -p "${warn_dir}"
    LOGERROR "${warnmsg}" &>/dev/null
    log_file="${warn_dir}"/"${module_name}".log LOGERROR "${warnmsg}"
}

function gen_conf {
    local mount_points mount_point half_disk_available test_size conf_file filename
    find "${CUR_DIR}"/tmp/ -type f -name "*.ini" -exec unlink {} \; &>/dev/null
    rm -f "${CUR_DIR}"/tmp/*.ini &>/dev/null
    mapfile -t mount_points < <(
        df -PhT |
            grep -P "(apfs|btrfs|ext[234]|fat32|ffs|hfs|jfs|jfs2|ntfs|refs|reiser|ufs|vxfs|xfs|zfs)" |
            awk '{print $NF}'
    )
    for mount_point in "${mount_points[@]}"; do
        half_disk_available=$(
            df -Phk "${mount_point}" |
                awk 'NR==2 {print int($4/1024/1024/2)"g"}'
        )
        if [[ "${half_disk_available}" == "0g" ]]; then
            LOGINFO 挂载点可用空间小于 2G, 跳过测试. "${mount_point}"
            continue
        fi
        test_size=$(
            echo -e "${size}\n${half_disk_available}" |
                sort -g |
                head -n1
        )
        filename="$(mktemp -u -p "${mount_point}")"
        conf_file=${CUR_DIR}/tmp/${mount_point//\//@}.ini
        sed -r -n \
            -e "/^\s*size/csize=${test_size}" \
            -e "/^s*\[${module_name}\]/,/^s*\[/p" \
            "${CONF_FILE}" >"${conf_file}"
        echo "filename=${filename}" >>"${conf_file}"
    done
}

if ! command -v timeout &>/dev/null; then
    logerror 机器未安装 timeout 程序
    LOGINFO "${module_cname}": 结束
    exit 4
fi

if [[ ! -s ${CONF_FILE} ]]; then
    logerror "未找到主配置文件"
    LOGINFO "${module_cname}": 结束
    exit 2
fi

LOGDELIVERY "${module_cname}" "失败" "fio 未成功结束" >"${result_dir}"/"${module_name}"_delivery.log

read_conf "${CONF_FILE}" "${module_name}" size
LOGINFO 开始进行测试 , 根据设备性能差异, 每挂载点运行时间预期 3-30 分钟. 挂载点列表: "$(
    df -PhT |
        grep -P "(apfs|btrfs|ext[234]|fat32|ffs|hfs|jfs|jfs2|ntfs|refs|reiser|ufs|vxfs|xfs|zfs)" |
        awk '{print $NF}' | xargs
)"
gen_conf
ret=0
delivery_msg=()
while read -r -d '' fio_conf; do
    read_conf "${fio_conf}" fio filename
    test_dir="$(dirname "${filename}")"
    fio_log="$(readlink -f "${result_dir}/$(basename "${fio_conf%%.ini}").log")"
    LOGINFO 测试目录: "${test_dir}", 测试日志: "${fio_log}"
    LOGDEBUG "$(/bin/fio "${fio_conf}" --showcmd)"
    if (
        timeout -s9 1800 /bin/fio "${fio_conf}" -output="${fio_log}" --output-format=json
    ); then
        echo ""
        LOGINFO "测试完成: ${test_dir}"
        if read_bw="$(/bin/jq -rc '.jobs[0].read.bw' "${fio_log}")" &&
            write_bw="$(/bin/jq -rc '.jobs[0].write.bw' "${fio_log}")"; then
            if [[ "${read_bw}" -lt 51200 ]]; then
                logwarning "该目录挂载的块设备读速度小于 50MB/s: $(df -P "${test_dir}" | awk 'NR==2{print $1}') -> $((read_bw / 1024))MB/s"
                delivery_msg+=("该目录挂载的块设备读速度小于 50MB/s: $(df -P "${test_dir}" | awk 'NR==2{print $1}') -> $((read_bw / 1024))MB/s")
                ret=128
            fi
            if [[ "${write_bw}" -lt 51200 ]]; then
                logwarning "该目录挂载的块设备写速度小于 50MB/s: $(df -P "${test_dir}" | awk 'NR==2{print $1}') -> $((write_bw / 1024))MB/s"
                delivery_msg+=("该目录挂载的块设备写速度小于 50MB/s: $(df -P "${test_dir}" | awk 'NR==2{print $1}') -> $((read_bw / 1024))MB/s")
                ret=128
            fi
        else
            logerror "日志解析出错: ${test_dir} -> ${fio_log}"
            delivery_msg+=("日志解析出错")
            ret=64
            continue
        fi
        LOGINFO "挂载点: ${test_dir}, 读取速度: ${read_bw}KB/s, 写入速度: ${write_bw}KB/s"
        delivery_msg+=("挂载点: ${test_dir}, 读取速度: ${read_bw}KB/s, 写入速度: ${write_bw}KB/s")
    else
        echo ""
        logerror "测试失败: ${test_dir}"
        delivery_msg+=("测试失败: ${test_dir}")
        ret=255
    fi
done < <(find "${CUR_DIR}"/tmp/ -maxdepth 1 -mindepth 1 -type f -name "*.ini" -print0)

if [[ "${ret}" -eq 0 ]]; then
    LOGSUCCESS "${module_cname}"
    LOGDELIVERY "${module_cname}" "正常" "$(for line in "${delivery_msg[@]}"; do echo "${line}"; done)" >"${result_dir}"/"${module_name}"_delivery.log
else
    LOGINFO "${module_cname}": 结束
    echo "${delivery_msg[@]}"
    LOGDELIVERY "${module_cname}" "异常" "$(for line in "${delivery_msg[@]}"; do echo "${line}"; done)" >"${result_dir}"/"${module_name}"_delivery.log
    exit "${ret}"
fi
