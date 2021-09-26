FROM ubuntu:20.04
LABEL maintainer="techzealot" \
      version="1.0" \
      description="ubuntu 20.04 with tools for c/c++ programing"

#install build-essential(gcc make) nasm valgrind cmake binutils(objdump) gdb git
# 替换阿里云的源
#set timezone to avoid interactive select
ENV TZ Asia/Shanghai
RUN set -x \
    && cp /etc/apt/sources.list /etc/apt/sources.list.bak \
    && sed  -i "s/archive.ubuntu.com/mirrors.aliyun.com/g" /etc/apt/sources.list \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime  \
    && echo $TZ > /etc/timezone \
    && apt update \
    && apt install -y  build-essential nasm valgrind \
                       cmake binutils gdb git

# 设置工作目录
WORKDIR /mnt