#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034,SC2046,SC2086,SC2116,SC2154
set -o errexit
set -o nounset
set -o pipefail
set +o posix
shopt -s nullglob

WORK_DIR="$(dirname "$(readlink -f "$0")")" && cd "${WORK_DIR}" || exit 99
script_name="$(basename "$0" 2>/dev/null)"

if ! "${TSC_FUNC:-false}"; then
    source ${WORK_DIR}/../../func
fi

get_cpu_info() {
    local cpu_model cpu_cnt cpu_arch
    cpu_model="$(awk -F : '/model name/{print $2}' /proc/cpuinfo | sort -u | sed 's/^\s*//')"
    cpu_cnt="$(lscpu | awk '/^Socket\(s\):/{print $2}')"
    jq -n --arg model "$cpu_model" --argjson cnt "$cpu_cnt" \
        '{cpu: {cpu_model: $model, cpu_cnt: $cnt}}'
}

get_mem_info() {
    local mem_info

    mapfile -t mem_info < <(
        dmidecode -t17 | grep -vP "^\s*$|^\s*#" | grep -P '^\s*Size:|^\s*Locator:' |
            sed 'N;s/\n/\t/g' |
            grep -v "No Module Installed"
    )

    for line in "${mem_info[@]}"; do
        size_val="$(awk '{print $2}' <<<"${line}")"
        size_unit="$(awk '{print $3}' <<<"${line}")"
        locator_val="$(cut -d: -f3- <<<"${line}" | sed 's/^ *//')"
        if [[ "${size_unit}" == "MB" ]]; then
            size_val="$(awk "BEGIN{printf \"%.2f\", ${size_val} / 1024}")"
        elif [[ "${size_unit}" != "GB" ]]; then
            continue
        fi
        jq -n \
            --arg locator "${locator_val}" \
            --argjson size "${size_val}" \
            '{"size": $size, locator: $locator, unit: "G"}'
    done |
        jq -s '{memory: .}'
}

get_serial_number() {
    local sn_file="${original_logfile}"
    local invalid_sns=('1234567890' '01234567890' '0000000000' 'To be filled by O.E.M.' '')
    local sn=""

    if [[ -f "${sn_file}" ]]; then
        sn=$(jq -r .sn "${sn_file}" 2>/dev/null || echo "")
    fi

    if [[ -z "${sn}" ]]; then
        sn="$(dmidecode -s system-serial-number 2>/dev/null | grep -v '#' | head -n1 || echo "")"
        for invalid_sn in "${invalid_sns[@]}"; do
            if [[ "${sn}" == "${invalid_sn}" ]]; then
                sn="$(dmidecode -s baseboard-serial-number 2>/dev/null | head -n1 || echo "")"
                break
            fi
        done
        for invalid_sn in "${invalid_sns[@]}"; do
            if [[ "${sn}" == "${invalid_sn}" ]]; then
                sn="None"
                break
            fi
        done
    fi

    if [[ -z "${sn}" ]]; then
        sn="None"
    fi

    jq -n --arg sn "${sn}" '{sn: $sn}'
}

