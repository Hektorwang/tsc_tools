# 采集 lsof

## 功能说明

采集 lsof  
检查如果有进程打开了被删除的文件则将信息输出到检查结果文件夹下

## 使用方法

```bash
# 从工具主入口调度
./run.sh -m 模块名
# 从模块私有入口调度
CONF_FILE="配置文件" RESULT_DIR="结果输出目录" WARN_DIR="告警日志目录" log_file="日志文件" modules/模块名/run.sh
```
