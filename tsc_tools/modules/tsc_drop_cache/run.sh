#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
set -o errexit    # Exit immediately if a command exits with a non-zero status (same as set -e)
set -o nounset    # Treat unset variables and parameters as an error (same as set -u)
set -o pipefail   # If any command in a pipeline fails, the pipeline returns an error code
set -o posix      # Enable POSIX mode for more portable behavior (may disable some Bash-specific extensions)
shopt -s nullglob # When no files match a glob pattern, expand to nothing instead of the pattern itself

MEM_USED_THRESHOLD="${1:-80}"

script_name="$(basename "$0" 2>/dev/null)"

export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export 'NLS_LANG=american_america.AL32UTF8'

export SETCOLOR_DEBUG="echo -en \\033[1;37m"
export SETCOLOR_NORMAL="echo -en \\033[0;39m"
export SETCOLOR_SUCCESS="echo -en \\033[1;32m"
export SETCOLOR_ERROR="echo -en \\033[1;31m"
export SETCOLOR_WARNING="echo -en \\033[1;33m"
readonly SETCOLOR_DEBUG SETCOLOR_NORMAL SETCOLOR_SUCCESS SETCOLOR_ERROR SETCOLOR_WARNING

script_name="$(basename "$0" 2>/dev/null)"

export TSC_FUNC=true
##################################################
# 向标准 (错误) 输出和指定文件中写入日志
# 所有日志函数返回值都是0, 执行日志函数的结果必为成功. 但是打印到屏幕是分为stdout和stderr的
# 全局变量:
#   log_file
# 参数:
#   日志内容
# 输出:
#   封装后的日志信息
##################################################
function __log() {
    local level="$1"
    shift
    local timestamp line message out_fd
    timestamp=$(date "+%F %T")
    line="${BASH_LINENO[1]:-0}"
    message="$*"
    case "$level" in
    DEBUG)
        ${SETCOLOR_DEBUG}
        out_fd="2"
        ;;
    INFO)
        ${SETCOLOR_NORMAL}
        out_fd="1"
        ;;
    SUCCESS)
        ${SETCOLOR_SUCCESS}
        out_fd="1"
        ;;
    WARNING)
        ${SETCOLOR_WARNING}
        out_fd="2"
        ;;
    ERROR)
        ${SETCOLOR_ERROR}
        out_fd="2"
        ;;
    *)
        ${SETCOLOR_NORMAL}
        out_fd="1"
        ;;
    esac
    {
        printf "%-23s | %-8s | %s:%s - %s\n" \
            "${timestamp}" "${level}" "${script_name}" "${line}" "${message}"
        ${SETCOLOR_NORMAL}
    } | tee -a "${log_file:-/dev/null}" >&"${out_fd}"
    return 0
}

function LOGDEBUG { __log "DEBUG" "$@"; }
function LOGINFO { __log "INFO" "$@"; }
function LOGSUCCESS { __log "SUCCESS" "$@"; }
function LOGWARNING { __log "WARNING" "$@"; }
function LOGERROR { __log "ERROR" "$@"; }

get_mem() {
    mem_total="$(free -m | awk '/^Mem:/{print $2}')"
    mem_used="$(free -m | awk '/^Mem:/{print $3}')"
    mem_used_percentage="$(
        awk -v used="$mem_used" -v total="$mem_total" '
    BEGIN {
        if (total == 0)
            printf "%d", 0
        else
            printf "%d", (used / total) * 100
    }'
    )"

    LOGINFO "Memory usage: ${mem_used_percentage}% (used: ${mem_used}MB, total: ${mem_total}MB)"
}
get_mem

if [ "${mem_used_percentage}" -gt "${MEM_USED_THRESHOLD}" ]; then
    LOGINFO "Memory usage is above ${MEM_USED_THRESHOLD}%: ${mem_used_percentage}%"
    if sync; then
        echo 3 >/proc/sys/vm/drop_caches
        LOGSUCCESS "Caches dropped successfully."
    else
        LOGERROR "Failed to sync before dropping caches." >&2
        exit 1
    fi
else
    LOGINFO "Memory usage is below or equal to ${MEM_USED_THRESHOLD}%: ${mem_used_percentage}%"
fi
