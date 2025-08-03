# 使用 iperf3 进行带宽测试

## 功能说明

使用 iperf3 进行带宽测试. 程序将先 ssh 到服务端主机, 并打开 `iperf3 -s`, 然后在客户端主机上使用 `bin/iperf3-$(arch) -c $服务端IP -P 10 -t300` 进行测试. 然后和通讯网卡速率进行对比, 若实际通讯速率小于网卡速率的 80% 则告警. 虚拟机网卡或无法获取速率的网卡速率默认视为 1000Mb/s. 如需修改速率对比阈值或网卡默认速率或测试时间可配置 `globe.common.conf`.

## 使用方法

配置 globe.comm.conf -> iperf3 段, 其中 `server_ssh_cmd` 为必须根据现场情况配置的选项. 需要配置为从本机 ssh 到服务端无需交互的操作命令.

```bash
# 从工具主入口调度
./run.sh -m 模块名
# 从模块私有入口调度
CONF_FILE="配置文件" RESULT_DIR="结果输出目录" WARN_DIR="告警日志目录" log_file="日志文件" modules/模块名/run.sh
```

### iperf3

编译参数 `./configure --prefix=/tmp/iperf3 --enable-static-bin --without-openssl --without-sctp`
