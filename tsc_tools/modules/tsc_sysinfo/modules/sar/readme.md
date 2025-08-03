# 采集 sar 日志

## 功能说明

采集 sar 日志, 当有 CPU IOWAIT 高于配置中阈值或 CPU IDLE 低于阈值则告警.

## 使用方法

```bash
# 从工具主入口调度
./run.sh -m 模块名
# 从模块私有入口调度
CONF_FILE="配置文件" RESULT_DIR="结果输出目录" WARN_DIR="告警日志目录" log_file="日志文件" modules/模块名/run.sh
```
