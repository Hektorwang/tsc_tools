#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034,SC2046,SC2086,SC2116,SC2154
set -o errexit
set -o nounset
set -o pipefail
set +o posix
shopt -s nullglob

WORK_DIR="$(dirname "$(readlink -f "$0")")" && cd "${WORK_DIR}" || exit 99
script_name="$(basename "$0" 2>/dev/null)"
declare -A RAID_INFO

if ! "${TSC_FUNC:-false}"; then
    source ${WORK_DIR}/../../func
fi

get_cpu_info() {
    local cpu_model cpu_cnt cpu_arch
    cpu_model="$(awk -F : '/model name/{print $2}' /proc/cpuinfo | sort -u | sed 's/^\s*//')"
    cpu_cnt="$(lscpu | awk '/^Socket\(s\):/{print $2}')"
    jq -rcn --arg model "$cpu_model" --argjson cnt "$cpu_cnt" \
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
        jq -rcs '{memory: .}'
}

get_serial_number() {
    # 优先级：命令行 --sn > 原日志 sn > dmidecode 自动获取
    local sn_file="${original_logfile}"
    local invalid_sns=('1234567890' '01234567890' '0000000000' 'To be filled by O.E.M.' '')
    local serial=""
    # 1) 命令行 --sn 优先（全局变量 sn 由参数解析设置）
    if [[ -n "${sn:-}" ]]; then
        serial="${sn}"
    else
        # 2) 若 original_logfile 存在且有 sn，则使用之
        if [[ -f "${sn_file}" ]]; then
            serial="$(jq -r .sn "${sn_file}" 2>/dev/null || echo "")"
        fi
        # 3) 若仍为空或无效，则用 dmidecode 等方式探测
        if [[ -z "${serial}" ]]; then
            serial="$(dmidecode -s system-serial-number 2>/dev/null | grep -v '#' | head -n1 || echo "")"
            for invalid_sn in "${invalid_sns[@]}"; do
                if [[ "${serial}" == "${invalid_sn}" ]]; then
                    serial="$(dmidecode -s baseboard-serial-number 2>/dev/null | head -n1 || echo "")"
                    break
                fi
            done
            for invalid_sn in "${invalid_sns[@]}"; do
                if [[ "${serial}" == "${invalid_sn}" ]]; then
                    serial="None"
                    break
                fi
            done
        fi
    fi
    if [[ -z "${serial}" ]]; then
        serial="None"
    fi

    jq -rcn --arg sn "${serial}" '{sn: $sn}'
}

# 从 original_logfile 继承 contract_no（如果本次未提供则继承）
get_contract_no() {
    local val=""
    if [[ -n "${contract_no:-}" ]]; then
        val="${contract_no}"
    elif [[ -f "${original_logfile}" ]]; then
        val="$(jq -r '.contract_no // ""' "${original_logfile}" 2>/dev/null || echo "")"
    fi
    jq -rcn --arg contract_no "${val}" '{contract_no: $contract_no}'
}

# 从 original_logfile 继承 location（如果本次未提供则继承）
get_location() {
    local val=""
    if [[ -n "${location:-}" ]]; then
        val="${location}"
    elif [[ -f "${original_logfile}" ]]; then
        val="$(jq -r '.location // ""' "${original_logfile}" 2>/dev/null || echo "")"
    fi
    jq -rcn --arg location "${val}" '{location: $location}'
}

