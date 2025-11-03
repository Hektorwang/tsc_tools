# release-note

## Version=2.0.3.beta3

1. feat: 给 `tsc_iaas_info` 增加告警功能. 当执行 `--runtime` 时会生成结果告警对象 `warning`, 提供处理器, 内存, 存储使用率告警及存储健康状态告警, 并可额外指定告警阈值. 如此当 `zabbix` 调用时可直接读取该对象, 减轻在服务端计算压力;
2. feat: 给 `tsc_iaas_info` 增加手工设置序列号功能. 当执行 `--sn` 时会用手工配置的序列号覆盖原保存的序列号, 否则会优先读取原配置中序列号. 如既未手工配置序列号, 原配置序列号也为空, 则尝试从硬件中读取序列号;
3. fix: 修复因 raid 判断方法问题导致的重复安装失败问题
4. fix: 修复 tsc_iaas_info 采集 raid 卡重复问题
5. fix: 调整 tsc_iaas_info --runtime 输出数据结构, 以及判断 `warning` 方法.
6. TODO: 补充 README.md

## Version=2.0.2.beta

1. feat: 给 `tsc_iaas_info` 增加 `runtime` 选项, 收集系统运行时资源状态, 参考 `zabbix` 上原生的多个监控项内容;

## Version=2.0.1.dev

X4068

1. fix: 修改了两个 raid 卡工具的安装方式和调用方式, 优先调用系统已安装好的工具;
2. fix: 修复了 `tsc_sysinit` 的几个问题;
3. feat: 依赖 python 的工具已经全部剥离;
4. TODO: 给 `tsc_iaas_info` 增加 `runtime` 选项, 收集系统运行时资源状态, 参考 `zabbix` 上原生的多个监控项内容;

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
