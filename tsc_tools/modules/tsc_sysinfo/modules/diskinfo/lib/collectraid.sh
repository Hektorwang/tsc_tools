#!/bin/bash
set +o posix

CollectArcconf() {
    (
        # 获取型号
        /usr/Arcconf/arcconf list |
            grep "Controller [0-9]" |
            awk -F "," '{print "Raid卡型号:"$4}'
        # 获取驱动版本
        /usr/Arcconf/arcconf GETVERSION |
            grep -E "Firmware|Driver" |
            sed 's/ //g' |
            sed 'N;s/\n/;/g' |
            awk '{print "固件驱动版本:"$0}'
        echo "RIAD信息======================"
        /usr/Arcconf/arcconf GETCONFIG 1 LD >>"${result_dir}"/RIAD信息.log
        # /usr/Arcconf/arcconf GETCONFIG 1 LD|grep -E "Logical Device number|RAID level|Size|Status of Logical Device"|grep -vE "Full Stripe Size|Block Size of member drives"|sed 'N;N;N;s/\n/;/g'|sed s/number/number:/g|sed 's/ //g' >>/tmp/raidinfo.tmp

        /usr/Arcconf/arcconf GETCONFIG 1 LD |
            grep -E "Logical Device number|RAID level|Size|Status of Logical Device|Device" |
            grep -vE "Full Stripe Size|Block Size of member drives|Logical Device name|Device Type" |
            sed s/number/number:/g |
            sed 's/ //g'

        echo "物理磁盘信息=================="

        /usr/Arcconf/arcconf GETCONFIG 1 PD |
            grep -Ew "Device |Vendor|Model|Total Size|Serial number|State|Transfer Speed|Rotational Speed|SSD" |
            grep -v "Power State" |
            sed 's/ //g' |
            sed 'N;N;N;N;N;N;N;N;s/\n/;/g' |
            grep "TotalSize"
    ) >/tmp/raidinfo.tmp

    sed -i 's/;SSDSmartTripWearout.*//g' /tmp/raidinfo.tmp
    sed -i 's/LogicalDevicenumber/虚拟磁盘/g;s/RAIDlevel/RAID级别/g;s/StatusofLogicalDevice/虚拟磁盘状态/g;s/;Size/;虚拟磁盘大小/g;s/Device#/槽位:/g;s/State/磁盘状态/g;s/Vendor/厂家/g;s/Serialnumber/序列号/g;s/TotalSize/磁盘容量/g;s/TransferSpeed/接口类型/g;s/Model/型号/g;s/RotationalSpeed/转速/g;s/ArrayPhysicalDeviceInformation/RAID成员磁盘:/g' /tmp/raidinfo.tmp
}

CollectLsi() {
    (
        /opt/MegaRAID/storcli/storcli64 /c0 show nolog |
            grep -E "Product Name" |
            awk -F "=" '{print "Raid卡型号:"$2}'
        /opt/MegaRAID/storcli/storcli64 /c0 show nolog |
            grep -E "BIOS Version|FW Version|Driver Version" |
            sed 's/=/:/g;s/ //g' |
            sed 'N;N;s/\n/;/g' |
            awk '{print "固件驱动版本:"$0}'

        echo "RIAD信息======================"

        /opt/MegaRAID/storcli/storcli64 /c0/dall show nolog |
            awk '/----/ 
                {count++;if (count > 1) print buffer;buffer = ""; next}
                {buffer = buffer $0 ORS}'
        /opt/MegaRAID/storcli/storcli64 /c0/vall show >>"${result_dir}"/RIAD信息.log
        #/opt/MegaRAID/storcli/storcli64  /c0/vall show |awk '/----/ {count++; next} count == 2 {print} count > 2 {exit}'|awk -F "/" '{print $2}'|awk '{print "LogicalDevicenumber:"$1";RAIDlevel:"$2";StatusofLogicalDevice:"$3";Size:"$9$10}' >> /tmp/raidinfo.tmp
        echo "物理磁盘信息=================="

        #/opt/MegaRAID/storcli/storcli64 /c0/eall/sall show  |awk '/----/ {count++; next} count == 2 {print} count > 2 {exit}'
        /opt/MegaRAID/storcli/storcli64 /c0/eall/sall show nolog |
            awk '/----/ {count++; next} count == 2 {print} count > 2 {exit}' |
            awk -F ":" '{print $2}' |
            awk '{print "Device#"$1";State:"$3";Size:"$5$6";;Model:"$12";TransferSpeed:"$7";SSD:"$8}'
    ) >/tmp/raidinfo.tmp

    sed -i 's/LogicalDevicenumber/虚拟磁盘/g;s/RAIDlevel/RAID级别/g;s/StatusofLogicalDevice/虚拟磁盘状态/g;s/Device#/槽位:/g;s/State/磁盘状态/g;s/Vendor/厂家/g;s/Serialnumber/序列号/g;s/Size/磁盘容量/g;s/TransferSpeed/接口类型/g;s/Model/型号/g;s/RotationalSpeed/转速/g' /tmp/raidinfo.tmp
}

source /etc/profile

stat=$(lspci | grep -ciE "raid|lsi|adaptec")
if [ "${stat}" -lt 1 ]; then
    exit 0
fi

stat1=$(lspci | grep -iE 'raid|adaptec' | grep -c Adaptec)
stat2=$(lspci | grep -i raid | grep -c -i -E 'LSI|DELL|Intel')
stat3=$(lspci | grep -i raid | grep -c "Hewlett-Packard")

if [ "${stat1}" -ge 1 ]; then
    CollectArcconf
elif [ "${stat2}" -ge 1 ]; then
    CollectLsi
fi

echo "=======================" >>/tmp/raidinfo.tmp
vendor=$(dmidecode -t system | grep Manufacturer | awk -F ':' '{print $2}')
echo "设备厂商:${vendor}" >>/tmp/raidinfo.tmp

cat /tmp/raidinfo.tmp
