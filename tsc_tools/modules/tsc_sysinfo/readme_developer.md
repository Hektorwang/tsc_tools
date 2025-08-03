# 模块开发

## 入口脚本提供变量说明

入口脚本设置以下环境变量, 供模块使用. 其中 script_name, log_file 这两个设置为非只读, 模块可自行修改.

### 通用变量

| 变量名      | 变量说明           | 取值                                                                    | 只读 |
| ----------- | ------------------ | ----------------------------------------------------------------------- | ---- |
| WORK_DIR    | 本工具主目录       | 本工具主目录                                                            | 是   |
| ETC_DIR     | 主配置目录         | `$WORK_DIR/etc`                                                         | 是   |
| CONF_FILE   | 主配置文件         | `$ETC_DIR/globe.comm.conf`, 另该文件软连接到 `$WORK_DIR/gloe.comm.conf` | 是   |
| LOG_DIR     | 主日志目录         | `$WORK_DIR/log/`                                                        | 是   |
| script_name | 主入口脚本文件名   | `run.sh`                                                                | 否   |
| log_file    | 主日志文件         | `$LOG_DIR/run.sh.log`                                                   | 否   |
| DATETIME    | 开始执行时间       | `date +'%Y%m%d%H%M%S'`                                                  | 是   |
| RESULT_DIR  | 本次采集文件主目录 | `$LOG_DIR/$DATETIME/result/`                                            | 是   |
| WARN_DIR    | 本次告警文件主目录 | `$LOG_DIR/$DATETIME/warn/`                                              | 是   |
| TMP_DIR     | 本次执行临时主目录 | `$WORK_DIR/tmp/$DATETIME`                                               | 是   |

### 操作系统

入口脚本已获取操作系统版本及处理器架构, 供模块使用. 对于可能有无法获取到操作系统发行版, 及操作系统发行版不在支持列表内的情况, 入口脚本不会退出. 模块可根据自身工作是否有操作系统相关性, 根据 `get_os_arch_flag` 变量决定是否要退出本模块工作.
支持的操作系统发行版当前设定为: 'RedHat', 'CentOS', 'Fit StarrySky OS', 'Kylin Linux Advanced Server'

| 变量名           | 变量说明                                       | 值样例                      |
| ---------------- | ---------------------------------------------- | --------------------------- |
| os_distribution  | 操作系统发行版                                 | `Fit StarrySky OS`          |
| os_version       | 操作系统版本                                   | `"6.7","7.4","v10","22.06"` |
| arch             | 处理器架构                                     | `"x86_64", "aarch64"`       |
| get_os_arch_flag | 是否成功获取操作系统版本且操作系统在支持列表内 | 0:是, 1:否                  |

## 日志函数

日志定义在 `"${WORK_DIR}"/bin/func` 和 `"${WORK_DIR}"/bin/tsc_sysinfo_func.sh` 中, 入口脚本已引入, 模块可直接调用这些函数

| 函数名      | 函数说明             | 显示输出 | 日志输出                                                                                                  |
| ----------- | -------------------- | -------- | --------------------------------------------------------------------------------------------------------- |
| LOGINFO     | 信息                 | stdout   | 当 $log_file 变量存在则输出到该文件                                                                       |
| LOGSUCCESS  | 成功                 | stdout   | 当 $log_file 变量存在则输出到该文件                                                                       |
| LOGWARNING  | 警告                 | stderr   | 当 $log_file 变量存在则输出到该文件                                                                       |
| LOGERROR    | 错误                 | stderr   | 当 $log_file 变量存在则输出到该文件                                                                       |
| LOGDEBUG    | 调试                 | stderr   | 当 $log_file 变量存在则输出到该文件                                                                       |
| LOGDELIVERY | 汇总模式专用日志函数 | stdout   | 需自行重定向至${result_dir}/“模块名”\_delivery.log 中,输入参数为 参数必须为 3 个: module_name status info |

第三个参数会被进行 base64 编码,以保存自定义格式文本。供生成汇总日志使用。
|

```bash
# 调用样例
LOGERROR "未支持的操作系统: ${os_distribution}"
# [2023-11-15 16:02:56]	ERROR	run.sh	未支持的操作系统: CentOS

LOGDELIVERY 带宽测试 成功 "收: 100mbps,
> 发: 200mbps"
带宽测试:成功:5pS2OiAxMDBtYnBzLArlj5E6IDIwMG1icHMK
echo 5pS2OiAxMDBtYnBzLArlj5E6IDIwMG1icHMK|base64 -d
收: 100mbps,
发: 200mbps
```

## 入口脚本调度模块及传参

1. 当未指定入口脚本位置参数时, 入口脚本读取主配置文件 `globe.common.conf`-`common`-`default_modules`, 根据该配置查找 `modules/对应目录/run.sh` 并串行执行.
2. 当需要指定模块执行时, 入口脚本根据传入的 `-m` 参数, 查找 `modules/对应目录/run.sh` 并执行.
3. 当指定模块时还可传输模块参数 使用方法为 `./run.sh -m "模块1" -a "模块1的参数"`.
4. 可同时指定多个模块及其对应的参数执行, 如 `./run.sh -m "模块1" -a "模块1的参数" -m "模块2" -m "模块3" -a "模块3的参数`
