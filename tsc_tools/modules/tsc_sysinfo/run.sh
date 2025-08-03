#!/bin/bash
#
# 系统运行状态采集工具
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2154

set +o posix
unset LD_LIBRARY_PATH
# 工具主目录
WORK_DIR="$(dirname "$(readlink -f "$0")")" && cd "${WORK_DIR}" || exit 99
# 主配置目录
ETC_DIR="$(readlink -f "${WORK_DIR}/etc/")"
# 主配置文件路径
CONF_FILE="${ETC_DIR}"/globe.common.conf
# 主日志目录
LOG_DIR="$(readlink -f "${WORK_DIR}/log/")"
# 主入口脚本文件名
script_name=$(basename "$0" 2>/dev/null)
# 开始执行时间
[[ -z "${DATETIME}" ]] && DATETIME="$(date +'%Y%m%d%H%M%S')"
# 主日志文件
log_file="${LOG_DIR}"/"${script_name}"_"${DATETIME}".log
# 主采集文件目录
RESULT_DIR=${LOG_DIR}/${DATETIME}/result/
# 主告警文件目录
WARN_DIR=${LOG_DIR}/${DATETIME}/warn/
# 主临时文件夹
TMP_DIR="${WORK_DIR}/tmp/${DATETIME}"

source "${WORK_DIR}"/bin/func &>/dev/null
source "${WORK_DIR}"/bin/tsc_sysinfo_func &>/dev/null

if [[ ! -f "${CONF_FILE}" ]] || [[ ! -s "${CONF_FILE}" ]]; then
    LOGERROR 主配置文件不存在或为空: "${CONF_FILE}"
    exit 99
fi

declare -xr WORK_DIR ETC_DIR LOG_DIR DATETIME RESULT_DIR WARN_DIR TMP_DIR CONF_FILE
export script_name log_file