get_disk_info() {
    local machine_type="$1"
    local line ctl_no
    local model lsblk_line model size type
    local da_disks raid_disks disk_detail
    local da_disk_detail
    raid_disks=()
    da_disks=()
    disk_detail=()
    if [[ "${machine_type}" == "pm" ]]; then
        # 判断 RAID 卡类型
        # Adaptec
        # LSI|AVAGO|DELL|MegaRAID
        if lspci | grep -qiP "Adaptec"; then
            if [[ -f /bin/arcconf ]]; then
                arcconf_bin="/bin/arcconf"
            fi
            if [[ -f /sbin/arcconf ]]; then
                arcconf_bin="/sbin/arcconf"
            fi
            if [[ -f "${WORK_DIR}/../packages/arcconf/arcconf-$(arch)" ]]; then
                arcconf_bin="${WORK_DIR}/../packages/arcconf/arcconf-$(arch)"
            fi
            mapfile -t raid_detail < <(
                "${arcconf_bin}" GETCONFIG 1 PD |
                    awk -F ':' '
                        BEGIN { i=0 }
                        /^\s*Device #/{ i+=1 }
                        /^\s*Device is a Hard drive/{ r[i]["flag"]=1 }
                        /^\s*Model/{ gsub(/^\s+|\s+$/,"",$2); r[i]["model"]=$2 }
                        /^\s*Serial number/{ gsub(/^\s+|\s+$/,"",$2); r[i]["serial"]=$2 }
                        /^\s*World-wide name/{ gsub(/^\s+|\s+$/,"",$2); r[i]["wwn"]=$2 }
                        /^\s*Total Size/{ 
                            gsub(/^\s+|\s+$/,"",$2)
                            if ($2~"M") size=$2/1024/1024
                            if ($2~"G") size=$2/1024
                            if ($2~"T") size=$2
                            if ($2~"P") size=$2*1024
                            r[i]["size"]=size
                            }
                        END {
                            for (a in r) {
                                if (r[a]["flag"]==1) {
                                printf "{\"type\":\"raid\",\"model\":\"%s\",\"serial\":\"%s\",\"wwn\":\"%s\",\"size\":%.2f},\"unit\":\"T\"\n", \
                                    r[a]["model"], r[a]["serial"],r[a]["wwn"],r[a]["size"]
                                }
                            }
                        }
                    '
            )
            disk_detail+=("${raid_detail[@]}")
        elif lspci |
            grep -qiP "LSI|AVAGO|MegaRAID|(RAID bus controller: Intel Corporation Lewisburg)"; then
            local storcli_bin
            if [[ -f /bin/storcli ]]; then
                storcli_bin="/bin/storcli"
            fi
            if [[ -f /opt/MegaRAID/storcli/storcli64 ]]; then
                storcli_bin="/opt/MegaRAID/storcli/storcli64"
            fi
            if [[ -f "${WORK_DIR}/../packages/storcli64/storcli64-noarch" ]]; then
                storcli_bin="${WORK_DIR}/../packages/storcli64/storcli64-noarch"
            fi
            ctl_no=$(
                "${storcli_bin}" show |
                    grep -PA2 "Ctl\s+Model" |
                    tail -n1 | awk '{print $1}'
            )
            mapfile -t raid_detail < <(
                "${storcli_bin}" /c"${ctl_no}" show |
                    sed -nr '/^PD LIST :/,/EID=Enclosure Device ID/p' |
                    awk '
                        /^(([0-9]+)?|\s*?):[0-9]/{
                            model=""
                            for (i=12;i<=NF-2;i++) model=model" "$i
                            gsub(/^\s+/,"",model)
                            if ($6~/T/) size=int($5*10^2+0.5)/10^2
                            if ($6~/G/) size=int($5*10^2/1024+0.5)/10^2
                            if ($6~/M/) size=int($5*10^2/1024/1024+0.5)/10^2
                            print "{\"type\":\"raid\",\"size\":"size",\"model\":\""model"\"}"
                        }'
            )
            disk_detail+=("${raid_detail[@]}")
        fi
    fi
    # 判断是不是RAID盘, 条件慢慢补充
    # TRAN 是空, 且整行中没有 Virtual disk|VMware
    # VENDOR = LSI|DELL|HP|AVAGO
    # MODEL 含有 LOGICAL
    mapfile -t lsblk_info < <(lsblk -Pdo NAME,MODEL,SERIAL,SIZE,TYPE,VENDOR,TRAN,WWN | grep disk)
    # while read -r line; do
    for lsblk_line in "${lsblk_info[@]}"; do
        declare -A disk_info=()
        line="${lsblk_line}"
        while [[ $line =~ ([A-Z]+)=\"([^\"]*)\" ]]; do
            key="${BASH_REMATCH[1]}"
            val="${BASH_REMATCH[2]}"
            key_lc="${key,,}"
            disk_info["${key_lc}"]="$val"
            line=${line#*"$key=\"$val\""}
        done

        name="${disk_info[name]:-}"
        model="${disk_info[model]:-}"
        serial="${disk_info[serial]:-}"
        size="${disk_info[size]:-}"
        type="${disk_info[type]:-}"
        vendor="${disk_info[vendor]:-}"
        tran="${disk_info[tran]:-}"
        wwn="${disk_info[wwn]:-}"

        if [[ -z "${name}" ]] || [[ -z "${size}" ]] || [[ "${type}" != disk ]]; then
            continue
        fi

        if [[ "${size}" == *T ]]; then
            size="$(echo "${size}" | grep -oP '\d+(\.\d+)?')"
        elif [[ "${size}" == *G ]]; then
            size_val="$(echo "${size}" | grep -oP '\d+(\.\d+)?')"
            size="$(awk -v val="${size_val}" 'BEGIN{printf "%.2f", val / 1024}')"
        fi
        if { [[ -z "${tran}" ]] && ! echo "${lsblk_line}" | grep -qP "Virtual disk|VMware"; } ||
            echo "${model}" | grep -q 'LOGICAL' ||
            echo "${vendor}" | grep -qP "LSI|DELL|HP|AVAGO"; then
            raid_disks+=("${name}")
        else
            da_disks+=("${name}")
            da_disk_detail="$(
                jq -n \
                    --arg serial "${serial}" \
                    --arg model "${model}" \
                    --argjson size "${size}" \
                    --arg type "direct" \
                    '{serial: $serial, model: $model, "size": $size, type: $type, unit: "T"}'
            )"
            # 如果这个盘不在RAID卡上到或为虚拟磁盘则加入直通盘
            if (
                ! echo "${disk_detail[*]}" | grep -iq "${serial}" ||
                    echo "${lsblk_line}" | grep -qP "Virtual disk|VMware" ||
                    { [[ -n "${wwn}" ]] && ! echo "${disk_detail[*]}" | grep -iq "${wwn}"; }
            ); then
                disk_detail+=("${da_disk_detail}")
            fi
        fi
    done
    [[ "${#disk_detail[@]}" -ge 1 ]] &&
        printf '%s\n' "${disk_detail[@]}" | jq -s '{storage: .}'
}

test_writability() {
    local mount_point="$1"
    local temp_file
    local TEMP_FILE_PREFIX="test_rw_"
    temp_file=$(mktemp "${mount_point}/${TEMP_FILE_PREFIX}XXXXX")

    if [[ -f "$temp_file" ]]; then
        unlink "$temp_file" &>/dev/null
        return 0
    else
        return 1
    fi
}

get_storage_runtime_info() {
    local json_array="[]"
    local mount_info
    local -a FILESYSTEMS=(ext2 ext3 ext4 btrfs xfs vfat ntfs jfs reiserfs zfs)
    local FS_TYPES
    FS_TYPES="$(
        IFS=,
        echo "${FILESYSTEMS[*]}"
    )"

    mapfile -t mount_info < <(
        findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS -l -t "${FS_TYPES}"
    )

    for line in "${mount_info[@]}"; do
        local mount_point fstype options source_device
        mount_point="$(echo "$line" | awk '{print $1}')"
        source_device="$(echo "$line" | awk '{print $2}')"
        fstype="$(echo "$line" | awk '{print $3}')"
        options="$(echo "$line" | awk '{print $4}')"

        local df_size_output
        df_size_output="$(df -B1 --portability "${mount_point}" 2>/dev/null || echo "0 0")"
        local size_total_bytes size_used_bytes
        size_total_bytes="$(echo "${df_size_output}" | tail -n 1 | awk '{print $2}')"
        size_used_bytes="$(echo "${df_size_output}" | tail -n 1 | awk '{print $3}')"

        local df_inode_output
        df_inode_output="$(df -i --portability "${mount_point}" 2>/dev/null || echo "0 0")"
        local inode_total inode_used
        inode_total="$(echo "${df_inode_output}" | tail -n 1 | awk '{print $2}')"
        inode_used="$(echo "${df_inode_output}" | tail -n 1 | awk '{print $3}')"

        local size_total_gb=0
        local size_used_gb=0
        if [[ "$size_total_bytes" -gt 0 ]]; then
            size_total_gb="$(awk "BEGIN {printf \"%.2f\", $size_total_bytes / (1024^3)}")"
        fi
        if [[ "$size_used_bytes" -gt 0 ]]; then
            size_used_gb="$(awk "BEGIN {printf \"%.2f\", $size_used_bytes / (1024^3)}")"
        fi

        local size_used_percent=0
        if [[ "$size_total_bytes" -gt 0 ]]; then
            size_used_percent="$(awk "BEGIN {printf \"%.2f\", ($size_used_bytes / $size_total_bytes) * 100}")"
        fi

        local inode_used_percent=0
        if [[ "$inode_total" -gt 0 ]]; then
            inode_used_percent="$(awk "BEGIN {printf \"%.2f\", ($inode_used / $inode_total) * 100}")"
        fi

        local writable=false
        if [[ "$options" =~ rw ]]; then
            if test_writability "${mount_point}"; then
                writable=true
            fi
        fi

        json_array="$(echo "${json_array}" | jq \
            --arg target "${mount_point}" \
            --arg source "${source_device}" \
            --arg fs "${fstype}" \
            --argjson size_total "$size_total_gb" \
            --argjson size_used "$size_used_gb" \
            --argjson inode_total "$inode_total" \
            --argjson inode_used "$inode_used" \
            --argjson size_used_percent "$size_used_percent" \
            --argjson inode_used_percent "$inode_used_percent" \
            --argjson rw "${writable}" \
            '. + [{
                target: $target,
                source: $source,
                filesystem: $fs,
                size: {
                    total: $size_total,
                    used: $size_used,
                    used_percent: $size_used_percent,
                    unit: "G"
                },
                inodes: {
                    total: $inode_total,
                    used: $inode_used,
                    used_percent: $inode_used_percent
                },
                writable: $rw
            }]')"
    done
    echo "$json_array"
}

