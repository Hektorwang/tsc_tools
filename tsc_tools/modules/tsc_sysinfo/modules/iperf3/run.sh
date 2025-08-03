#!/bin/bash
#
# 使用 iperf3 进行带宽测试
#
#################################### cc=79 ####################################
# shellcheck disable=SC1091,SC2153,SC2154
set +o posix
CUR_DIR="$(dirname "$(readlink -f "$0")")" && cd "${CUR_DIR}" || exit 99
module_cname="使用 iperf3 进行带宽测试"
module_name=$(basename "${CUR_DIR}")
datetime="$(date +'%Y%m%d%H%M%S')"

# 检查引入 func
if [[ ! "$(type -t LOGINFO)" == "function" ]]; then
    if [[ -d "${WORK_DIR}" ]]; then
        source "${WORK_DIR}"/bin/func &>/dev/null
    else
        WORK_DIR=$(readlink -f "${CUR_DIR}"/../../)
        source "${CUR_DIR}"/../../bin/func &>/dev/null
    fi
fi
LOGINFO "${module_cname}"

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

if [[ ! -f "${CONF_FILE}" ]]; then
    logerror 未找到主配置文件
    exit 1
fi

read_conf "${CONF_FILE}" "${module_name}" server_ssh_cmd
read_conf "${CONF_FILE}" "${module_name}" bandwidth_threshold
read_conf "${CONF_FILE}" "${module_name}" transmit_seconds
read_conf "${CONF_FILE}" "${module_name}" default_netspeed

logerror "暂不支持, 请使用 批量执行 基础环境完工检查 功能进行测试"

# 解析并校验各参数
if server_arch=$(
    tmout 5 ${server_ssh_cmd} -o LogLevel=QUIET -o StrictHostKeyChecking=no "arch"
); then
    ssh_cmd="${server_ssh_cmd} -o LogLevel=QUIET -o StrictHostKeyChecking=no"
    server_host=$(
        ${ssh_cmd} -v "exit" 2>&1 |
            awk -F '[][]' '/^debug1: Connecting to/{print $2;exit}'
    )
else
    logerror "无法免交互 ssh 服务端 ${ssh_cmd}"
    exit 2
fi

if bw_threshold=${bandwidth_threshold%%%} &&
    [[ ${bw_threshold} -gt 0 ]] &&
    [[ ${bw_threshold} -le 100 ]]; then
    :
else
    logerror "带宽阈值配置错误 bandwidth_threshold=${bandwidth_threshold}"
    exit 2
fi

if ! [[ "${transmit_seconds}" =~ ^[0-9]+$ ]]; then
    logwarning "测试时长配置错误: transmit_seconds=${transmit_seconds}"
    exit 2
fi

if [[ "${default_netspeed}" =~ ^[0-9]+[KMG]b/s$ ]]; then
    d_netspeed=${default_netspeed%[kMG]b/s}
    case "${default_netspeed: -4}" in
    Kb/s) ((d_netspeed *= 1000)) ;;
    Mb/s) ((d_netspeed *= 1000 ** 2)) ;;
    Gb/s) ((d_netspeed *= 1000 ** 3)) ;;
    *)
        logwarning "网口默认速率配置错误: default_netspeed=${default_netspeed}"
        exit 2
        ;;
    esac
else
    logwarning "网口默认速率配置错误: default_netspeed=${default_netspeed}"
    exit 2
fi

if [[ -z "${server_arch}" ]]; then
    logerror "${module_cname}": 未获取到服务端处理器架构
    exit 2
fi

if [[ ! -f "/opt/tsc/packet/iperf3/iperf3-${server_arch}" ]]; then
    logerror "${module_cname}": 无法找到服务端对应处理器架构的 iperf3 工具
    exit 3
fi

if ! command -v /bin/iperf3 &>/dev/null; then
    logerror "${module_cname}": 本设备未安装 iperf3 请安装最新版 tsc 工具集.
    exit 3
fi

if ! command -v /bin/jq &>/dev/null; then
    logerror "${module_cname}": 本设备未安装 jq 请安装最新版 tsc 工具集.
    exit 3
fi
LOGINFO 在服务端主机上开启 iperf3 服务端, 请稍候.

LOGDEBUG "${ssh_cmd} 'rm -f /tmp/iperf3;cat >/tmp/iperf3' </opt/tsc/packet/iperf3/iperf3-${server_arch}"
LOGDEBUG "${ssh_cmd} 'chmod u+x /tmp/iperf3;/tmp/iperf3 --server --daemon --json'"
${ssh_cmd} 'rm -f /tmp/iperf3
    cat >/tmp/iperf3' <"/opt/tsc/packet/iperf3/iperf3-${server_arch}"
