#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
set -o errexit    # Exit immediately if a command exits with a non-zero status (same as set -e)
set -o nounset    # Treat unset variables and parameters as an error (same as set -u)
set -o pipefail   # If any command in a pipeline fails, the pipeline returns an error code
set +o posix      # Enable POSIX mode for more portable behavior (may disable some Bash-specific extensions)
shopt -s nullglob # When no files match a glob pattern, expand to nothing instead of the pattern itself

usage() {
    echo ""
    echo "    notice:  monitor process run state"
    echo ""
    echo "    usage:   $0 <mode> <process_pattern> <delay_interval>"
    echo "                 mode:  PID/PNAME"
    echo "                 process_pattern:  process name"
    echo "                 delay_interval: The delay between updates in seconds. Minimum is 2 seconds."
    echo ""
    echo "    example: $0 PNAME 'querydaemon' 5"
    echo ""
}

get_process_id() {
    local mode="$1" process_pattern="$2"
    case "${mode}" in
    PID)
        if [[ "${process_pattern}" =~ ^[0-9]+$ ]]; then
            echo "${process_pattern}"
        else
            echo "ERROR: process_pattern must be a valid PID when mode is PID"
            exit 1
        fi
        ;;
    PNAME)
        pgrep -f "${process_pattern}" | head -n 1
        ;;
    *)
        echo "ERROR: mode must be PID or PNAME"
        exit 1
        ;;
    esac
}

get_cpu_used_percentage() {
    local proc_id="$1" sleep_interval="$2"
    local cpu_stat_1 cpu_total_time_1 cpu_idle_time_1 cpu_iowait_time_1 proc_time_1
    local cpu_stat_2 cpu_total_time_2 cpu_idle_time_2 cpu_iowait_time_2 proc_time_2
    local idle_percentage iowait_percentage proc_cpu_percentage total_diff
    if ! ps -q "$proc_id" &>/dev/null; then
        echo "Process $proc_id does not exist."
        return 1
    fi
    cpu_stat_1="$(head -n 1 /proc/stat | cut -d ' ' -f 2-)"
    cpu_total_time_1="$(echo "${cpu_stat_1}" | awk '{sum=0; for(i=1;i<=NF;i++) sum += $i} END {print sum}')"
    cpu_idle_time_1="$(echo "${cpu_stat_1}" | awk '{print $4}')"
    cpu_iowait_time_1="$(echo "${cpu_stat_1}" | awk '{print $5}')"
    proc_time_1="$(awk '{print $14+$15+$16+$17}' /proc/"${proc_id}"/stat)"
    sleep "${sleep_interval}"
    cpu_stat_2="$(head -n 1 /proc/stat | cut -d ' ' -f 2-)"
    cpu_total_time_2="$(echo "${cpu_stat_2}" | awk '{sum=0; for(i=1;i<=NF;i++) sum += $i} END {print sum}')"
    cpu_idle_time_2="$(echo "${cpu_stat_2}" | awk '{print $4}')"
    cpu_iowait_time_2="$(echo "${cpu_stat_2}" | awk '{print $5}')"
    proc_time_2="$(awk '{print $14+$15+$16+$17}' /proc/"${proc_id}"/stat)"

    total_diff="$((cpu_total_time_2 - cpu_total_time_1))"
    if [[ "${total_diff}" -eq 0 ]]; then
        echo "0 0 0"
        return 0
    fi

    idle_percentage="$((100 * (cpu_idle_time_2 - cpu_idle_time_1) / total_diff))"
    iowait_percentage="$((100 * (cpu_iowait_time_2 - cpu_iowait_time_1) / total_diff))"
    proc_cpu_percentage="$((100 * (cpu_cnt * (proc_time_2 - proc_time_1)) / total_diff))"
    echo "${idle_percentage} ${iowait_percentage} ${proc_cpu_percentage}"
}

