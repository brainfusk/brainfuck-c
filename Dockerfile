# CLion remote docker environment (How to build docker container, run and stop it)
#
# Build and run:
#   docker build -t clion/remote-cpp-env:0.5 -f Dockerfile.remote-cpp-env .
#   docker run -d --cap-add sys_ptrace -p127.0.0.1:2222:22 --name clion_remote_env clion/remote-cpp-env:0.5
#   ssh-keygen -f "$HOME/.ssh/known_hosts" -R "[localhost]:2222"
#
# stop:
#   docker stop clion_remote_env
#
# ssh credentials (test user):
#   user@password
# reversion from https://github.com/JetBrains/clion-remote/blob/master/Dockerfile.remote-cpp-env
FROM ubuntu:20.04

LABEL maintainer="techzealot" \
      version="1.0" \
      description="ubuntu 20.04 with dev tools for c/c++/rust programing"

#RUN DEBIAN_FRONTEND="noninteractive" apt-get update && apt-get -y install tzdata
ENV USER deploy
ENV PASSWD deploy
ENV PROJECTDIR projects
ENV TZ Asia/Shanghai

RUN set -x \
    # only for users in china to accelerate
    && cp /etc/apt/sources.list /etc/apt/sources.list.bak \
    && sed  -i "s/archive.ubuntu.com/mirrors.aliyun.com/g" /etc/apt/sources.list \
    # set timezone to avoid interactive select
    && ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime  \
    && echo ${TZ} > /etc/timezone \
    && apt-get update \
    && apt-get install -y ssh \
      build-essential nasm valgrind binutils git net-tools lsof vim \
      gcc \
      g++ \
      gdb \
      clang \
      cmake \
      ninja-build \
      rsync \
      tar \
      python \
    && apt-get clean

RUN ( \
    echo 'LogLevel DEBUG2'; \
    echo 'PermitRootLogin yes'; \
    echo 'PasswordAuthentication yes'; \
    echo 'Subsystem sftp /usr/lib/openssh/sftp-server'; \
  ) > /etc/ssh/sshd_config_test_clion \
  && mkdir /run/sshd

RUN useradd -m ${USER} \
  && yes ${PASSWD} | passwd ${USER}

RUN usermod -s /bin/bash ${USER}

# set root passwd
RUN echo "root:root" | chpasswd

USER ${USER}

RUN mkdir -p /home/${USER}/${PROJECTDIR}/

USER root

WORKDIR /home/${USER}/${PROJECTDIR}/

CMD ["/usr/sbin/sshd", "-D", "-e", "-f", "/etc/ssh/sshd_config_test_clion"]