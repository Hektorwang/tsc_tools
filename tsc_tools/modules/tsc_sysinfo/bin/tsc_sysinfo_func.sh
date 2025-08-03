#!/bin/bash
# 输出交付检查工具所用日志格式
# 主机名修改:已修改:eXdjZW50ZXItcGctNTUtOTkK
function LOGDELIVERY {
    if [[ $# -ne 3 ]]; then
        LOGERROR "${FUNCNAME[0]}", 参数必须为 3 个: module_name status info
        return 1
    fi
    local module_name status info
    module_name=$1
    status=$2
    info=$3
    info_b64=$(
        base64 -iw0 <<eof
${info}
eof
    )
    echo "${module_name}":"${status}":"${info_b64}"
    return 0
}
export -f LOGDELIVERY
