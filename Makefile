SOURCES:= brainfuck.c brainfuck-jit.c
ELFS:= ${SOURCES:%.c=%}
CACHEGRINDS:=${SOURCES:%.c=cachegrind.%.txt}
MEMCHECKS:=${SOURCES:%.c=memcheck.%.xml}
PERFORMANCES:=${SOURCES:%c=performance.%.txt}
RUN:=${SOURCES:%.c=%-run}

DOCKER_IMAGE?=techzealot/ubuntu20.04-c

DOCKER_NAME?=brainfuck-c

MOUNT_DIR?=$(shell pwd)

SSHD_PORT?=2222

.PHONY: clean all valgrind support compare cachegrind memcheck performance run ${RUN} docker build-docker exec-docker

all: ${ELFS}

${ELFS}: %:%.c
	gcc $< -g -o $@

clean:
	-rm ${ELFS} commands.o brainfuck-jit-disas.txt commands.objdump cachegrind.* vgcore.* core* memcheck.*

run:${RUN}

${RUN}: %-run:%
	time=`time ./$< programs/sierpinski.bf` \
	echo $$time

cachegrind: ${CACHEGRINDS}

memcheck: ${MEMCHECKS}

performance: ${PERFORMANCES}

# 内存泄漏检查,use strict mode,interupt when error,output file
${MEMCHECKS}: memcheck.%.xml:%
	valgrind --leak-check=full --smc-check=all --error-exitcode=1 --xml-file=$@ --xml=yes ./$< programs/666.bf

# 内存泄漏检查,output file
${CACHEGRINDS}: cachegrind.%.txt:%
	valgrind --tool=cachegrind --branch-sim=yes --log-file=$@ ./$< programs/sierpinski.bf

support: commands.objdump brainfuck-jit-disas.txt

# 运行时间对比
compare: ${ELFS}
	# 使用 level=[0,1,2,3] program=$^ gcc `$$elf`.c -o$level -o $$elf
	# time ./$$elf programs/mandelbrot.bf
	# 收集数据 program:level:cost

commands.o: commands.asm
	nasm -felf64 commands.asm -o commands.o

# 生成所需指令集合的反汇编形式
commands.objdump: commands.o
	objdump -d commands.o > commands.objdump

# 生成jit代码的二进制形式和汇编形式
brainfuck-jit-disas.txt:brainfuck-jit
	gdb -q -x gdb.txt --args ./brainfuck-jit programs/666.bf
# CFLAGS get result from time
${PERFORMANCES}: performance.%.txt:%
	time=`time ./$< programs/sierpinski.bf` \
	echo $$time

# 伪目标如果相互依赖，依赖的目标每次都会执行
# use first non-root user,you can change to root by su root
exec-docker:
	docker exec -it --user 1000 ${DOCKER_NAME} bash

# we can debug in /home/deploy/projects ,and we mount the project in /mnt for cli user
# clion debug container
# https://blog.jetbrains.com/clion/2020/01/using-docker-with-clion/
# https://www.jetbrains.com/help/clion/clion-toolchains-in-docker.html
docker:
	-docker stop ${DOCKER_NAME}
	docker run --rm -d --cap-add sys_ptrace -p127.0.0.1:${SSHD_PORT}:22 --mount type=bind,source=${MOUNT_DIR},destination=/mnt --name ${DOCKER_NAME} ${DOCKER_IMAGE}

build-docker:
	docker build -t ${DOCKER_IMAGE} .