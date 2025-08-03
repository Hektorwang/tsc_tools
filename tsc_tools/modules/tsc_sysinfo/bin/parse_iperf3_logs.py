"""解析采集到的各机器日志生成表格"""
import json

# from collections import defaultdict
from pathlib import Path

import pandas as pd

import tsc_loguru

logger = tsc_loguru.TscLoguru().logger


class CheckLogs:
    """读取日志并汇总生成表格"""

    def __init__(self, input_dir):
        logger.info(f"分析日志目录: {input_dir}")
        self.input_dir = input_dir

    def read_logs(self):
        """
        read_logs 遍历读取日志文件, 将每文件内容转为一个字典再组成一个列表

        Returns:
            list: 准备写入表格的结果集
        """
        input_dir = self.input_dir
        result = {}
        for log_file in input_dir.rglob("*delivery.log"):
            host = log_file.parent.name
            if result.get(host) is None:
                result[host] = {}
                result[host]["测速服务器"] = "读取文件失败"
                result[host]["测速(mbps) 详情"] = log_file.as_posix()
            try:
                with open(log_file, mode="r", encoding="utf-8") as f:
                    data = json.load(f)
                    try:
                        server_host = data["start"]["connecting_to"]["host"]
                        send_bps = data["end"]["sum_sent"]["bits_per_second"]
                        recive_bps = data["end"]["sum_received"]["bits_per_second"]
                    except AttributeError as get_json_data_e:
                        logger.debug(get_json_data_e)
                        logger.error(f"解析日志数据失败: {log_file.as_posix()}")
                        continue
                    send_mbps = round(send_bps / 1024 / 1024)
                    receive_mbps = round(recive_bps / 1024 / 1024)

                    result[host]["测速服务器"] = server_host
                    result[host]["测速(mbps) 详情"] = f"收:{receive_mbps}, 发:{send_mbps}"

            except Exception as open_file_e:
                logger.debug(open_file_e)
                logger.critical(f"读取文件失败: {log_file.as_posix()}")
        return result

    def run(self):
        read_logs = self.read_logs
        input_dir = self.input_dir
        excel_file = input_dir / "iperf3.xlsx"
        result = read_logs()
        # logger.debug(result)
        # pd.DataFrame.to_pickle('/tmp/tsc_iaas_check.pkl')
        # data = pd.DataFrame(result)
        data = pd.DataFrame.from_dict(result, orient="index")
        data.reset_index().rename(columns={"index": "host"}, inplace=True)
        # 1.1.0 根据柏总要求删除部分列
        # drop_cols = [
        #     "CPU节能 详情",
        #     "CPU虚拟化 详情",
        #     "系统默认启动级别 详情",
        #     "selinux关闭 详情",
        #     "压力测试日志 详情",
        # ]
        # data.drop(drop_cols, axis=1, inplace=True)
        # data1 按检查项组织
        data1 = data[[x for x in list(data.columns) if "详情" not in x]]
        data1 = data1.reset_index().rename(columns={"index": "host"})
        melted_data1 = pd.melt(
            data1,
            id_vars="host",
            var_name="check",
            value_name="status",
        )
        data_summary = (
            melted_data1.groupby(["check", "status"])["host"]
            .apply(",".join)
            .reset_index()
        )
        with pd.ExcelWriter(excel_file) as writer:
            data_summary.to_excel(
                writer,
                index=False,
                freeze_panes=(1, 1),
                sheet_name="按检查项组织",
            )
            data.to_excel(
                writer,
                freeze_panes=(1, 1),
                index_label="主机",
                sheet_name="按主机组织",
            )
        logger.success(f"请查看: {excel_file}")


if __name__ == "__main__":
    PROJECT_DIR = Path(__file__).resolve().parent.parent
    run_log_dir = PROJECT_DIR / "batch_logs"
    obj = CheckLogs(run_log_dir)
    obj.run()
