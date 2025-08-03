#!/bin/bash
#date :20180420
#update:20180724
#将告警级别调整为信息，告警和严重
#20180806,解决lsi卡盘符不连续，并且出现坏盘时，告警和盘符不对应的情况
#20190101,sas3008卡不支持megacli，改用sas3ircu
#20230414,移除megacli,lsi系列卡采用storcli命令获取信息
set +o posix
ld_warns=("Optimal|信息(正常)" "OK|信息(正常)" "Impacted|告警(条带化错误)" "Rebuild|告警(正在重建)" "Degraded|告警(被降级)" "Offline|严重(离线)" "Online|信息(在线)" "OfLn|严重(离线)" "Pdgd|告警(部分降级)" "Dgrd|告警(被降级)" "Optl|信息(正常)")
ld_warns_num=${#ld_warns[@]}
#LD状态
#正常：Optimal 正常
#告警：Impacted 条带化错误，Rebuild 重建，Degraded 降级
#严重：Offline 离线

pd_warns=("Unconfigured(good)|信息(未格式化待用)" "OK|信息(正常)" "Optimal|信息(正常)" "Online,SpunUp|信息(在线)" "Ready|信息(已格式化待用)" "Hot Spare|信息(热备盘)" "Raw|信息(直通盘)" "Unconfigured(bad)|告警(已坏未使用)" "Rebuild|告警(正在重建)" "Foreign|告警(含阵列配置的待用盘)" "Failed|严重(损坏)" "Offline|严重(离线)" "Hotspare,Spundown|信息(热备盘)" "Online|信息(在线)" "DHS|信息(热备盘)" "UGood|信息(未格式化待用)" "GHS|信息(全局热备盘)" "UBad|告警(已坏未使用)" "Sntze|信息(清洁状态)" "Onln|信息(在线)" "Offln|严重(离线)")
pd_warns_num=${#pd_warns[@]}
#echo $pd_warns_num
#PD状态
#正常：Unconfigured(good) 未使用（正常），Ready 正常，Hot Spare 热备，Raw 不通raid卡管理的直通盘
#告警：Unconfigured(bad) 未使用（坏），Rebuild 重建，Foreign 外部的
#严重：Failed 损坏，Offline 离线

CheckArcconf() {
    /usr/Arcconf/arcconf GETCONFIG 1 LD | grep -E "Logical Device number|Status of Logical Device" | sed 'N;s/\n/;/g' | sed 's/number/number:/g' | sed 's/ //g' >/tmp/arcconf_array_info.txt 2>/dev/null
    /usr/Arcconf/arcconf GETCONFIG 1 PD | grep -Ew "Device |State" | grep -v "Power State" | sed 's/ //g' | sed 'N;s/\n/;/g' | grep State >>/tmp/arcconf_array_info.txt 2>/dev/null
    #判断LD是否健康
    mapfile -t ld < <(grep "LogicalDevicenumber" /tmp/arcconf_array_info.txt)
    ld_num=${#ld[@]}
    for ((i = 0; i < ld_num; i++)); do
        ld_health=$(echo "${ld[i]}" | awk -F ":" '{print $NF}')
        for ((j = 0; j < "${ld_warns_num}"; j++)); do
            ld_warn_status=$(echo "${ld_warns[j]}" | awk -F "|" '{print $1}')
            ld_warn_level=$(echo "${ld_warns[j]}" | awk -F "|" '{print $2}')
            shopt -s nocasematch
            if [[ "$ld_health" =~ "${ld_warn_status}" ]]; then
                sed -i "/LogicalDevicenumber:$i;/s/^/$ld_warn_level:  /" /tmp/arcconf_array_info.txt 2>/dev/null
            fi
        done
    done

    #判断PD是否健康
    pd=($(cat /tmp/arcconf_array_info.txt 2>/dev/null | grep "Device#"))
    pd_num=${#pd[@]}
    for ((i = 0; i < pd_num; i++)); do
        pd_health=$(echo "${pd[i]}" | awk -F ":" '{print $NF}')
        for ((j = 0; j < pd_warns_num; j++)); do
            pd_warn_status=$(echo "${pd_warns[j]}" | awk -F "|" '{print $1}')
            pd_warn_level=$(echo "${pd_warns[j]}" | awk -F "|" '{print $2}')
            shopt -s nocasematch
            if [[ "$pd_health" =~ "${pd_warn_status}" ]]; then
                realsolt=$(echo "${pd[i]}" |
                    awk -F ";" '{print $1}' | awk -F "#" '{print $2}')
                sed -i "/Device#$realsolt;/s/^/$pd_warn_level:  /" /tmp/arcconf_array_info.txt 2>/dev/null
            fi
        done
    done

    sed -i "/^[a-zA-Z]/s/^/未知状态:  /" /tmp/arcconf_array_info.txt 2>/dev/null

    whole_health=$(cat /tmp/arcconf_array_info.txt 2>/dev/null | grep -cE "告警|严重|未知状态")

    if [[ "${whole_health}" -eq 0 ]]; then
        : >/tmp/arcconf_array_info.txt 2>/dev/null
    fi
    sed -i 's/LogicalDevicenumber/虚拟磁盘/g;s/StatusofLogicalDevice/虚拟磁盘状态/g;s/Device#/槽位:/g;s/State/磁盘状态/g;s/Vendor/厂家/g;s/Serialnumber/序列号/g;s/TotalSize/磁盘容量/g' /tmp/arcconf_array_info.txt 2>/dev/null
}

CheckLsi() {
    : >/tmp/lsi_array_info.txt 2>/dev/null
    Nc=$(/opt/MegaRAID/storcli/storcli64 show nolog | grep "Number of Controllers" | awk '{print $NF}')

    for ((i = 0; i < Nc; i++)); do
        cn=$i
        /opt/MegaRAID/storcli/storcli64 /c"${cn}" show nolog >/tmp/lsi_array_info.tmp 2>/dev/null
        #频道VD是否健康
        vdnum=$(cat /tmp/lsi_array_info.tmp | grep "Virtual Drives" | awk '{print $NF}')
        gnum=$((vdnum + 5))
        cat /tmp/lsi_array_info.tmp | grep -A $gnum "VD LIST" |
            tail -n "$vdnum" |
            while read -r line; do
                vd=$(echo "$line" | awk -F/ '{print $1}')
                raidstatus=$(echo "$line" | awk '{print $3}')
                echo "raid卡$cn;虚拟磁盘:$vd;Raid状态:$raidstatus" >>/tmp/lsi_array_info.txt 2>/dev/null
                for ((j = 0; j < ld_warns_num; j++)); do
                    ld_warn_status=$(echo "${ld_warns[j]}" | awk -F "|" '{print $1}')
                    ld_warn_level=$(echo "${ld_warns[j]}" | awk -F "|" '{print $2}')
                    shopt -s nocasematch
                    if [[ "$raidstatus" =~ "$ld_warn_status" ]]; then
                        sed -i "/虚拟磁盘:$vd;Raid状态:$raidstatus/s/^/$ld_warn_level:  /" /tmp/lsi_array_info.txt 2>/dev/null
                    fi
                done
            done
        #判断PD是否健康
        pdnum=$(cat /tmp/lsi_array_info.tmp | grep "Physical Drives" | awk '{print $NF}')
        dnum=$(echo $pdnum+5 | bc)
        cat /tmp/lsi_array_info.tmp |
            grep -A "$dnum" "PD LIST" |
            tail -n "$pdnum" |
            while read -r line; do
                pd=$(echo "$line" | awk -F "[: ]" '{print $2}')
                pdstatus=$(echo "$line" | awk '{print $3}')
                echo "raid卡$cn;槽位:$pd;磁盘状态:$pdstatus" >>/tmp/lsi_array_info.txt 2>/dev/null
                for ((j = 0; j < pd_warns_num; j++)); do
                    pd_warn_status=$(echo "${pd_warns[j]}" | awk -F "|" '{print $1}')
                    pd_warn_level=$(echo "${pd_warns[j]}" | awk -F "|" '{print $2}')
                    shopt -s nocasematch
                    if [[ "$pdstatus" =~ "$pd_warn_status" ]]; then
                        sed -i "/槽位:$pd;磁盘状态:$pdstatus/s/^/$pd_warn_level:  /" /tmp/lsi_array_info.txt 2>/dev/null
                    fi
                done
            done

    done

    #新增sas3ircu依赖内核判断
    sas3mod=$(lsmod | grep ^mpt3sas | awk '{print 3}')
    if [[ -z "$sas3mod" ]]; then
        sas3mod=0
    fi
    #新增sas2ircu依赖内核判断
    sas2mod=$(lsmod | grep ^mpt2sas | awk '{print 3}')
    if [[ -z "$sas2mod" ]]; then
        sas2mod=0
    fi
    if [[ "$sas3mod" -ge "1" ]]; then
        command="sas3ircu"
    elif [[ "$sas2mod" -ge "1" ]]; then
        command="sas2ircu"
    fi
    if [[ "$sas3mod" -ge "1" ]] ||
        [[ "$sas2mod" -ge "1" ]]; then
        mapfile -t array < <(
            /etc/zabbix/script/$command list |
                grep SAS |
                grep -vE "SAS3IRCU|SAS2IRCU|Avago" |
                awk '{print $1}'
        )
        array_num=${#array[@]}
        for ((i = 0; i < array_num; i++)); do
            /etc/zabbix/script/$command "$i" display |
                awk '/IR Volume information/,/Physical device information/{print}' |
                grep -E "IR volume|Status of volume" |
                sed 'N;s/\n/;/g' |
                sed 's/ //g' |
                sed 's/^/Raid卡'${array[i]}'&;/g' >>/tmp/lsi_array_info.txt 2>/dev/null
            /etc/zabbix/script/$command "$i" display |
                awk '/Physical device information/,/Enclosure information/{print}' |
                grep -A 13 "Device is a Hard disk" |
                grep -E "Slot|State" |
                sed 'N;s/\n/;/g' |
                sed 's/ //g' |
                sed 's/^/Raid卡'${array[i]}'&;/g' >>/tmp/lsi_array_info.txt 2>/dev/null
        done
        #判断VD是否健康
        vd=($(cat /tmp/lsi_array_info.txt 2>/dev/null | grep "IRvolume"))
        vd_num=${#vd[@]}
        for ((i = 0; i < vd_num; i++)); do
            vd_health=$(echo ${vd[i]} | awk -F ":" '{print $NF}')
            for ((j = 0; j < ld_warns_num; j++)); do
                ld_warn_status=$(echo "${ld_warns[j]}" | awk -F "|" '{print $1}')
                ld_warn_level=$(echo "${ld_warns[j]}" | awk -F "|" '{print $2}')
                shopt -s nocasematch
                if [[ "$vd_health" =~ "$ld_warn_status" ]]; then
                    realnum=$(echo "${vd[i]}" | awk -F ";" '{print $2}')
                    sed -i "/$realnum;/s/^/$ld_warn_level:  /" /tmp/lsi_array_info.txt 2>/dev/null
                fi
            done
        done

        #判断PD是否健康
        pd=($(cat /tmp/lsi_array_info.txt 2>/dev/null | grep "Slot"))
        pd_num=${#pd[@]}
        #echo $pd_num
        for ((i = 0; i < pd_num; i++)); do
            pd_health=$(echo ${pd[i]} | awk -F ":" '{print $NF}')
            for ((j = 0; j < $pd_warns_num; j++)); do
                pd_warn_status=$(echo ${pd_warns[j]} | awk -F "|" '{print $1}')
                pd_warn_level=$(echo ${pd_warns[j]} | awk -F "|" '{print $2}')
                shopt -s nocasematch
                if [[ "$pd_health" =~ "$pd_warn_status" ]]; then
                    realslot=$(echo ${pd[i]} | awk -F ";" '{print $2}' | awk -F ":" '{print $2}')
                    sed -i "/Slot#:$realslot;/s/^/$pd_warn_level:  /" /tmp/lsi_array_info.txt 2>/dev/null
                fi
            done
        done
    fi

    sed -i "/^[a-zA-Z]/s/^/未知状态:  /" /tmp/lsi_array_info.txt 2>/dev/null
    whole_health=$(cat /tmp/lsi_array_info.txt 2>/dev/null | grep -Ec "严重|告警|未知状态")
    if [[ "${whole_health}" -eq 0 ]]; then
        : >/tmp/lsi_array_info.txt 2>/dev/null

    fi
    sed -i 's/VirtualDrive/虚拟磁盘/g;s/PredictiveFailureCount/磁盘错误计数/g;s/State/磁盘状态/g;s/SlotNumber/槽位/g;s/Firmwarestate/磁盘状态/g;s/Slot#/槽位/g;s/IRvolume/虚拟磁盘/g;s/Statusofvolume/磁盘状态/g' /tmp/lsi_array_info.txt 2>/dev/null

}

stat=$(lspci | grep -ciE "raid|lsi|adaptec")
if [[ "${stat}" -lt 1 ]]; then
    echo "信息:  未发现RAID卡，或RAID卡不受支持！"
    exit 0
fi

stat1=$(lspci | grep -iE "raid|adaptec" | grep -c Adaptec)
stat2=$(lspci | grep -i raid | grep -c -i -E 'LSI|DELL|Intel')

if [[ "${stat1}" -ge 1 ]]; then
    CheckArcconf
elif [[ "${stat2}" -ge 1 ]]; then
    CheckLsi
fi
cat /tmp/arcconf_array_info.txt 2>/dev/null
cat /tmp/lsi_array_info.txt 2>/dev/null
rm -rf /tmp/arcconf_array_info.txt 2>/dev/null
rm -rf /tmp/lsi_array_info.txt 2>/dev/null