get_raid_type() {
    RAID_INFO[type]="none"
    RAID_INFO[bin]=""
    local lspci_info lsmod_info
    lspci_info="$(lspci)"
    lsmod_info="$(lsmod)"
    if echo "${lspci_info}" | grep -qiP "Adaptec"; then
        RAID_INFO[type]="adaptec"
        if [[ -f /bin/arcconf ]]; then
            RAID_INFO[bin]="/bin/arcconf"
        elif [[ -f /sbin/arcconf ]]; then
            RAID_INFO[bin]="/sbin/arcconf"
        elif [[ -f "${WORK_DIR}/../packages/arcconf/arcconf-$(arch)" ]]; then
            RAID_INFO[bin]="${WORK_DIR}/../packages/arcconf/arcconf-$(arch)"
        else
            RAID_INFO[bin]="$(command -v arcconf 2>/dev/null || echo false)"
        fi
    elif echo "${lsmod_info}" | grep -qE "^mpt3sas" || echo "${lspci_info}" | grep -q "SAS3008"; then
        RAID_INFO[type]="mpt3sas"
        if [[ -f /bin/sas3ircu ]]; then
            RAID_INFO[bin]="/bin/sas3ircu"
        elif [[ -f /sbin/sas3ircu ]]; then
            RAID_INFO[bin]="/sbin/sas3ircu"
        elif [[ -f "${WORK_DIR}/../packages/sas3ircu/sas3ircu-$(arch)" ]]; then
            RAID_INFO[bin]="${WORK_DIR}/../packages/sas3ircu/sas3ircu-$(arch)"
        else
            RAID_INFO[bin]="$(command -v sas3ircu 2>/dev/null || echo false)"
        fi
    elif echo "${lsmod_info}" | grep -qE "^mpt2sas" ||
        echo "${lspci_info}" | grep -q "LSI2308"; then
        RAID_INFO[type]="mpt2sas"
        if [[ -f /bin/sas2ircu ]]; then
            RAID_INFO[bin]="/bin/sas2ircu"
        elif [[ -f /sbin/sas2ircu ]]; then
            RAID_INFO[bin]="/sbin/sas2ircu"
        elif [[ -f "${WORK_DIR}/../packages/sas2ircu/sas2ircu-$(arch)" ]]; then
            RAID_INFO[bin]="${WORK_DIR}/../packages/sas2ircu/sas2ircu-$(arch)"
        else
            RAID_INFO[bin]="$(command -v sas2ircu 2>/dev/null || echo false)"
        fi
    elif echo "${lspci_info}" |
        grep -qiP "LSI|AVAGO|MegaRAID|(RAID bus controller: Intel Corporation Lewisburg)"; then
        RAID_INFO[type]="lsi"
        if [[ -f /bin/storcli ]]; then
            RAID_INFO[bin]="/bin/storcli"
        elif [[ -f /opt/MegaRAID/storcli/storcli64 ]]; then
            RAID_INFO[bin]="/opt/MegaRAID/storcli/storcli64"
        elif [[ -f "${WORK_DIR}/../packages/storcli64/storcli64-noarch" ]]; then
            RAID_INFO[bin]="${WORK_DIR}/../packages/storcli64/storcli64-noarch"
        elif command -v storcli64 &>/dev/null; then
            RAID_INFO[bin]="$(command -v storcli64 2>/dev/null)"
        else
            RAID_INFO[bin]="$(command -v storcli 2>/dev/null || echo false)"
        fi
    fi
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
        get_raid_type
        if [[ "${RAID_INFO[type]}" == "adaptec" && -n "${RAID_INFO[bin]}" ]]; then
            # Adaptec
            mapfile -t raid_detail < <(
                "${RAID_INFO[bin]}" GETCONFIG 1 PD |
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
                                printf "{\"type\":\"raid\",\"model\":\"%s\",\"serial\":\"%s\",\"wwn\":\"%s\",\"size\":\"%.2f\",\"unit\":\"T\"}\n", \
                                    r[a]["model"], r[a]["serial"],r[a]["wwn"],r[a]["size"]
                                }
                            }
                        }
                    '
            )
            if [[ "${#raid_detail[@]}" -gt 0 ]]; then
                disk_detail+=("${raid_detail[@]}")
            fi
        elif [[ "${RAID_INFO[type]}" == "lsi" && -n "${RAID_INFO[bin]}" ]]; then
            # LSI|AVAGO|MegaRAID
            ctl_no=$(
                "${RAID_INFO[bin]}" show |
                    grep -PA2 "Ctl\s+Model" |
                    tail -n1 | awk '{print $1}'
            )
            mapfile -t raid_detail < <(
                "${RAID_INFO[bin]}" /c"${ctl_no}" show |
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
    # 逐行看块设备是否是直通盘
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
        # 判断是不是主板直通盘, 条件慢慢补充
        # 虚拟磁盘 Virtual disk|VMware -> 视为直通盘
        # VENDOR 不含 raid卡关键字 LSI|DELL|HP|AVAGO 且
        # MODEL 不含逻辑卷关键字 LOGICAL 且
        # readlink -f /sys/block/块设备名 看 / 分割的第5位和第6位, 这里是块设备的总线的路径。lspci看不含Raid卡关键字
        if (
            { echo "${lsblk_line}" | grep -qiP "Virtual disk|VMware"; } ||
                (
                    { ! echo "${vendor}" | grep -qP "LSI|DELL|HP|AVAGO"; } &&
                        { ! echo "${model}" | grep -q 'LOGICAL'; } &&
                        { # 查找块设备的总线路径, 看其上级设备名字有没有带 raid 这个关键字的
                            ! lspci |
                                grep -E "$(
                                    readlink -f "/sys/block/${name}" |
                                        awk -F / '{print $5"|"$6}' |
                                        sed 's/\b0000://g'
                                )" |
                                grep -qiE "raid|Adaptec|Avago|LSI|MegaRAID|RAID bus controller"
                        }
                )
        ); then
            da_disks+=("${name}")
            da_disk_detail="$(
                jq -n \
                    --arg serial "${serial}" \
                    --arg model "${model}" \
                    --argjson size "${size}" \
                    --arg type "direct" \
                    '{serial: $serial, model: $model, "size": $size, type: $type, unit: "T"}'
            )"
            disk_detail+=("${da_disk_detail}")
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