get_memory_runtime_info() {
    local mem_line swap_line
    mem_line="$(free -b | awk 'NR==2{print $2, $3}')"
    swap_line="$(free -b | awk 'NR==3{print $2, $3}')"
    read -r mem_total_bytes mem_used_bytes <<<"$mem_line"
    read -r swap_total_bytes swap_used_bytes <<<"$swap_line"

    local mem_total_g mem_used_g swap_total_g swap_used_g
    mem_total_g="$(awk -v m="${mem_total_bytes}" 'BEGIN {printf "%.2f", m / (1024^3)}')"
    mem_used_g="$(awk -v m="${mem_used_bytes}" 'BEGIN {printf "%.2f", m / (1024^3)}')"
    swap_total_g="$(awk -v m="${swap_total_bytes}" 'BEGIN {printf "%.2f", m / (1024^3)}')"
    swap_used_g="$(awk -v m="${swap_used_bytes}" 'BEGIN {printf "%.2f", m / (1024^3)}')"

    # 新增行: 计算 RAM 使用率
    local mem_used_percent=0
    if ((mem_total_bytes > 0)); then
        mem_used_percent="$(awk "BEGIN {printf \"%.2f\", ($mem_used_bytes / $mem_total_bytes) * 100}")"
    fi

    # 新增行: 计算 Swap 使用率
    local swap_used_percent=0
    if ((swap_total_bytes > 0)); then
        swap_used_percent="$(awk "BEGIN {printf \"%.2f\", ($swap_used_bytes / $swap_total_bytes) * 100}")"
    fi

    # 修改行: jq命令更新，添加了used_percent字段
    jq -n \
        --argjson mem_total "${mem_total_g}" \
        --argjson mem_used "${mem_used_g}" \
        --argjson mem_used_percent "${mem_used_percent}" \
        --argjson swap_total "${swap_total_g}" \
        --argjson swap_used "${swap_used_g}" \
        --argjson swap_used_percent "${swap_used_percent}" \
        '{
            ram: {
                total: $mem_total,
                used: $mem_used,
                used_percent: $mem_used_percent,
                unit: "G"
            },
            swap: {
                total: $swap_total,
                used: $swap_used,
                used_percent: $swap_used_percent,
                unit: "G"
            }
        }'
}

