# FIO 测试工具

## 功能说明

测试磁盘性能

## 使用方法

配置主配置文件 globe.common.conf -> fio 段, 务必确认配置测试目录 `fio_dir`

```bash
# 从工具主入口调度
./run.sh -m 模块名
# 从模块私有入口调度
CONF_FILE="配置文件" RESULT_DIR="结果输出目录" WARN_DIR="告警日志目录" log_file="日志文件" modules/模块名/run.sh
```
