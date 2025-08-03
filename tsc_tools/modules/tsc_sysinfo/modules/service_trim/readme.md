# 检查服务是否裁剪

## 功能说明

检查服务是否裁剪

## 使用方法

默认服务列表: (sysstat crond sssd irqbalance rsyslog sshd auditd microcode ipmi tuned getty NetworkManager iptables zabbix-agent zabbix-proxy zabbix-server tsc_salt-master tsc_salt-minion)

```bash
# 从工具主入口调度
./run.sh -m 模块名
# 从模块私有入口调度
CONF_FILE="配置文件" RESULT_DIR="结果输出目录" WARN_DIR="告警日志目录" log_file="日志文件" modules/模块名/run.sh
```