get_cpu_runtime_info() {
    local first_sample second_sample
    local user nice system idle iowait irq softirq steal guest guest_nice
    local total_jiffies idle_jiffies iowait_jiffies

    read -r _ user nice system idle iowait irq softirq steal guest guest_nice </proc/stat
    first_sample=(
        "${user}"
        "${nice}"
        "${system}"
        "${idle}"
        "${iowait}"
        "${irq}"
        "${softirq}"
        "${steal}"
        "${guest}"
        "${guest_nice}"
    )
    sleep 1
    read -r _ user nice system idle iowait irq softirq steal guest guest_nice </proc/stat
    second_sample=(
        "${user}"
        "${nice}"
        "${system}"
        "${idle}"
        "${iowait}"
        "${irq}"
        "${softirq}"
        "${steal}"
        "${guest}"
        "${guest_nice}"
    )

    local total_jiffies="$((second_sample[0] - first_sample[0] + \
        second_sample[1] - first_sample[1] + \
        second_sample[2] - first_sample[2] + \
        second_sample[3] - first_sample[3] + \
        second_sample[4] - first_sample[4] + \
        second_sample[5] - first_sample[5] + \
        second_sample[6] - first_sample[6] + \
        second_sample[7] - first_sample[7] + \
        second_sample[8] - first_sample[8] + \
        second_sample[9] - first_sample[9]))"
    local idle_jiffies="$((second_sample[3] - first_sample[3]))"
    local iowait_jiffies="$((second_sample[4] - first_sample[4]))"

    local cpu_used_percentage=0
    local iowait_percentage=0

    if [[ "$total_jiffies" -gt 0 ]]; then
        cpu_used_percentage="$(awk "BEGIN {printf \"%.2f\", (100.0 - ($idle_jiffies / $total_jiffies) * 100)}")"
        iowait_percentage="$(awk "BEGIN {printf \"%.2f\", ($iowait_jiffies / $total_jiffies) * 100}")"
    fi

    jq -n --argjson cpu_used "${cpu_used_percentage}" \
        --argjson iowait "${iowait_percentage}" \
        '{
            used_percent: $cpu_used,
            iowait_percent: $iowait
        }'
}

