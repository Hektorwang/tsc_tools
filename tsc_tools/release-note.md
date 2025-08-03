# 📦 `tsc_tools` 更新日志

## Version=2.0.0.dev

X4068

1. feat: 剥离依赖 `python` 的工具，将相关工具移到 `tsc_python` 中. 可通过加装 `tsc_python` 将剥离的工具集成回来.
2. feat: 不再支持 `el6` 操作系统, 并后续不再对 `el7` 操作系统进行兼容测试, 仅对 `fhos/euler` 操作系统进行测试.
3. feat: 删除一些工具, 并新增一些工具.
4. refactor(tsc): 修改入口脚本, 后续工具调用方式都由此入口进入.
5. refactor: 每个工具都进行检查确认, 有需要的都修改调度方式, 原有工具改好确认过的才加回本工具集.
6. chore: 更改安装目录到 `/home/tsc/tsc_tools`.
7. chore: 修改为使用 `makeself` 打包, 并使用 `gitea/jenkins` 自动集成.
8. TODO: 逐步将原有工具添加回来.

## Version=1.8.8

20240614 X4068

1. fix(tsc_sysinit): 修复执行时会反复执行不能退出的问题.

## Version=1.8.7

20240401 X4068

1. fix(install.sh): 修复根据发布日期判断包过老不能安装时取日期错误问题.
2. fix(install.sh): 因暂时无法解决 Ansible 远程批量安装工具强制开启 pty 导致本工具无法判断结束安装的问题，暂时取消安装完成后进入子 shell 自动生效环境变量的功能.
3. fix(sshpass): 更换 sshpass-x86_64 程序.

## Version=1.8.6

20240401 X4068

1. feat(tsc_getSerialNumber, tsc_show_hardware_str): 过滤部分如 `000000` 的明显不合法的序列号.
2. fix(tsc_sysinit): 因 FOS 的 NSSwitch 回落机制更改，需开启 SSSD 服务才能使用 EL6 系统上静态编译的 sshpass。判断当操作系统为 FOS 时开启该服务.
3. feat(tsc_sysinit): 原修改 GRUB 的函数 `config_update_kernel` 因无需求场景，默认不执行.
4. TODO(tsc_sysinfo): sysinfo 的批量采集后对日志进行分析生成汇总结果.

## Version=1.8.5

20240401 X4068

1. feat(tsc_getSerialNumber, tsc_show_hardware_str): 因部分厂家的序列号写到 `baseboard-serial-number` 段而非 `system-serial-number` 段，改为从 `baseboard-serial-number` 读取
2. feat(install.sh): 增加判断当前安装进程如果没有 TTY，则安装最后步骤不进入子 shell，避免远程调用时进入子 shell 后远程端无法识别到安装结束
3. TODO(tsc_sysinfo): sysinfo 的批量采集后对日志进行分析生成汇总结果

## Version=1.8.4

20240401 X4068

1. refactor(tsc_getSerialNumber): 适配 Zabbix 读取新的 `tsc_show_hardware_str` 序列号生成日志形式
2. TODO(tsc_sysinfo): sysinfo 的批量采集后对日志进行分析生成汇总结果

## Version=1.8.3

20240227 张\*X6735

1. feat: 增加了对过旧的版本禁止安装功能
2. TODO(tsc_sysinfo): sysinfo 的批量采集后对日志进行分析生成汇总结果

## Version=1.8.2

20240227 X4068

1. fix(tsc_show_hardware_str): 修复读取保存到文件的本机序列号功能问题
2. TODO(tsc_sysinfo): sysinfo 的批量采集后对日志进行分析生成汇总结果

## Version=1.8.1

20240221 X4068

1. feat(qrencode): 增加文本转换二维码模块
2. feat(tsc_show_hardware_str): 增加对接运维管理中心版设备序列号查询标签系统功能
3. TODO(tsc_sysinfo): sysinfo 的批量采集后对日志进行分析生成汇总结果

## Version=1.7.2

20240219 X4068

