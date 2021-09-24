SOURCES:= brainfuck.c brainfuck-jit.c
ELFS:= ${SOURCES:%.c=%}
CACHEGRINDS:=${SOURCES:%.c=cachegrind.%.txt}
MEMCHECKS:=${SOURCES:%.c=memcheck.%.xml}
PERFORMANCES:=${SOURCES:%c=performance.%.txt}
RUN:=${SOURCES:%.c=%-run}
.PHONY: clean all valgrind support compare cachegrind memcheck performance run ${RUN}

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