get_process_rss_size() {
    local proc_id="$1"
    local rss_size=0
    if ! ps -q "${proc_id}" &>/dev/null; then
        echo "Process ${proc_id} does not exist."
        return 1
    fi
    rss_size="$(awk '/^Rss:/{s+=$2}END{printf "%d",s/1024}' /proc/"${proc_id}"/smaps)"
    echo "${rss_size}"
}

get_process_swap_size() {
    local proc_id="$1"
    local swap_size=0
    if ! ps -q "${proc_id}" &>/dev/null; then
        echo "Process ${proc_id} does not exist."
        return 1
    fi
    swap_size="$(awk '/^Swap:/{s+=$2}END{printf "%d",s/1024}' /proc/"${proc_id}"/smaps)"
    echo "${swap_size}"
}

get_process_fd_cnt() {
    local proc_id="$1"
    if ! ps -q "${proc_id}" &>/dev/null; then
        echo "Process ${proc_id} does not exist."
        return 1
    fi
    local fd_cnt
    fd_cnt=$(find "/proc/${proc_id}/fd" -mindepth 1 -maxdepth 1 | wc -l)
    echo "${fd_cnt}"
}

###############################################################################

if [ $# -ne 3 ]; then
    usage
    exit 0
fi

mode="$1"
process_pattern="$2"
delay_interval="$3"
if [ "${mode}" != "PID" ] && [ "${mode}" != "PNAME" ]; then
    echo "ERROR: mode must be PID or PNAME"
    usage
    exit 1
fi
if [ -z "${process_pattern}" ]; then
    echo "ERROR: process_pattern must not be empty"
    usage
    exit 1
fi
if [ "${delay_interval}" -lt 2 ]; then
    echo "WARN: sleep time less than 2, set to 2"
    delay_interval=2
fi

cpu_cnt="$(nproc)"
mem_total_size="$(awk '/^MemTotal:/{printf "%d", $2/1024/1024}' /proc/meminfo)"

index=0

while true; do
    date_str=$(date "+%F %T")

    page_flag="$((index % 50))"

    if [[ "${page_flag}" -eq 0 ]]; then
        printf "%-20s|%-9s|%-8s|%-8s|%-10s|%-10s|%-9s|%-12s|%-9s|%-8s\n" \
            "DateTime" "cpu(cnt)" "mem(GB)" "idle(%)" "iowait(%)" "pid" "cpu(%)" "mem(MB)" "swap(MB)" "fd(cnt)"
    fi

    index="$((index + 1))"

    proc_id="$(get_process_id "${mode}" "${process_pattern}")"
    proc_cnt="$(echo "${proc_id}" | wc -w)"

    if [[ "${proc_cnt}" -ne 1 ]]; then
        echo -e "${date_str}\tcan not get only process id, reset <process_pattern>: ${proc_id}"
        exit 1
    fi

    cpu_used_percentage_list="$(get_cpu_used_percentage "${proc_id}" "${delay_interval}")"

    all_idle="$(echo "${cpu_used_percentage_list}" | awk '{print $1}')"
    all_iowait="$(echo "${cpu_used_percentage_list}" | awk '{print $2}')"

    proc_cpu_used=$(echo "${cpu_used_percentage_list}" | awk '{print $3}')
    proc_mem_used=$(get_process_rss_size "${proc_id}")
    proc_swap_used=$(get_process_swap_size "${proc_id}")
    proc_fd_cnt=$(get_process_fd_cnt "${proc_id}")

    printf "%-20s|%9d|%8.1f|%8d|%10d|%10d|%9d|%12.1f|%9d|%8d\n" \
        "${date_str}" \
        "${cpu_cnt}" \
        "${mem_total_size}" \
        "${all_idle}" \
        "${all_iowait}" \
        "${proc_id}" \
        "${proc_cpu_used}" \
        "${proc_mem_used}" \
        "${proc_swap_used}" \
        "${proc_fd_cnt}"
done
