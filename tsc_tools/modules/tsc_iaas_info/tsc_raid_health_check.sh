#!/usr/bin/env bash
# RAID健康检查独立脚本，输出JSON格式

# 故障关键字, 按严重级别从高到低写, 确保匹配顺序
LD_KEYWORDS=(
    "Offline|严重(离线)"
    "OfLn|严重(离线)"
    "Impacted|告警(条带化错误)"
    "Rebuild|告警(正在重建)"
    "Degraded|告警(被降级)"
    "Pdgd|告警(部分降级)"
    "Dgrd|告警(被降级)"
    "Optimal|信息(正常)"
    "OK|信息(正常)"
    "Optl|信息(正常)"
    "Online|信息(在线)"
)
PD_KEYWORDS=(
    "Offln|严重(离线)"
    "Failed|严重(损坏)"
    "Offline|严重(离线)"
    "Unconfigured(bad)|告警(已坏未使用)"
    "Rebuild|告警(正在重建)"
    "Foreign|告警(含阵列配置的待用盘)"
    "Rbld|告警(正在重建)"
    "UBad|告警(已坏未使用)"
    "DHS|信息(热备盘)"
    "Unconfigured(good)|信息(未格式化待用)"
    "Sntze|信息(清洁状态)"
    "Onln|信息(在线)"
    "UGood|信息(未格式化待用)"
    "GHS|信息(全局热备盘)"
    "JBOD|信息(正常)"
    "OK|信息(正常)"
    "Optimal|信息(正常)"
    "Hotspare,Spundown|信息(热备盘)"
    "Online|信息(在线)"
    "Online,SpunUp|信息(在线)"
    "Ready|信息(已格式化待用)"
    "Hot Spare|信息(热备盘)"
    "Raw|信息(直通盘)"
)
# 最终结果 [{vd_info_obj},{vd_info_obj},{pd_info_obj},{pd_info_obj}]
raid_status_json="[]"

declare -A RAID_INFO

associate_array_to_json() {
    declare -n assoc=$1
    local sep=$'\u0019'
    for k in "${!assoc[@]}"; do
        printf '%s%s%s%s' "$k" "$sep" "${assoc[$k]}" "$sep"
    done |
        jq -Rrcs --arg sep "$sep" '
    (split($sep)[:-1]) as $a |
    [range(0; ($a|length); 2) | { ($a[.]) : $a[. + 1] }] |
    add
  '
}

array_to_json() {
    local sep=$'\u0019'
    declare -n arr=$1

    {
        for v in "${arr[@]}"; do
            printf '%s%s' "$v" "$sep"
        done
    } |
        jq -Rrcs --arg sep "$sep" '
    (split($sep)[:-1]) as $a
    | $a
  '
}

