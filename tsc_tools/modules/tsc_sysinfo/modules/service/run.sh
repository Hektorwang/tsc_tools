#!/bin/bash
#
# 系统服务状态检查
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="系统服务状态检查"
module_name=$(basename "${CUR_DIR}")

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
    DATETIME="$(date +'%Y%m%d%H%M%S')"
    result_dir=${CUR_DIR}/log/${DATETIME}/
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

ret=0
# if [[ "${get_os_arch_flag}" == "1" ]]; then
#     logwarnning "操作系统不支持"
#     exit 1
# fi

# if [[ ${os_version} =~ ^6\. ]]; then
if ps -we -o cmd=,pid= | awk '$NF==1{print $1}' | grep -qP "/init$"; then
    LOGINFO 系统初始化程序为: SysV, 不支持检测服务是否启动
    service --status-all &>"${result_dir}"/sysv-status-all.log &
    chkconfig --list --type sysv &>"${result_dir}"/chkconfig-list-type-sysv.log
    wait
    LOGINFO "如下服务设置为开机启动: $(grep "3:on" <"${result_dir}"/chkconfig-list-type-sysv.log | awk '{print $1}' | xargs)"
    # services_on_notrunning=()
    # services_off_running=()
    # chkconfig --list --type sysv &>"${result_dir}"/"${module_name}".log
    # mapfile -t sysv_services < <(chkconfig --list --type sysv 2>/dev/null)
    # for sysv_service in "${sysv_services[@]}"; do
    #     sysv_service_name=$(echo "${sysv_service}" | awk '{print $1}')
    #     echo "${sysv_service}" | grep -q '3:on'
    #     sysv_service_onboot=$?
    #     service "${sysv_service_name}" status 2>&1 | grep -qP "is running|pid="
    #     sysv_service_status=$?
    #     if [[ "${sysv_service_onboot}" -eq 0 ]]; then
    #         if [[ "${sysv_service_status}" -ne 0 ]]; then
    #             services_on_notrunning+=("${sysv_service_name}")
    #         fi
    #     else
    #         if [[ "${sysv_service_status}" -eq 0 ]]; then
    #             services_off_running+=("${sysv_service_name}")
    #         fi
    #     fi
    # done
elif ps -we -o cmd=,pid= | awk '$NF==1{print $1}' | grep -qP "/systemd$"; then
    LOGINFO 系统初始化程序为: systemd
    services_on_notrunning=()
    services_off_running=()
    if ! systemctl list-unit-files --type=service --state=enabled,disabled -l --quiet --no-wall --no-legend --no-pager &>"${result_dir}"/"${module_name}".log; then
        logerror 检查出错, 请查看: "${result_dir}"/"${module_name}".log
        LOGINFO "${module_cname}": 结束
        exit 2
    fi
    mapfile -t systemd_services <"${result_dir}"/"${module_name}".log
    for systemd_service in "${systemd_services[@]}"; do
        systemd_service_name="$(echo "${systemd_service}" | awk '{print $1}')"
        systemctl list-unit-files \
            --type=service \
            --state=enabled \
            -l --no-wall --no-legend --no-pager \
            "${systemd_service_name}" |
            grep -q 'enabled'
        systemd_service_onboot=$?
        if [[ ${systemd_service_name} =~ @ ]]; then
            systemctl status "${systemd_service_name/@/@*}" -l --no-wall --no-legend --no-pager |
                grep -q ": active ("
            systemd_service_status=$?
        else
            systemctl status -l "${systemd_service_name}" -l --no-wall --no-legend --no-pager |
                grep -q ": active ("
            systemd_service_status=$?
        fi
        if [[ "${systemd_service_onboot}" -eq 0 ]]; then
            if [[ "${systemd_service_status}" -ne 0 ]]; then
                services_on_notrunning+=("${systemd_service_name}")
            fi
        else
            if [[ "${systemd_service_status}" -eq 0 ]]; then
                services_off_running+=("${systemd_service_name}")
            fi
        fi
    done
else
    logerror "不支持的系统初始化程序: $(ps -we -o cmd=,pid= | awk '$NF==1{print $1}')"
    LOGINFO "${module_cname}": 结束
    exit 1
fi

if [[ "${#services_on_notrunning[@]}" -ge 1 ]]; then
    logwarning "有设置为开机启动但未启动的服务: ${services_on_notrunning[*]}"
    ((ret += 2))
fi

if [[ "${#services_off_running[@]}" -ge 1 ]]; then
    logwarning "有未设置为开机启动但已启动的服务: ${services_off_running[*]}"
    ((ret += 4))
fi

if [[ "${ret}" -eq 0 ]]; then
    LOGSUCCESS "${module_cname}"
else
    LOGINFO "${module_cname}": 结束
    exit "${ret}"
fi
