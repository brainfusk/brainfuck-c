//
// Created by techzealot on 2021/6/25.
//

#include <stdio.h>
#include <sys/fcntl.h>
#include <stdlib.h>

#define MAX_STACK 1000

void prepareJumpTable(char *program, size_t program_size, char **jumpTable) {
    size_t stack[MAX_STACK] = {0};
    size_t *sp = stack;
    char *ptr = program;
    while (ptr < (program + program_size)) {
        if (*ptr == '[') {
            *sp = ptr - program;
            ++sp;
        }
        if (*ptr == ']') {
            jumpTable[ptr - program] = program + *(sp - 1);
            jumpTable[*(sp - 1)] = ptr;
            sp--;
        }
        ptr++;
    }
    if (sp != stack) {
        perror("stack not balanced");
    }
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        perror("must input a bf file");
        exit(-1);
    }
    char program[50000], memory[30000];
    //存储跳转信息
    char *jumpTable[50000];
    char *ip = program;
    char *ptr = memory;
    char *filename = argv[1];
    FILE *file = fopen(filename, "rb");
    if (file == NULL) {
        printf("error open file %s", filename);
        exit(-1);
    }
    size_t read;
    size_t program_size = 0;
    do {
        read = fread(program + program_size, 1, 1024, file);
        program_size += read;
    } while (read == 1024);
    if (ferror(file)) {
        printf("error reading file %s", filename);
        exit(-1);
    }
    fclose(file);
    prepareJumpTable(program, program_size, jumpTable);
    while (ip < (program + program_size)) {
        switch (*ip) {
            case '+':
                (*ptr)++;
                break;
            case '-':
                (*ptr)--;
                break;
            case '>':
                ptr++;
                break;
            case '<':
                ptr--;
                break;
            case '.':
                putchar(*ptr);
                fflush(stdout);
                break;
            case ',':
                *ptr = getchar();
                if (*ptr == EOF) {
                    exit(0);
                }
                break;
            case '[':
                if (!*ptr) {
                    ip = jumpTable[ip - program];
                }
                break;
            case ']':
                if (*ptr) {
                    ip = jumpTable[ip - program];
                }
                break;
                //ignore unrecognized token
        }
        ip++;
    }
    return 0;
}