get_mountpoint_runtime_info() {
    local json_array="[]"
    local mount_info_tmp
    local -A mount_info
    local -a FILESYSTEMS=(ext2 ext3 ext4 btrfs xfs vfat ntfs jfs reiserfs zfs)
    local FS_TYPES
    FS_TYPES="$(
        IFS=,
        echo "${FILESYSTEMS[*]}"
    )"

    mapfile -t mount_info < <(
        findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS -l -U -D -t "${FS_TYPES}"
    )

    unset line
    local line
    for line in "${mount_info[@]}"; do
        local mount_point fstype options source_device
        mount_point="$(echo "$line" | awk '{print $1}')"
        source_device="$(echo "$line" | awk '{print $2}')"
        fstype="$(echo "$line" | awk '{print $3}')"
        options="$(echo "$line" | awk '{print $4}')"
        [[ ! -d "${mount_point}" ]] && continue
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

    local mem_used_percent=0
    if ((mem_total_bytes > 0)); then
        mem_used_percent="$(awk "BEGIN {printf \"%.2f\", ($mem_used_bytes / $mem_total_bytes) * 100}")"
    fi

    local swap_used_percent=0
    if ((swap_total_bytes > 0)); then
        swap_used_percent="$(awk "BEGIN {printf \"%.2f\", ($swap_used_bytes / $swap_total_bytes) * 100}")"
    fi

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
    local mountpoint_json memory_json cpu_json raid_type
    system_info="$(detect_system_info)"
    machine_type="$(echo $system_info | jq -r .machine_type)"
    mountpoint_json="$(get_mountpoint_runtime_info)"
    memory_json="$(get_memory_runtime_info)"
    cpu_json="$(get_cpu_runtime_info)"
    if [[ -z "$mountpoint_json" ]]; then
        mountpoint_json="[]"
    fi
    local warnings='{}' cpu_used_percent memory_used_percent storage_warnings_list mount_points storage_unwritable_list unwritable_mount_points inode_mount_points

    cpu_used_percent="$(echo "$cpu_json" | jq -r '.used_percent')"
    memory_used_percent="$(echo "$memory_json" | jq -r '.ram.used_percent')"

    if awk -v t="${cpu_threshold}" "BEGIN {exit !($cpu_used_percent > t)}"; then
        warnings="$(
            echo "$warnings" |
                jq --arg threshold "${cpu_threshold}" \
                    '."cpu_usage" = "CPU usage is above threshold: \($threshold)%."'
        )"
    fi

    if awk -v t="${memory_threshold}" "BEGIN {exit !($memory_used_percent > t)}"; then
        warnings="$(
            echo "$warnings" |
                jq --arg threshold "${memory_threshold}" \
                    '."memory_usage" = "Memory usage is above threshold: \($threshold)%."'
        )"
    fi

    storage_warnings_list="$(
        echo "${mountpoint_json}" |
            jq --argjson threshold "${storage_threshold}" \
                '[.[] | select(.size.used_percent > $threshold) | .target]'
    )"

    local inode_warnings_list
    inode_warnings_list="$(
        echo "${mountpoint_json}" |
            jq --argjson threshold "${storage_threshold}" \
                '[.[] | select(.inodes.used_percent > $threshold) | .target]'
    )"

    if [[ "${storage_warnings_list}" != "[]" ]]; then
        mount_points="$(echo "$storage_warnings_list" | jq -r 'join(", ")')"
        warnings="$(
            echo "$warnings" |
                jq --arg mount_points "$mount_points" \
                    --arg threshold "${storage_threshold}" \
                    '."storage_usage" = "Storage size usage for \($mount_points) is above threshold: \($threshold)%."'
        )"
    fi

    if [[ "${inode_warnings_list}" != "[]" ]]; then
        inode_mount_points="$(echo "$inode_warnings_list" | jq -r 'join(", ")')"
        warnings="$(
            echo "$warnings" |
                jq --arg inode_mount_points "$inode_mount_points" \
                    --arg threshold "${storage_threshold}" \
                    '."inode_usage" = "Inode usage for \($inode_mount_points) is above threshold: \($threshold)%."'
        )"
    fi

    storage_unwritable_list="$(
        echo "${mountpoint_json}" |
            jq '[.[] | select(.writable == false) | .target]'
    )"

    if [[ "${storage_unwritable_list}" != "[]" ]]; then
        unwritable_mount_points="$(echo "$storage_unwritable_list" | jq -r 'join(", ")')"
        warnings="$(
            echo "$warnings" |
                jq --arg unwritable_mount_points "$unwritable_mount_points" \
                    '."storage_unwritable" = "The following mount points are not writable: \($unwritable_mount_points)."'
        )"
    fi
    if [[ "${machine_type}" == "pm" ]]; then
        get_raid_type
        local raid_status="{}"
        if [[ "${RAID_INFO[type]}" != "none" && -n "${RAID_INFO[bin]}" ]]; then
            raid_status="$(
                bash "${WORK_DIR}/tsc_raid_health_check.sh" \
                    "${RAID_INFO[type]}" "${RAID_INFO[bin]}" "${original_logfile}"
            )"
        fi
        # 在这里给warnings 添加raid 的pd, vd 告警,以及磁盘数量比对告警
        jq -n --argjson mountpoint_status "${mountpoint_json}" \
            --argjson memory_data "${memory_json}" \
            --argjson cpu_data "$cpu_json" \
            --argjson warnings_data "$warnings" \
            --argjson raid_status "$raid_status" \
            '{
                storage: 
                {
                    mountpoint: $mountpoint_status,
                    raid: $raid_status
                },
                memory: $memory_data,
                cpu: $cpu_data,
                warning: ($warnings_data + {raid_status: $raid_health} + ( $raid_health.raid_count_mismatch? // {} ) )
            }'
    else
        jq -n --argjson mountpoint_status "${mountpoint_json}" \
            --argjson memory_data "${memory_json}" \
            --argjson cpu_data "$cpu_json" \
            --argjson warnings_data "$warnings" \
            '{
                storage:
                {
                    mountpoint: $mountpoint_status,
                },
                memory: $memory_data,
                cpu: $cpu_data,
                warning: $warnings_data
            }'
    fi
}

