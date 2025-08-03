# 重要节点联通性

## 功能说明

对给定的重要节点列表中的 host 以 20 个并发 ping, 对 ping 不通的节点告警. 并发数量在 globe.common.conf 中配置.

## 使用方法

配置重要节点列表文件: etc/important_hosts, 每行一条 IP 如:

```text
192.168.1.1
192.168.1.2
172.16.31.254
```

```bash
# 从工具主入口调度
./run.sh -m 模块名
# 从模块私有入口调度
CONF_FILE="配置文件" RESULT_DIR="结果输出目录" WARN_DIR="告警日志目录" log_file="日志文件" modules/模块名/run.sh
```