1. feat(tsc_sysinfo): sysinfo 模块增加批量执行并采集结果功能
2. TODO(tsc_sysinfo): sysinfo 的批量采集后对日志进行分析生成汇总结果

## Version=1.7.1

20240205 X4068

1. feat(ansible_profile): `tsc_ansible` 和 `tsc_ansible-playbook` 增加支持从环境变量导入配置功能。当调用这两个工具时会以变量形式引入 `ansible_profile` 中的 Ansible 配置，本次更新后支持在命令调用环境上以环境变量覆盖 `ansible_profile` 中配置变量的功能，例如

   ```bash
   ANSIBLE_PIPELINING=False tsc_ansible -i host all -m "ping"
   ```

2. TODO(tsc_sysinfo): 系统运行环境采集检查 功能的两种批量调度模式待开发，需修改所有模块输出格式后才能汇总检查结果

## Version=1.7.0

20240205 X4068

1. feat(tsc_sysinfo, tsc_iaas_check): 将`系统运行时基础环境采集工具 (tsc_sysinfo)`合并入运维工具集，并将`基础环境完工检查工具 (tsc_iaas_check)`的所有功能合并入此工具。对该工具提供批量调度功能，并增加了批量压测功能。

## Version=1.6.4

20240122 张\*X6735

1. modify(install.sh): 安装完成后使用 `exec` 自动加载工具集环境
2. fix: 修复机器信息采集阶段 OS 类型受主机名影响导致采集结果有误的问题

## Version=1.6.3

20240109 张\*X6735

1. delete: 移除标签系统相关内容

## Version=1.6.2

20231221 X4068

1. update(tsc_os_install_server-2.0.0): 更新 `11.标准化操作系统无人值守远程安装服务端搭建工具`，支持 el7/fos, x64

## Version=1.6.1

20231221 张\*X6735

1. fix: 解决 EL7 x86_64 机器安装失败的问题 (OS: el7a)
2. fix: 在计算 `/root/.vimrc` 文件 md5 值前先检查文件是否存在
3. fix: 修正 `/var/log/tsc/` 目录校验和创建部分存在的逻辑错误

## Version=1.6.0

20231213 X4068

1. modify: 为方便执行者观测，`tsc_ansible` 输出回调为 JSON，`tsc_ansible-playbook` 输出回调为 YAML。
2. modify: 修改了 `tsc_sysinit` 中少量错误，并修改了系统参数调优的具体调优值。
3. TODO: 操作系统安装待修改。

20231213 张\*X6735

1. feat: 修改 `sar 系统性能分时比对` 工具，适配 FOS 和 KylinOS
2. delete: 移除 `硬件操作系统-系统信息采集` 工具，停止维护

20231212 张\*X6735

1. feat: 修改 build/install.sh，支持 ky10 系统
2. modify: 重构 build/install.sh，修改 jq 等工具安装流程，移除 cron_tsc
3. modify: 修改 bin/tsc，适配 glow
4. docs(doc): 重构 `05.远程管理` 章节，适配 tsc_ansible
5. modify(doc): 重构 `07.业务常用` 章节
6. fix: 移除 bin/.vimrc 文件，安装脚本只认 vimrc
7. delete(packet): 删除性能测试工具和 fping、jq 等工具的安装包
8. feat(packet): 新增 fio、fping、glow、iperf3、jq、sshpass、stress-ng 静态编译所得二进制工具

20231210 X4068

1. feat: 适配 FitStarrySkyOS 操作系统
2. fix: 修复 `01.批量修改主机名` 中文件名错误描述
3. fix: 修改 .vimrc，适配 FitStarrySkyOS

## Version=1.5.4

20231101 张\*X6735

1. fix: 解决 jq 安装失败的问题；修改 fping、jq、netcat、sshpass 安装流程，日志不再输出至黑洞，安装失败时留存本地日志。

## Version=1.5.3

20231027 张\*X6735

1. feat: 增加 `sar 系统性能分时比对` 工具 (`tsc 9 5`)。

