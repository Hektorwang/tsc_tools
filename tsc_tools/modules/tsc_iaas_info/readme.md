# tsc_iaas_info

## 功能说明

输出系统基本信息, 包括`处理器`, `内存`, `存储`, `操作系统版本`, `是否虚拟机`.  
支持可使用`Arcconf` 卡和 `storcli` 的 Raid 卡.  
结果输出 json 并生成到 `/var/log/tsc/tsc_iaas_info.json`

## 运行方法说明

```bash
source /home/tsc/tsc_profile
tsc --tsc_iaas_info
# 可选添加合同号和机器位置信息功能
tsc --tsc_iaas_info --contract_no 合同号 --location 机器位置
```