main() {
    local system_info manufacturer sn cpu_info mem_info disk_info machine_type
    system_info="$(detect_system_info)"
    machine_type="$(echo $system_info | jq -r .machine_type)"
    sn_json="$(get_serial_number | jq -c . 2>/dev/null || echo '{}')"
    contract_no_json="$(get_contract_no | jq -c . 2>/dev/null || echo '{}')"
    location_json="$(get_location | jq -c . 2>/dev/null || echo '{}')"
    manufacturer="$(dmidecode -s system-manufacturer | grep -vP "^\s*$|^\s*#")"
    cpu_info="$(get_cpu_info | jq -c . 2>/dev/null || echo '{}')"
    mem_info="$(get_mem_info | jq -c . 2>/dev/null || echo '{}')"
    disk_info="$(get_disk_info "${machine_type}" | jq -c . 2>/dev/null || echo '{}')"
    echo "${system_info}" |
        jq --argjson sn "${sn_json}" '. + $sn' |
        jq --arg manufacturer "${manufacturer}" '. + {manufacturer: $manufacturer}' |
        jq --argjson cpu_info "${cpu_info}" '. + $cpu_info' |
        jq --argjson mem_info "${mem_info}" '. + $mem_info' |
        jq --argjson disk_info "${disk_info}" '. + $disk_info' |
        jq --argjson contract_no "${contract_no_json}" '. + $contract_no' |
        jq --argjson location "${location_json}" '. + $location'
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --contract_no <contract_no>   Specify the contract number (optional, requires a parameter)
  --location <location>         Specify the location (optional, requires a parameter)
  --runtime                     Gather runtime information (optional, no parameter)
  --cpu_threshold <value>       Set CPU usage threshold (used with --runtime, requires a parameter, default: 90)
  --storage_threshold <value>   Set storage usage threshold (used with --runtime, requires a parameter, default: 90)
  --memory_threshold <value>    Set memory usage threshold (used with --runtime, requires a parameter, default: 90)
  --help                        Show this help message and exit
EOF
}

