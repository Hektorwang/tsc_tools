#!/bin/bash
#
# 检查挂载磁盘是否只读
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="检查挂载磁盘是否只读"
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

mainpid=$$
rnd=$(echo "$RANDOM % 1000" | bc)
tmpfile="tsc_sysinfo_diskrw.$rnd"
read_conf "${CONF_FILE}" "${module_name}" overtime
[ -z "$overtime" ] && overtime=10
content="磁盘读写超时"
(
    sleep $overtime
    echo -e "${content}"
    kill -9 $mainpid &>/dev/null
) &
subpid=$!

Dirs=$(df -PT 2>/dev/null | grep -E '[ \t]+(ext[0-9]|nfs|xfs|cifs|fus\.mfs)[ \t]+' | awk '/%/{print $NF}' | sort -u)
ret=0
rds=""
for Dir in $Dirs; do
    { rm -f "${Dir}"/"${tmpfile}"; } >/dev/null 2>&1
    { touch "${Dir}"/"${tmpfile}"; } >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        rds="${rds},$Dir"
        ret=$(($ret + 1))
    fi
    find $Dir -mmin +60 -maxdepth 1 -type f -size 0 -name "tsc_sysinfo_diskrw\.*" 2>/dev/null | xargs rm -f 1>/dev/null 2>&1
done

if [ -n "$rds" ]; then
    rds=$(echo "$rds" | sed 's/^,//')
    logwarning "存在只读的磁盘,挂载目录为：$rds"
fi
if [[ ${ret} -eq 0 ]]; then
    LOGSUCCESS "${module_cname}"
else
    LOGINFO "${module_cname}": 结束
    #exit ${ret}
fi

exec 1>/dev/null
kill -9 $subpid
exec 1>&-
