SOURCES:= brainfuck.c brainfuck-jit.c
ELFS:= ${SOURCES:%.c=%}
.PHONY: clean all valgrind support

all: ${ELFS}

${ELFS}: %:%.c
	gcc $< -g -o $@

clean:
	-rm ${ELFS} commands.o brainfuck-jit-disas.txt commands.objdump

run: brainfuck-jit
	time ./brainfuck-jit programs/mandelbrot.bf

valgrind: ${ELFS}
	@for elf in $^;  \
	do \
	valgrind --leak-check=full --smc-check=all-non-file ./$$elf programs/666.bf ;\
	done

support: commands.objdump brainfuck-jit-disas.txt

commands.o: commands.asm
	nasm -felf64 commands.asm -o commands.o

commands.objdump: commands.o
	objdump -d commands.o >> commands.objdump

brainfuck-jit-disas.txt:brainfuck-jit
	gdb -x gdb.txt --args ./brainfuck-jit programs/666.bf