runtime() {
    local storage_json memory_json cpu_json
    storage_json="$(get_storage_runtime_info)"
    memory_json="$(get_memory_runtime_info)"
    cpu_json="$(get_cpu_runtime_info)"

    if [[ -z "$storage_json" ]]; then
        storage_json="[]"
    fi
    jq -n --argjson storage_data "${storage_json}" \
        --argjson memory_data "${memory_json}" \
        --argjson cpu_data "$cpu_json" \
        '{
            storage: $storage_data, 
            memory: $memory_data,
             cpu: $cpu_data
        }'
}

main() {
    local system_info manufacturer sn cpu_info mem_info disk_info machine_type
    system_info="$(detect_system_info)"
    machine_type="$(echo $system_info | jq -r .machine_type)"
    sn="$(get_serial_number)"
    manufacturer="$(dmidecode -s system-manufacturer | grep -vP "^\s*$|^\s*#")"
    cpu_info="$(get_cpu_info)"
    mem_info="$(get_mem_info)"
    disk_info="$(get_disk_info "${machine_type}")"
    echo "${system_info}" |
        jq --argjson sn "${sn}" '. + $sn' |
        jq --arg manufacturer "${manufacturer}" '. + {manufacturer: $manufacturer}' |
        jq --argjson cpu_info "${cpu_info}" '. + $cpu_info' |
        jq --argjson mem_info "${mem_info}" '. + $mem_info' |
        jq --argjson disk_info "${disk_info}" '. + $disk_info'
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --contract_no <contract_no>   Specify contract number (optional, requires parameter)
  --location <location>         Specify location (optional, requires parameter)
  --runtime                     Gathter runtime information
  --help                        Show this help message and exit
EOF
}

OPTIONS=$(getopt --options="" --longoptions=contract_no:,location:,help,runtime, --name "$0" -- "$@") || {
    usage
    exit 1
}
eval set -- "$OPTIONS"

contract_no=""
location=""

while true; do
    case "$1" in
    --runtime)
        runtime
        exit "$?"
        ;;
    --contract_no)
        contract_no="$2"
        shift 2
        ;;
    --location)
        location="$2"
        shift 2
        ;;
    --help)
        usage
        exit 0
        ;;
    --)
        shift
        break
        ;;
    *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
done
mkdir -p /var/log/tsc/
original_logfile="/var/log/tsc/tsc_iaas_info.json"

result="$(
    main |
        jq -r --arg contract_no "${contract_no}" --arg location "${location}" '
  . + (if $contract_no != "" then {contract_no: $contract_no} else {} end)
    + (if $location != "" then {location: $location} else {} end)
'
)"
if [[ -s "${original_logfile}" ]]; then
    original_info="$(jq -r . <"${original_logfile}")"
else
    original_info='{}'
fi

final_result=$(
    jq --argjson new "${result}" \
        --argjson original "${original_info}" '
    $new * $original
' <<<'{}'
)

echo "${final_result}" | tee "${original_logfile}"
