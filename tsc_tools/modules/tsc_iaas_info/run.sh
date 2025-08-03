#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034,SC2046,SC2086,SC2116,SC2154
set -o errexit    # Exit immediately if a command exits with a non-zero status (same as set -e)
set -o nounset    # Treat unset variables and parameters as an error (same as set -u)
set -o pipefail   # If any command in a pipeline fails, the pipeline returns an error code
set +o posix      # Disable POSIX mode to allow Bash-specific features
shopt -s nullglob # When no files match a glob pattern, expand to nothing instead of the pattern itself

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
            mapfile -t raid_detail < <(
                /home/tsc/tsc_tools/bin/arcconf-"$(arch)" GETCONFIG 1 PD |
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
            ctl_no=$(
                /home/tsc/tsc_tools/bin/storcli-"$(arch)" show |
                    grep -PA2 "Ctl\s+Model" |
                    tail -n1 | awk '{print $1}'
            )
            mapfile -t raid_detail < <(
                /home/tsc/tsc_tools/bin/storcli-"$(arch)" /c"${ctl_no}" show |
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

main() {
    local system_info manufacturer sn cpu_info mem_info disk_info machine_type
    system_info="$(detect_system_info)"
    machine_type="$(echo $system_info | jq -r .machine_type)"
    sn="$(get_serial_number)"
    manufacturer="$(dmidecode -s system-manufacturer | grep -vP "^\s*$|^\s*#")"
    cpu_info="$(get_cpu_info)"
    mem_info="$(get_mem_info)"
    disk_info="$(get_disk_info "${machine_type}")"
    # echo "$disk_info"
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
  --help                       Show this help message and exit
EOF
}

OPTIONS=$(getopt --options="" --longoptions=contract_no:,location:,help --name "$0" -- "$@") || {
    usage
    exit 1
}
eval set -- "$OPTIONS"

contract_no=""
location=""

while true; do
    case "$1" in
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
