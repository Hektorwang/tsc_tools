"""日志配置
import tsc_loguru
logger = tsc_loguru.TscLoguru().logger
logger.debug('调试消息')
logger.info('普通消息')
logger.warning('警告消息')
logger.error('错误消息')
logger.critical('严重错误消息')
logger.success('成功调用')
"""
import sys
from pathlib import Path

from loguru import logger


class TscLoguru:
    """
    logger.debug('调试消息')
    logger.info('普通消息')
    logger.warning('警告消息')
    logger.error('错误消息')
    logger.critical('严重错误消息')
    logger.success('成功调用')
    TRACE     5   logger.trace()
    DEBUG     10  logger.debug()
    INFO      20  logger.info()
    SUCCESS   25  logger.success()
    WARNING   30  logger.warning()
    ERROR     40  logger.error()
    CRITICAL  50  logger.critical()

    @logger.catch 函数的异常捕获装饰器
    """

    def __init__(self, **kwargs):
        project_dir = Path(__file__).resolve().parent.parent
        log_name = Path(sys.argv[0]).name
        log_dir = Path(project_dir) / "log"
        log_file = kwargs.get("log_file", False)
        if log_file:
            self.log_file = log_file
        else:
            self.log_file = Path(log_dir) / (log_name + ".log")

        logger.remove(handler_id=None)

        # 添加标准输出
        logger.add(
            level="TRACE",
            sink=sys.stdout,
            format=(
                "[{time:YYYY-MM-DD HH:mm:ss}]\t"
                "<level>"
                "{level}\t{file}\t{message}"
                "</level>"
            ),
            filter=None,
            colorize=True,
            diagnose=True,
            catch=True,
        )

        # 添加文件输出
        if self.log_file:
            logger.add(
                sink=self.log_file,
                format="[{time:YYYY-MM-DD HH:mm:ss}]\t{level}\t{file}\t{message}",
                filter="",
                level="DEBUG",
                encoding="utf-8",
                # 每天0点轮询日志
                rotation="00:00",
                # 保留28天日志
                retention="28 days",
                compression="zip",
                # Loguru 默认情况下是线程安全的, 但它不是多进程安全的。
                # 不过如果你需要多进程/异步记录日志, 它也能支持,
                # 只需要添加一个 enqueue 参数：
                enqueue=True,
                # 格式化的异常跟踪是否应该向上扩展, 超出捕获点, 以显示生成错误的完整堆栈跟踪。
                backtrace=True,
            )
        self.logger = logger


# import tsc_loguru
# logger = tsc_loguru.TscLoguru().logger
# logger.debug('调试消息')
# logger.info('普通消息')
# logger.warning('警告消息')
# logger.error('错误消息')
# logger.critical('严重错误消息')
# logger.success('成功调用')