20231012 凌\*X8343

1. 增加：环境检查及初始化 `tsc_sysinit` 脚本集成 `fh-data-recovery-1.3.6-1.noarch.rpm` 安装
   - 默认执行 `tsc_sysinit -s` 时安装 fhmv
   - 单独安装/升级 fhmv 可执行 `tsc_sysinit -m config_fhmv`
   - 备注：fhmv-1.3.6 版本开始支持 fhos 系统安装。

## Version=1.5.2

20230915 张\*X6735

1. modify(install.sh): 支持 FitStarrySkyOS 系统安装。
2. 重写：`bin/tsc` 和 `doc/manual.py`，规避 Python 环境不一致导致脚本无法正常工作的问题。
3. 修改：`tsc_sysinit` 和 `tsc_init_check`，适配 FitStarrySkyOS 系统。
4. 重写：批量修改主机名工具、批量建立信任工具，新版本基于 Ansible 实现。

## Version=1.5.1

20230707 张\*X6735

1. 修改：`tsc_changenhostame`，解决 eval 引起的远程工作异常问题，该 BUG 会导致执行脚本的机器主机名被误修改。
2. 修改：`install.sh`，若 sshpass 不在默认 PATH 中，将建立 `/usr/bin/sshpass` 软连接。

## Version=1.5.0

20230613 X4068

1. 修改：`tsc_iaas_check`，版本更新到 1.1.0。

## Version=1.4.0

20230516 X4068

1. 增加：`tsc_iaas_check`，增加按《基础环境完工检查项.xlsx》对交付的设备进行自检。
2. 修改：`cron_tsc`，去掉向 cn.pool.ntp.org 对时的无意义配置。
3. 修改：`build.sh`, `install.sh`，根据 shellcheck 和 shfmt 检查进行优化，并增加排除文件列表 `ignorelist`
4. 增加：`18.基础环境完工检查`，增加基础环境完工检查工具说明。
5. 增加：`ignorelist`，在此列表中的 pattern 都不会被 `build.sh` 打包

## Version=1.3.2

20230410 X4068

1. feat: 新增 `tsc_ssh_copy_id` 工具，用于快速建立主机间 SSH 信任
2. modify: 优化 `tsc_batch_ssh` 脚本逻辑，提升远程执行效率
3. fix: 修复部分系统下因缺少 `expect` 导致的信任建立失败问题

## Version=1.3.1

20230328 张\*X6735

1. feat: 增加 `tsc_check_kernel` 模块，用于检查当前内核版本是否符合安全合规要求
2. modify: 优化 `tsc_check_kernel` 输出格式，适配统一日志采集系统

## Version=1.3.0

20230315 X4068

1. feat: 引入 `tsc_inventory` 模块，支持 Ansible 动态 Inventory 构建
2. feat: 增加对 AWS EC2 实例的自动识别与标签提取功能
3. modify: 重构 `tsc_ansible` 入口脚本，增强参数兼容性与错误提示能力

## Version=1.2.5

20230228 张\*X6735

1. fix: 修复在 EL8 系统中因 Python 版本不兼容导致的 `tsc_aws` 模块异常
2. modify: 升级依赖包，替换 `boto` 为 `boto3`，提升 AWS 接口稳定性

## Version=1.2.4

20230210 X4068

1. feat: 新增 `tsc_logrotate` 模块，用于集中管理工具日志轮转策略
2. modify: 默认启用日志压缩功能，减少磁盘占用

## Version=1.2.3

20230125 张\*X6735

1. fix: 修复 `tsc_logrotate` 在非 root 权限下运行时权限不足的问题
2. modify: 日志路径改为可配置项，支持用户自定义

## Version=1.2.2

20230110 凌\*X8343

1. feat: 增加 `tsc_backup` 模块，用于备份关键配置文件至远端服务器
2. feat: 支持通过环境变量指定备份目标地址、目录及保留天数

## Version=1.2.1

20221225 张\*X6735

