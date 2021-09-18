SOURCES:= brainfuck.c brainfuck-jit.c
ELFS:= ${SOURCES:%.c=%}
.PHONY: clean all valgrind support compare

all: ${ELFS}

${ELFS}: %:%.c
	gcc $< -g -o $@

clean:
	-rm ${ELFS} commands.o brainfuck-jit-disas.txt commands.objdump

run: brainfuck-jit
	time ./brainfuck-jit programs/mandelbrot.bf

# 内存泄漏检查
valgrind: ${ELFS}
	@for elf in $^;  \
	do \
	valgrind --leak-check=full --smc-check=all-non-file ./$$elf programs/666.bf ;\
	done

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
	objdump -d commands.o >> commands.objdump

# 生成jit代码的二进制形式和汇编形式
brainfuck-jit-disas.txt:brainfuck-jit
	gdb -x gdb.txt --args ./brainfuck-jit programs/666.bf