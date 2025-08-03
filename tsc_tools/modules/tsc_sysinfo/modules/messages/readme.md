# 采集 messages 日志

## 功能说明

采集 messages 日志, 若日志大于 100m 则仅提示不拷贝.

## 使用方法

```bash
# 从工具主入口调度
./run.sh -m 模块名
# 从模块私有入口调度
CONF_FILE="配置文件" RESULT_DIR="结果输出目录" WARN_DIR="告警日志目录" log_file="日志文件" modules/模块名/run.sh
```
