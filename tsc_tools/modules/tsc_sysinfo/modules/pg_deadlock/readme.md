# 检查 pg 中是否存在指定锁类型

## 功能说明

检查 pg 中是否存在指定锁类型

## 使用方法

需配置 globe.common.conf, 必须配置可连接 pg 库的命令, 当 pg 库有独占锁持续时长超过 30 秒告警.

```bash
# 从工具主入口调度
./run.sh -m 模块名
# 从模块私有入口调度
CONF_FILE="配置文件" RESULT_DIR="结果输出目录" WARN_DIR="告警日志目录" log_file="日志文件" modules/模块名/run.sh
```
