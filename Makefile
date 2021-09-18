SOURCES:= brainfuck.c brainfuck-jit.c
ELFS:= ${SOURCES:%.c=%}
.PHONY: clean all

all: ${ELFS}

${ELFS}: %:%.c
	gcc $< -g -o $@

clean:
	rm ${ELFS}

run: brainfuck-jit
	./brainfuck-jit programs/mandelbrot.bf

valgrind: ${ELFS}
	valgrind --leak-check=full --smc-check=all-non-file ./$@ programs/666.bf

commands.asm: commands.o
	nasm -felf64 commands.asm -o commands.o

commands.dump: commands.o
	objdump -d commands.o >> commands.dump

brainfuck-jit.txt:brainfuck-jit
	gdb -x gdb.txt --args ./brainfuck-jit programs/666.bf