${ssh_cmd} "kill -9 \$(pgrep -f 'iperf3 --server --daemon --json') &>/dev/null"
if ! ${ssh_cmd} "chmod u+x /tmp/iperf3
    /tmp/iperf3 --server --daemon --json"; then
    logerror 无法在服务端开启 iperf3.
    exit 4
fi

LOGINFO "在客户端开启 iperf3 连接服务端, 测试时长(秒): ${transmit_seconds}".
iperf3_log="$(readlink -f "${result_dir}"/"${module_name}".log)"
LOGDEBUG iperf3 \
    --client "${server_host}" \
    --parallel 10 \
    --time "${transmit_seconds}" \
    --json --get-server-output \
    --logfile "${iperf3_log}"

if ! ( 
    (for ((sec = 1; sec <= "${transmit_seconds}"; sec++)); do
        echo -en "\r进度: ${sec} / ${transmit_seconds}"
        sleep 1
    done) &
    disown
    progress_bar_pid=$!
    iperf3 \
        --client "${server_host}" \
        --parallel 10 \
        --time "${transmit_seconds}" \
        --get-server-output --json \
        --logfile "${iperf3_log}" || (
        ${ssh_cmd} "kill -9 \$(pgrep -f 'iperf3 --server --daemon --json') &>/dev/null"
        kill -0 "${progress_bar_pid}" &>/dev/null &&
            kill -9 "${progress_bar_pid}"
        exit 1
    )
    ret=$?
    wait
    echo ""
    exit $ret
); then
    logerror 命令执行失败, 请检查日志: "${iperf3_log}"
    # 结束服务端的 iperf3
    ${ssh_cmd} "kill -9 \$(pgrep -f 'iperf3 --server --daemon --json') &>/dev/null"
    exit 3
else
    # 从 server 回显获取 ip 再获取网口, 再获取网口速率, 再计算和本机网口速率取小, 再计算阈值
    # 服务端本机 IP
    server_ip="$(/bin/jq '.server_output_json.start.connected[0].local_host' -rc "${iperf3_log}")"
    # 服务端通信网口速率
    server_netspeed=$(
        $ssh_cmd "
        mapfile -t nics < <(awk 'NR>2{print \$1}' /proc/net/dev)
        for nic in \${nics[@]}; do
            if ip a show \${nic%%:} | grep -q ${server_ip}; then
                server_nic=\${nic%%:}
                break
            fi
        done
        if [[ -z \${server_nic} ]]; then
            exit 1
        elif ! command -v ethtool &>/dev/null; then
            exit 2
        elif ! ethtool \${server_nic} |
                grep -oP '(?<=Speed: )\d+[KMG]b/s'; then
            exit 3
        elif ethtool -i \${server_nic}|grep -qP 'driver:.*?(virtio|vmx)'; then
            exit 4
        fi
        "
    )
    case $? in
    1)
        logwarning "无法根据服务端 IP: ${server_ip} 获取到通信网口, 服务端网口速率视为默认速率: ${default_netspeed}"
        server_netspeed="${default_netspeed}"
        ;;
    2)
        logwarning "服务端未安装 ethtool, 服务端网口速率视为默认速率: ${default_netspeed}"
        server_netspeed="${default_netspeed}"
        ;;
    3)
        logwarning "无法通过 ethtool ${server_nic}|grep -oP '(?<=Speed: )\d+[KMG]b/s' 获取服务端网口速率, 服务端网口速率视为默认速率: ${default_netspeed}"
        server_netspeed="${default_netspeed}"
        ;;
    4)
        logwarning "服务端为虚拟机, 服务端网口速率视为默认速率: ${default_netspeed}"
        server_netspeed="${default_netspeed}"
        ;;
    esac

    # 本机网口速率
    local_ip="$(/bin/jq .start.connected[0].local_host -rc "${iperf3_log}")"
    mapfile -t nics < <(awk 'NR>2{print $1}' /proc/net/dev)
    for nic in "${nics[@]}"; do
        if ip a show "${nic%%:}" | grep -q "${local_ip}"; then
            local_nic="${nic%%:}"
            break
        fi
    done
    if [[ -z "${local_nic}" ]]; then
        logwarning "无法根据本机 IP: ${local_ip} 获取到通信网口, 本机网口速率视为默认速率: ${default_netspeed}"
        local_netspeed="${default_netspeed}"
    elif ! command -v ethtool &>/dev/null; then
        logwarning "本机未安装 ethtool, 本机网口速率视为默认速率: ${default_netspeed}"
        local_netspeed="${default_netspeed}"
    elif ! local_netspeed="$(
        ethtool "${local_nic}" | grep -oP '(?<=Speed: )\d+[KMG]b/s'
    )"; then
        logwarning "本机为虚拟机, 本机网口速率视为默认速率: ${default_netspeed}"
        local_netspeed="${default_netspeed}"
    elif ethtool -i "${local_nic}" | grep -qP 'driver:.*?(virtio|vmx)'; then
        logwarning "无法通过 ethtool ${local_nic}|grep -oP '(?<=Speed: )\d+[KMG]b/s' 获取本机网口速率, 本机网口速率视为默认速率: ${default_netspeed}"
        local_netspeed="${default_netspeed}"
    fi