#################################### cc=79 ####################################
# 清理旧日志
# Globals:
#   CONF_FILE
# Arguments:
# Outputs:
# Returns:
#   0
#################################### cc=79 ####################################
function cleanup {
    LOGINFO "${FUNCNAME[0]}"
    local old_log_dir old_run_log old_log_dirs old_run_logs
    read_conf "${CONF_FILE}" common keep_old_log_cnt
    old_log_dirs=()
    old_run_logs=()
    while read -r old_log_dir; do
        old_log_dirs+=("${old_log_dir}")
    done < <(
        find "${LOG_DIR}" -maxdepth 1 -mindepth 1 -type d -print | sort -gr
    )
    while read -r old_run_log; do
        old_run_logs+=("${old_run_log}")
    done < <(
        find "${LOG_DIR}" -maxdepth 1 -mindepth 1 -type f -name "run.sh*.log" -print |
            sort -gr
    )
    if [[ ${#old_run_logs[@]} -gt ${keep_old_log_cnt} ]]; then
        # for ((i = 0; i <= ((${#old_run_logs[@]} - keep_old_log_cnt - 1)); i++)); do
        #     rm -rf "${old_run_logs[$i]}"
        # done
        for ((i = "${keep_old_log_cnt}"; i < "${#old_run_logs[@]}"; i++)); do
            rm -rf "${old_run_logs[$i]}"
        done
    fi
    if [[ ${#old_log_dirs[@]} -gt ${keep_old_log_cnt} ]]; then
        # for ((i = 0; i <= ((${#old_log_dirs[@]} - keep_old_log_cnt - 1)); i++)); do
        #     rm -rf "${old_log_dirs[$i]}"
        # done
        for ((i = "${keep_old_log_cnt}"; i < "${#old_log_dirs[@]}"; i++)); do
            rm -rf "${old_log_dirs[$i]}"
        done
    fi
    rm -rf "${WORK_DIR}"/tmp/*
    LOGSUCCESS "${FUNCNAME[0]}"
}

#################################### cc=79 ####################################
# 向标准输出打印帮助
# Globals:
# Arguments:
# Outputs:
#   readme.md
# Returns:
#   0
#################################### cc=79 ####################################
function usage {
    if ! "${WORK_DIR}"/bin/glow-"$(arch)" -p "${WORK_DIR}"/readme.md 2>/dev/null; then
        cat "${WORK_DIR}"/readme.md
    fi
    exit 0
}

#################################### cc=79 ####################################
# 获取操作系统版本和处理器架构
# 操作系统名称按 ansible 的叫法, 分如下几种
#   CentOS
#   Fit StarrySky OS
#   Kylin Linux Advanced Server
#   RedHat
# 处理器架构就是 x86_64和 aarch64
# Globals:
#   os_distribution: 操作系统发行版
#   os_version: 操作系统版本
#   arch: 处理器架构
#   get_os_arch_flag: 0-已获取操作系统版本和处理器架构且操作系统受支持, 1-非0
# Arguments:
#   -f: $1="-f", 则即使检查系统失败也不跳出脚本
# Outputs:
#    "${os_distribution}"-"${os_version}"-"${arch}"
#   结果样例
#     RedHat-6.7-x86_64
#     CentOS-7.4-aarch64
#     Kylin Linux Advanced Server-V10-aarch64
#     Fit StarrySky OS-22.06-x86_64
# Returns:
#   0: 获取成功
#   1: 获取失败
#   2: 不支持的系统
#################################### cc=79 ####################################
function get_os_arch {
    LOGINFO "${FUNCNAME[0]}"
    local warn_file os support_os support_flag force_flag result_dir
    [[ "$1" == "-f" ]] && force_flag=true || force_flag=false
    get_os_arch_flag=1
    read_conf "${CONF_FILE}" common support_os
    support_flag=false
    warn_file="${WARN_DIR}"/get_os_arch
    result_dir="${RESULT_DIR}"/get_os_arch/
    mkdir -p "${result_dir}"
    arch="$(arch)"
    arch &>"${result_dir}"/arch
    uname -a &>"${result_dir}"/uname
    if [[ -s /etc/redhat-release ]]; then
        \cp /etc/redhat-release "${result_dir}"/
        if grep -qw "Red Hat Enterprise Linux" /etc/redhat-release; then
            os_distribution="RedHat"
        elif grep -qw "CentOS Linux" /etc/redhat-release; then
            os_distribution="CentOS"
        else
            LOGERROR "获取操作系统版本失败, 请查看 /etc/redhat-release" |
                tee -a "${warn_file:-/dev/null}"
            ${force_flag} && exit 1 || return 1
        fi
    elif [[ -s /etc/os-release ]]; then
        \cp /etc/os-release "${result_dir}"/
        os_distribution="$(grep -oP "(?<=^NAME=\").*?(?=\")" /etc/os-release)"
    fi
    if [[ -z "${os_distribution}" ]]; then
        LOGERROR "获取操作系统版本失败, 请查看 /etc/redhat-release 或 /etc/os-release" |
            tee -a "${warn_file:-/dev/null}"
        ${force_flag} && exit 1 || return 1
    fi
    for os in "${support_os[@]}"; do
        if [[ "${os_distribution}" == "${os}" ]]; then
            support_flag=true
        fi
    done
    if ${support_flag}; then
        case $(uname -r) in
        *el6*)
            os_version=$(awk '{print $(NF-1)}' /etc/redhat-release)
            get_os_arch_flag=0
            ;;
        *el7*)
            os_version=$(awk '{print $(NF-1)}' /etc/redhat-release)
            os_version="${os_version%.*}"
            get_os_arch_flag=0
            ;;
        *fos2206* | *ky10*)
            os_version="$(grep -oP "(?<=^VERSION_ID=\").*?(?=\")" /etc/os-release)"
            get_os_arch_flag=0
            ;;
        esac
        echo "${os_distribution}"-"${os_version}"-"${arch}"
        export os_distribution os_version arch get_os_arch_flag
        LOGSUCCESS "${FUNCNAME[0]}"
    else
        LOGERROR "未支持的操作系统: ${os_distribution}"
        ${force_flag} && exit 2 || return 2
    fi
}
export -f get_os_arch

#################################### cc=79 ####################################
# 根据传参调用对应模块, 若未传参则调用 CONF_FILE-common-default_modules 中指定模块
# Globals:
#   CONF_FILE: 主配置文件
# Arguments:
#   -h: 打印帮助
#   -m: 指定模块名
#   -a: 上一个 -m 参数指定的模块的运行参数
# Outputs:
#   参数检查信息和各模块运行日志
# Returns:
#   0: 成功
#   255: 参数错误
#################################### cc=79 ####################################
function main {
    local module_dir default_modules specific_modules
    # 没给位置参数则执行默认模块
    if [[ -z "$1" ]]; then
        mkdir -p "${RESULT_DIR}" "${WARN_DIR}" "${LOG_DIR}" "${TMP_DIR}"
        cleanup
        # 获取操作系统为必选操作
        get_os_arch -f
        # 读取默认执行的模块们
        read_conf "${CONF_FILE}" common default_modules
        for module_dir in "${default_modules[@]}"; do
            (
                module_script="${WORK_DIR}"/modules/"${module_dir}"/run.sh
                if [[ -f "${module_script}" ]]; then
                    chmod u+x "${module_script}"
                    "${module_script}"
                    LOGDEBUG "----------------------------------------"
                else
                    LOGWARNING "模块入口脚本不存在: ${module_script}"
                fi
            )
        done
        LOGINFO "串行检查结束"
        printf "%0.s#" $(seq 1 "$(stty size | cut -f 2 -d ' ')")
        echo ""
        warn_files=()
        mapfile -t warn_files < <(find "${WARN_DIR}" -type f ! -name ".gitignore")
        if [[ ${#warn_files[@]} -gt 1 ]]; then
            LOGWARNING 执行报错汇总信息
            echo -e "\\033[1;31m"
            for warn_file in "${warn_files[@]}"; do
                awk '{$1="";$2="";$3="";$4="";print "-",$0}' <"${warn_file}"
            done
            echo -e "\\033[0;39m"
        else
            LOGSUCCESS 检查未发现明显问题.
        fi
        LOGDEBUG "以下压测模块对性能消耗较大, 可能影响业务程序工作. 不在默认执行列表内, 如有需要请手工执行"
        LOGDEBUG "$0 -m network_connection # 判断本机是否能 ping 通给定的重要节点列表"
        LOGDEBUG "$0 -m stress # 压测CPU,内存,存储IO"
        LOGDEBUG "$0 -m iperf3 # 带宽测试"
        LOGDEBUG "$0 -m fio # 存储性能检测"
        LOGINFO "检查信息汇总: ${log_file}"
        LOGINFO "检查信息详情: ${LOG_DIR}/${DATETIME}"
    # 给了位置参数校验合法性
    elif [[ $1 != "-m" ]] && [[ $1 != "-l" ]] && [[ $1 != "-h" ]] && [[ $1 != "-d" ]]; then
        LOGERROR 参数错误请查看帮助信息
        usage
        exit 255
    # 解析短参数执行对应模块
    else
        # 定义 指定加载的函数列表
        get_os_arch -f
        specific_modules=()
        while getopts "hm:a:ld" opt; do
            case ${opt} in
            l)
                LOGINFO "打印模块列表: (-: 默认执行模块, *: 非默认执行模块)."
                LOGINFO "可通过 ${0} -m 模块名 -h 查看模块具体帮助"
                read_conf "${CONF_FILE}" common default_modules
                mapfile -t all_modules < <(ls "${WORK_DIR}"/modules)
                mapfile -t non_default_modules < <(
                    comm -23 <(
                        for i in "${all_modules[@]}"; do
                            echo "${i}"
                        done | sort -u
                    ) <(
                        for i in "${default_modules[@]}"; do
                            echo "${i}"
                        done | sort -u
                    )
                )
                for default_module in "${default_modules[@]}"; do
                    echo "  - ${default_module}"
                done | sort -u
                for non_default_module in "${non_default_modules[@]}"; do
                    echo "  * ${non_default_module}"
                done | sort -u
                exit
                ;;
            h)
                if [[ "${#specific_modules[@]}" -eq 0 ]]; then
                    usage
                else
                    for specific_module in "${specific_modules[@]}"; do
                        "${WORK_DIR}"/bin/glow-"${arch}" \
                            "${specific_module%%run.sh*}"/readme.md
                    done
                fi
                exit
                ;;
            m)
                if [[ -f "${WORK_DIR}"/modules/"${OPTARG}"/run.sh ]]; then
                    chmod u+x "${WORK_DIR}"/modules/"${OPTARG}"/run.sh
                    specific_modules+=("${WORK_DIR}/modules/${OPTARG}/run.sh")
                else
                    LOGWARNING "模块入口脚本不存在: ${WORK_DIR}/modules/${OPTARG}/run.sh"
                fi
                ;;
            a)
                specific_modules[${#specific_modules[@]} - 1]+=" ${OPTARG}"
                ;;
            *)
                LOGERROR "错误参数: $*"
                exit 255
                ;;
            esac
        done
        cleanup
        if [[ -n ${specific_modules[*]} ]]; then
            mkdir -p "${RESULT_DIR}" "${WARN_DIR}" "${LOG_DIR}" "${TMP_DIR}"
            for module_script in "${specific_modules[@]}"; do
                (
                    # echo "${module_script}"
                    ${module_script}
                )
            done
            LOGINFO "串行检查结束"
            printf "%0.s#" $(seq 1 "$(stty size | cut -f 2 -d ' ')")
            echo ""
            warn_files=()
            mapfile -t warn_files < <(find "${WARN_DIR}" -type f ! -name ".gitignore")
            if [[ ${#warn_files[@]} -gt 1 ]]; then
                LOGWARNING 执行报错汇总信息
                echo -e "\\033[1;31m"
                for warn_file in "${warn_files[@]}"; do
                    awk '{$1="";$2="";$3="";$4="";print "-",$0}' <"${warn_file}"
                done
                echo -e "\\033[0;39m"
            else
                LOGSUCCESS 检查未发现明显问题.
            fi
            LOGDEBUG "以下压测模块对性能消耗较大, 可能影响业务程序工作. 不在默认执行列表内, 如有需要请手工执行"
            LOGDEBUG "$0 -m network_connection # 判断本机是否能 ping 通给定的重要节点列表"
            LOGDEBUG "$0 -m stress # 压测CPU,内存,存储IO"
            LOGDEBUG "$0 -m iperf3 # 带宽测试"
            LOGDEBUG "$0 -m fio # 存储性能检测"
            LOGINFO "检查信息汇总: ${log_file}"
            LOGINFO "检查信息详情: ${LOG_DIR}/${DATETIME}"
        else
            LOGERROR "未指定至少一个有效模块"
            usage
        fi
    fi
}

main "$@"
