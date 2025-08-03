# 采集 vmstat

## 功能说明

采集 30 秒 vmstat 信息, 期间当 r, b 列持续大于 cpu 线程数告警, 当 wa 列持续大于设定阈值告警, 当交换分区被使用超过 1 次告警

## 使用方法

```bash
# 从工具主入口调度
./run.sh -m 模块名
# 从模块私有入口调度
CONF_FILE="配置文件" RESULT_DIR="结果输出目录" WARN_DIR="告警日志目录" log_file="日志文件" modules/模块名/run.sh
```