fi

if [[ "${server_netspeed}" =~ ^[0-9]+[KMG]b/s$ ]]; then
    s_netspeed=${server_netspeed%[kMG]b/s}
    case "${server_netspeed: -4}" in
    Kb/s) ((s_netspeed *= 1000)) ;;
    Mb/s) ((s_netspeed *= 1000 ** 2)) ;;
    Gb/s) ((s_netspeed *= 1000 ** 3)) ;;
    *)
        logwarning "服务端网口速率解析错误: ${server_netspeed}, 将视为默认速率: ${default_netspeed}"
        server_netspeed="${default_netspeed}"
        ;;
    esac
else
    logwarning "服务端网口速率解析错误: ${server_netspeed}, 将视为默认速率: ${default_netspeed}"
    server_netspeed="${default_netspeed}"
fi

if [[ "${local_netspeed}" =~ ^[0-9]+[KMG]b/s$ ]]; then
    l_netspeed=${local_netspeed%[kMG]b/s}
    case "${local_netspeed: -4}" in
    Kb/s) ((l_netspeed *= 1000)) ;;
    Mb/s) ((l_netspeed *= 1000 ** 2)) ;;
    Gb/s) ((l_netspeed *= 1000 ** 3)) ;;
    *)
        logwarning "本机网口速率解析错误: ${local_netspeed}, 将视为默认速率: ${default_netspeed}"
        local_netspeed="${default_netspeed}"
        ;;
    esac
else
    logwarning "本机网口速率解析错误: ${local_netspeed}, 将视为默认速率: ${default_netspeed}"
    local_netspeed="${default_netspeed}"
fi

# 取本地和服务端网口速率较小的算网速阈值
threshold="$(awk -v s="${s_netspeed}" -v l="${l_netspeed}" -v b="${bw_threshold}" '
    BEGIN {
        k=s<=l?s:l
        print int(k*b/100)
    }')"

# 测试网速
send_netspeed="$(/bin/jq -rc '.end.sum_sent.bits_per_second' "${iperf3_log}")"
receive_netspeed="$(/bin/jq -rc '.end.sum_received.bits_per_second' "${iperf3_log}")"
send_netspeed=${send_netspeed%%.*}
receive_netspeed=${receive_netspeed%%.*}

LOGINFO 单位:"bits/s". 服务端网口速率: "$(printf "%'d" ${s_netspeed})(${server_netspeed})", \
    本机网口速率: "$(printf "%'d" ${l_netspeed})(${local_netspeed})", \
    阈值: "$(printf "%'d" "${threshold}")"
LOGINFO 单位:"bits/s". 测试发送速率: "$(printf "%'d" "${send_netspeed}")", \
    测试接收速率: "$(printf "%'d" "${receive_netspeed}")"

status=0
if [[ "${send_netspeed}" -lt "${threshold}" ]]; then
    # logwarning "本机发送速率低于阈值: ${send_netspeed} < ${threshold}"
    ((status += 100))
fi
if [[ "${receive_netspeed}" -lt "${threshold}" ]]; then
    # logwarning "本机接收速率低于阈值: ${receive_netspeed} < ${threshold}"
    ((status += 200))
fi

case "${status}" in
0)
    LOGSUCCESS "${module_cname}": 本机发送和接收速率均高于阈值.
    ;;
100)
    logwarning "${module_cname}: 结束. 本机发送 ${server_ip} 速率(bits/s)低于阈值: $(printf "%'d" "${send_netspeed}") < $(printf "%'d" "${threshold}")"
    ;;
200)
    logwarning "${module_cname}: 结束. 本机接收 ${server_ip} 速率(bits/s)低于阈值: $(printf "%'d" "${receive_netspeed}") < $(printf "%'d" "${threshold}")"
    ;;
300)
    logwarning "${module_cname}: 结束. 本机发送 ${server_ip} 速率(bits/s)低于阈值: $(printf "%'d" "${send_netspeed}") < $(printf "%'d" "${threshold}")"
    logwarning "${module_cname}: 结束. 本机接收 ${server_ip} 速率(bits/s)低于阈值: $(printf "%'d" "${receive_netspeed}") < $(printf "%'d" "${threshold}")"
    ;;
esac
# 结束服务端的 iperf3
${ssh_cmd} "kill -9 \$(pgrep -f 'iperf3 --server --daemon --json') &>/dev/null"

exit "${status}"