1. fix: 修复 `tsc_backup` 因未检测远端目录是否存在导致的传输失败问题
2. modify: 增加断点续传功能，提升大文件备份稳定性

## Version=1.2.0

20221210 X4068

1. feat: 新增 `tsc_audit` 模块，提供基础安全审计功能
   - 包括：弱密码检测、SSH 配置审计、账户登录历史分析等
2. modify: 所有模块默认输出 JSON 格式日志，便于集中分析

## Version=1.1.3

20221120 张\*X6735

1. feat: 增加对 SELinux 状态的检查与临时关闭支持
2. fix: 修复 `tsc_audit` 在 CentOS 7 上因命令版本差异导致的误报问题

## Version=1.1.2

20221015 张\*X6735

1. fix: 修复 `tsc_audit` 在部分系统上因缺少 `lastlog` 命令导致的崩溃问题
2. modify: 日志中增加模块版本信息，便于追踪调试

## Version=1.1.1

20221005 X4068

1. feat: 新增 `tsc_check_ssh` 模块，用于检测 SSH 配置安全性
2. feat: 支持检测是否存在空密码账户或 root 直接登录等高危配置

## Version=1.1.0

20220920 张\*X6735

1. feat: 引入 `tsc_config` 模块，集中管理工具全局配置参数
2. feat: 支持通过 `~/.tsc/config` 文件进行个性化设置
3. modify: 所有模块加载配置时优先读取用户配置，再合并默认配置

## Version=1.0.5

20220830 凌\*X8343

1. fix: 修复在低权限账户下执行 `tsc_config` 时写入失败的问题
2. modify: 增加配置文件校验机制，避免非法配置导致工具异常

## Version=1.0.4

20220815 张\*X6735

1. feat: 新增 `tsc_clean` 模块，用于清理过期日志和临时文件
2. modify: 默认每周自动清理一次日志目录，可通过配置关闭

## Version=1.0.3

20220725 X4068

1. feat: 增加 `tsc_help` 模块，提供交互式命令查询与示例展示
2. modify: 所有命令支持 `-h` 或 `--help` 参数查看详细说明

## Version=1.0.2

20220710 张\*X6735

1. fix: 修复帮助文档中部分命令描述错误的问题
2. modify: 增加中文提示支持，提升国内用户使用体验

## Version=1.0.1

20220620 X4068

1. feat: 完成基础工具链整合，发布首个稳定版本
2. feat: 提供完整的安装脚本、配置说明与用户手册
3. feat: 支持 CentOS 7/8、Ubuntu 20.04+、FOS 等主流发行版

## Version=1.0.0

20220615 X4068

1. feat: 初始化项目架构，搭建核心框架
2. feat: 包含常用运维命令封装、Ansible 集成、环境检查等功能
3. feat: 初步实现无 Python 依赖运行机制，兼容性更强

## 💡 创始人寄语（早期提交）

> applex*911 提交记录（2018 年 ~ 2019 年）  
> mangox*715、watch*101、朱*x0854、D*007、张*x6735 等开发者陆续加入贡献

### 一段感性的留言

> 致终于来到这里的勇敢的人：  
> 你是被上帝选中的人，是英勇的、不敌辛苦的、不眠不休的骑士。  
> 如果看到这能带给你快乐的话，那就点个稀饭吧，谢谢赏脸，愿所有的程序都永无 Bug，虽然我知道这项目有很多 bug，还是希望能为大家带来快乐，缓解一些你们工作中的压力，减少一些重复劳动。  
> 虽然代码很烂，虽然你读得懂这里的代码。但是你不会懂写代码人的心情的。  
> Do something meaningful while you are young.

## 📌 当前状态

- 已整合多个运维工具模块（如 Ansible 集成、批量操作、硬件采集、系统初始化等）
- 支持多种 Linux 发行版（包括 CentOS、EL、FOS、KylinOS 等）
- 持续优化自动化部署与远程管理能力
- 待完善：`tsc_sysinfo` 批量采集后的日志汇总分析功能
