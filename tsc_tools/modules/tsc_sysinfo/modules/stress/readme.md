# 使用 stress-ng 进行压力测试

## 功能说明

使用 stress-ng 工具进行压力测试, 看是否机器会死机. 测试参数参考:

```bash
# 工具运行时压测时间 stress_time 从 globe.common.conf 中读取
# 工具运行时压测目录 stress_dir 从 globe.common.conf 中读取
# 以机器一半的可用内存和压测目录剩余空间的一半进行测试
stress_time=1h
stress_dir=/
free_mem="$(free -m | awk '/Mem/{print int($NF/2)}')"
workers="$(($(nproc) + 1))"
disk_available=$(df -Plk / | awk 'NR==2{print int($4/2)"K"}')
cd "${stress_dir}"
stress-ng \
    -c "${workers}" \
    --vm "${workers}" --vm-bytes "${free_mem}"M \
    -d "${workers}" --hdd-bytes "${disk_available}" --hdd-opts direct \
    --iomix "${workers}" --smart \
    -t "${stress_time}"
```

## 使用方法

```bash
# 从工具主入口调度
./run.sh -m 模块名
# 从模块私有入口调度
CONF_FILE="配置文件" RESULT_DIR="结果输出目录" WARN_DIR="告警日志目录" log_file="日志文件" modules/模块名/run.sh
```

### stress-ng

stress-ng 是一个兼容 stress 但增加了数百项指标的压测工具. 使用 0.17.01 版, 编译参数为 `STATIC=1 make -j$($(nproc)+1)` 以获得静态二进制文件.