get_raid_type() {
    RAID_INFO[type]="none"
    RAID_INFO[bin]=""
    if lspci | grep -qiP "Adaptec"; then
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
    elif lsmod | grep -qE "^mpt3sas" || lspci | grep -q "SAS3008"; then
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
    elif lsmod | grep -qE "^mpt2sas" || lspci | grep -q "LSI2308"; then
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
    elif lspci |
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

check_lsi() {
    # 获取 ctl 数量
    local RAID_BIN=$1
    local ctl_cnt ctl_no vd_cnt
    ctl_cnt="$("${RAID_BIN}" show | awk '/Number of Controllers/{print $NF}')"
    # 遍历 ctl
    for ((ctl_no = 0; ctl_no < "${ctl_cnt}"; ctl_no++)); do
        storcli_out="$("${RAID_BIN}" /c"${ctl_no}" show 2>/dev/null)"
        # 获取 vd 数量, 遍历各 vd 状态
        # {"阵列卡号":"0", "虚拟磁盘号": "2", "虚拟磁盘状态":"OfLn","虚拟磁盘中文状态":"严重(离线)"}
        vd_cnt="$(echo "${storcli_out}" | awk '/Virtual Drives/{print $NF}')"
        local vd_no vd_stat vd_keyword vd_stat_cn line
        unset vd_info
        local -A vd_info
        # 摘出 vd list 这一段, 逐行对比 vd 状态, 并追加到总结果 raid_status_json
        while read -r line; do
            vd_no="$(echo "${line}" | awk -F / '{print $1}')"
            vd_stat="$(echo "${line}" | awk '{print $3}')"
            for vd_keyword in "${LD_KEYWORDS[@]}"; do
                if echo "${vd_stat}" | grep -iq "${vd_keyword%%|*}"; then
                    vd_stat_cn="${vd_keyword##*|}"
                    break
                fi
            done
            vd_info=(
                [阵列卡号]="${ctl_no}"
                [虚拟磁盘号]="${vd_no}"
                [虚拟磁盘状态]="${vd_stat}"g+
                [虚拟磁盘中文状态]="${vd_stat_cn}"
            )
            # 将 vd_info append 到 raid_status_json 中
            jq -c --argjson new "$(associate_array_to_json vd_info)" '. + [$new]' <<<"$raid_status_json"
        done < <(echo "${storcli_out}" | grep -A "$((vd_cnt + 5))" "VD LIST" | tail -n "${vd_cnt}")

        # 获取 pd 数量, 遍历各 pd 状态, 对比状态表, 将结果追加到总结果 raid_status_json
        local pd_cnt pd_no pd_stat pd_keyword pd_stat_cn
        pd_cnt="$(echo "${storcli_out}" | awk '/Physical Drives/{print $NF}')"
        unset pd_info
        local -A pd_info line
        # 摘出 vd list 这一段, 逐行对比 vd 状态, 并追加到总结果 raid_status_json
        while read -r line; do
            pd_no="$(echo "${line}" | awk -F / '{print $1}')"
            pd_stat="$(echo "${line}" | awk '{print $3}')"
            for pd_keyword in "${PD_KEYWORDS[@]}"; do
                if echo "${pd_stat}" | grep -iq "${pd_keyword%%|*}"; then
                    pd_stat_cn="${pd_keyword##*|}"
                    break
                fi
            done
            pd_info=(
                [阵列卡号]="${ctl_no}"
                [物理磁盘号]="${pd_no}"
                [物理磁盘状态]="${pd_stat}"
                [物理磁盘中文状态]="${pd_stat_cn}"
            )
            # 将 pd_info append 到 raid_status_json 中
            jq -c --argjson new "$(associate_array_to_json pd_info)" '. + [$new]' <<<"$raid_status_json"
        done < <(echo "${storcli_out}" | grep -A "$((pd_cnt + 5))" "PD LIST" | tail -n "${pd_cnt}")
    done
}
#     #新增sas3ircu依赖内核判断
#     sas3mod=$(lsmod | grep ^mpt3sas | awk '{print 3}')
#     if [ ! -n "$sas3mod" ]; then
#         sas3mod=0
#     fi
#     #新增sas2ircu依赖内核判断
#     sas2mod=$(lsmod | grep ^mpt2sas | awk '{print 3}')
#     if [ ! -n "$sas2mod" ]; then
#         sas2mod=0
#     fi
#     if [ "$sas3mod" -ge "1" ]; then
#         command="sas3ircu"
#     elif [ "$sas2mod" -ge "1" ]; then
#         command="sas2ircu"
#     fi
#     if [ "$sas3mod" -ge "1" ] || [ "$sas2mod" -ge "1" ]; then
#         array=($(/etc/zabbix/script/$command list | grep SAS | grep -vE "SAS3IRCU|SAS2IRCU|Avago" | awk '{print $1}'))
#         array_num=${#array[@]}
#         for ((i = 0; i < $array_num; i++)); do
#             /etc/zabbix/script/$command $i display | awk '/IR Volume information/,/Physical device information/{print}' | grep -E "IR volume|Status of volume" | sed 'N;s/\n/;/g' | sed 's/ //g' | sed 's/^/Raid卡'${array[i]}'&;/g' >>/tmp/lsi_array_info.txt 2>/dev/null
#             /etc/zabbix/script/$command $i display | awk '/Physical device information/,/Enclosure information/{print}' | grep -A 13 "Device is a Hard disk" | grep -E "Slot|State" | sed 'N;s/\n/;/g' | sed 's/ //g' | sed 's/^/Raid卡'${array[i]}'&;/g' >>/tmp/lsi_array_info.txt 2>/dev/null
#         done
#         #判断VD是否健康
#         vd=($(cat /tmp/lsi_array_info.txt 2>/dev/null | grep "IRvolume"))
#         vd_num=${#vd[@]}
#         for ((i = 0; i < $vd_num; i++)); do
#             vd_health=$(echo ${vd[i]} | awk -F ":" '{print $NF}')
#             for ((j = 0; j < $ld_warns_num; j++)); do
#                 ld_warn_status=$(echo ${ld_warns[j]} | awk -F "|" '{print $1}')
#                 ld_warn_level=$(echo ${ld_warns[j]} | awk -F "|" '{print $2}')
#                 shopt -s nocasematch
#                 if [[ "$vd_health" =~ "$ld_warn_status" ]]; then
#                     realnum=$(echo ${vd[i]} | awk -F ";" '{print $2}')
#                     sed -i "/$realnum;/s/^/$ld_warn_level:  /" /tmp/lsi_array_info.txt 2>/dev/null
#                 fi
#             done
#         done

#         #判断PD是否健康
#         pd=($(cat /tmp/lsi_array_info.txt 2>/dev/null | grep "Slot"))
#         pd_num=${#pd[@]}
#         #echo $pd_num
#         for ((i = 0; i < $pd_num; i++)); do
#             pd_health=$(echo ${pd[i]} | awk -F ":" '{print $NF}')
#             for ((j = 0; j < $pd_warns_num; j++)); do
#                 pd_warn_status=$(echo ${pd_warns[j]} | awk -F "|" '{print $1}')
#                 pd_warn_level=$(echo ${pd_warns[j]} | awk -F "|" '{print $2}')
#                 shopt -s nocasematch
#                 if [[ "$pd_health" =~ "$pd_warn_status" ]]; then
#                     realslot=$(echo ${pd[i]} | awk -F ";" '{print $2}' | awk -F ":" '{print $2}')
#                     sed -i "/Slot#:$realslot;/s/^/$pd_warn_level:  /" /tmp/lsi_array_info.txt 2>/dev/null
#                 fi
#             done
#         done
#     fi

#     sed -i "/^[a-zA-Z]/s/^/未知状态:  /" /tmp/lsi_array_info.txt 2>/dev/null
#     whole_health=$(cat /tmp/lsi_array_info.txt 2>/dev/null | grep -Ec "严重|告警|未知状态")
#     if [ $whole_health = 0 ]; then
#         echo "信息:  Raid卡状态正常" >/tmp/lsi_array_info.txt 2>/dev/null
#     fi
#     sed -i 's/VirtualDrive/虚拟磁盘/g;s/PredictiveFailureCount/磁盘错误计数/g;s/State/磁盘状态/g;s/SlotNumber/槽位/g;s/Firmwarestate/磁盘状态/g;s/Slot#/槽位/g;s/IRvolume/虚拟磁盘/g;s/Statusofvolume/磁盘状态/g' /tmp/lsi_array_info.txt 2>/dev/null

# }

if [[ "$RAID_TYPE" == "adaptec" && -n "$RAID_BIN" ]]; then
    arcconf_out="$($RAID_BIN GETCONFIG 1 PD 2>/dev/null)"
    raid_status_arr=($(echo "$arcconf_out" | grep -E "$fault_pattern" | awk '{print $NF}' | sort | uniq))
    raid_pd_count=$(echo "$arcconf_out" | grep -c "Device #")
elif [[ "$RAID_TYPE" == "lsi" && -n "$RAID_BIN" ]]; then
    ctl_no="$($RAID_BIN show | grep -PA2 "Ctl\s*Model" | tail -n1 | awk '{print $1}')"
    storcli_out="$($RAID_BIN /c"${ctl_no}" show 2>/dev/null)"
    raid_status_arr=($(echo "$storcli_out" | grep -E "$fault_pattern" | awk '{print $NF}' | sort | uniq))
    raid_pd_count=$(echo "$storcli_out" | grep -c "EID=")
fi
json_raid_count=0
if [[ -f "$ORIGINAL_LOGFILE" ]]; then
    json_raid_count=$(jq '[.storage[] | select(.type=="raid")1] | length' "$ORIGINAL_LOGFILE" 2>/dev/null)
fi
if [[ "$json_raid_count" != "$raid_pd_count" ]]; then
    json_count_mismatch="RAID disk count mismatch: json=$json_raid_count, detected=$raid_pd_count"
fi
jq -n --argjson arr "$(printf '%s\n' "${raid_status_arr[@]}" | jq -R . | jq -s .)" \
    --arg mismatch "$json_count_mismatch" \
    '{raid_status: $arr, raid_count_mismatch: ($mismatch == "null" ? null : $mismatch)}'
