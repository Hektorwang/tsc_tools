FROM openeuler/openeuler:22.03-lts-sp3 AS builder

LABEL author="X4068"

RUN dnf install --assumeyes --quiet findutils bash

WORKDIR /app

COPY . .
RUN ./build.sh
# RUN find release -type f -name 'tsc_tools-*.sh' -print0 | sort -zV | tail -zn 1 | xargs -0 sh

FROM scratch AS exporter

COPY --from=builder /app/release/ /export/

CMD ["ls", "-l", "/export/"]

# 执行构建和导出命令
# docker buildx build \
#     --progress plain \
#     --no-cache=false \
#     --cache-to=type=local,dest=./tmp/cache \
#     --cache-from=type=local,src=./tmp/cache \
#     --target exporter \
#     --output type=local,dest=./tmp/ \
#   .