OPTIONS=$(
    getopt \
        --options="" \
        --longoptions=contract_no:,location:,sn:,help,runtime,cpu_threshold:,storage_threshold:,memory_threshold: \
        --name "$0" \
        -- "$@"
) || {
    usage
    exit 1
}
eval set -- "$OPTIONS"

contract_no=""
location=""
sn=""

while true; do
    case "$1" in
    --runtime)
        runtime_flag=true
        cpu_threshold="${cpu_threshold:-90}"
        memory_threshold="${memory_threshold:-90}"
        storage_threshold="${storage_threshold:-90}"
        shift
        ;;
    --cpu_threshold)
        cpu_threshold="$2"
        shift 2
        ;;
    --storage_threshold)
        storage_threshold="$2"
        shift 2
        ;;
    --memory_threshold)
        memory_threshold="$2"
        shift 2
        ;;
    --sn)
        sn="$2"
        shift 2
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

if ${runtime_flag:-false}; then
    runtime
    exit $?
fi

# result="$(
#     main |
#         jq -r --arg contract_no "${contract_no}" --arg location "${location}" '
#   . + (if $contract_no != "" then {contract_no: $contract_no} else {} end)
#     + (if $location != "" then {location: $location} else {} end)
# '
# )"

# 读取原始日志（若存在）
# if [[ -s "${original_logfile}" ]]; then
#     original_info="$(jq -rc . <"${original_logfile}")"
# else
#     original_info='{}'
# fi

# 生成时间戳文件名
timestamp="$(date +%Y%m%d%H%M%S)"
new_file="/var/log/tsc/tsc_iaas_info-${timestamp}.json"

main | jq -S . | tee "${new_file}"

# 计算标准化后 md5
md5_new="$(jq -Src . "${new_file}" | md5sum | awk '{print $1}')"
# 直接解析 original_logfile 的实际目标并用该目标计算 md5（若目标存在）
orig_target="$(readlink -f "${original_logfile}" 2>/dev/null || true)"
md5_orig=""
if [[ -n "${orig_target}" && -f "${orig_target}" ]]; then
    md5_orig="$(jq -Src . "${orig_target}" | md5sum | awk '{print $1}')"
elif [[ -f "${original_logfile}" ]]; then
    md5_orig="$(jq -Src . "${original_logfile}" | md5sum | awk '{print $1}')"
fi

# 若相同：删除原软链指向的目标文件（若存在）并把软链指向新文件
# 若不同：保留原目标文件，但仍把软链指向新文件
if [[ -n "${md5_new}" && "${md5_new}" == "${md5_orig}" ]]; then
    if [[ -n "${orig_target}" && -f "${orig_target}" ]]; then
        rm -f "${orig_target}" || true
    fi
    ln -sf "${new_file}" "${original_logfile}"
else
    ln -sf "${new_file}" "${original_logfile}"
fi

# final_result=$(
#     jq --argjson new "${result}" \
#         --argjson original "${original_info}" '
#     $new * $original
# ' <<<'{}'
# )

# echo "${final_result}" | tee "${original_logfile}"
