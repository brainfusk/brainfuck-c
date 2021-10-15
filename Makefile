SOURCES := brainfuck.c brainfuck-jit.c brainfuck-dynasm-jit.c brainfuck-onepass.c
ELFS := ${SOURCES:%.c=%}
OPT ?= -O3
LEVELS ?= -O0 -O1 -O2 -O3
CACHEGRINDS := ${SOURCES:%.c=cachegrind.%${OPT}.txt}
MEMCHECKS := ${SOURCES:%.c=memcheck.%.xml}
PERFORMANCE_FILE=performance${OPT}.txt

DOCKER_IMAGE ?= techzealot/ubuntu20.04-c

DOCKER_NAME ?= brainfuck-c

MOUNT_DIR ?= $(shell pwd)

SSHD_PORT ?= 2222

# comment this to test programs/mandelbrot.bf (notice: non jit version is very slow)
BF_PROGRAM := programs/sierpinski.bf

BF_PROGRAM ?= programs/mandelbrot.bf

.PHONY: clean all valgrind support cachegrind memcheck run docker build-docker exec-docker sierpinski mandelbrot

all: ${ELFS}

${ELFS}: %:%.c
	gcc $< ${OPT} -g -o $@

brainfuck-dynasm-jit.c: brainfuck-dynasm.dasc
	git submodule update
	luajit LuaJIT/dynasm/dynasm.lua -o $@ -D X64 $<

clean:
	-rm ${ELFS} commands.o brainfuck-jit-disas.txt commands.objdump cachegrind.* vgcore.* core* memcheck.* brainfuck-dynasm-jit.c performance-*.txt

clean-elf:
	-rm ${ELFS}

run:${ELFS}
	-rm ${PERFORMANCE_FILE}
	for elf in $^;  \
	do \
	echo `date` >> ${PERFORMANCE_FILE}; \
	echo $$elf >> ${PERFORMANCE_FILE}; \
	(time ./$$elf ${BF_PROGRAM}) 2>> ${PERFORMANCE_FILE}; \
	echo "\n" >> ${PERFORMANCE_FILE}; \
	done

mandelbrot sierpinski:${ELFS}
	for level in ${LEVELS}; \
	do \
	echo "start run $< by opt level $$level" \
  	make clean-elf; \
    make OPT=$$level BF_PROGRAM=programs/$@.bf run; \
	done

cachegrind: ${CACHEGRINDS}

memcheck: ${MEMCHECKS}

performance: ${PERFORMANCES}

# 内存泄漏检查,use strict mode,interupt when error,output file
${MEMCHECKS}: memcheck.%.xml:%
	valgrind --leak-check=full --smc-check=all --error-exitcode=1 --xml-file=$@ --xml=yes ./$< ${BF_PROGRAM}

# cpu多级缓存及分支预测模拟分析
${CACHEGRINDS}: cachegrind.%${OPT}.txt:%
	valgrind --tool=cachegrind --branch-sim=yes --log-file=$@ ./$< ${BF_PROGRAM}

support: commands.objdump brainfuck-jit-disas.txt

commands.o: commands.asm
	nasm -felf64 commands.asm -o commands.o

# 生成所需指令集合的反汇编形式
commands.objdump: commands.o
	objdump -d commands.o > commands.objdump

# 生成jit代码的二进制形式和汇编形式,使用programs/666.bf便于分析问题
brainfuck-jit-disas.txt:brainfuck-jit
	gdb -q -x gdb.txt --args ./brainfuck-jit programs/666.bf

# 伪目标如果相互依赖，依赖的目标每次都会执行
# use first non-root user,you can change to root by su root
# set exec workdir to mount path /mnt
exec-docker:
	docker exec -it --user 1000 -w /mnt ${DOCKER_NAME} bash

# we can debug in /home/deploy/projects ,and we mount the project in /mnt for cli user
# clion debug container
# https://blog.jetbrains.com/clion/2020/01/using-docker-with-clion/
# https://www.jetbrains.com/help/clion/clion-toolchains-in-docker.html
docker:
	-docker stop ${DOCKER_NAME}
	docker run --rm -d --cap-add=SYS_PTRACE --security-opt seccomp=unconfined -p127.0.0.1:${SSHD_PORT}:22 --mount type=bind,source=${MOUNT_DIR},destination=/mnt --name ${DOCKER_NAME} ${DOCKER_IMAGE}

build-docker:
	docker build -t ${DOCKER_IMAGE} .