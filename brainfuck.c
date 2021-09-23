//
// Created by techzealot on 2021/6/25.
//

#include <stdio.h>
#include <sys/fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#define MAX_STACK 1000

#define MAX_PROGRAM_SIZE 50000

#define die(...) do { fprintf(stderr, __VA_ARGS__); fputc('\n', stderr); exit(EXIT_FAILURE); } while (0)

void prepareJumpTable(char *program, size_t program_size, char **jumpTable) {
    size_t stack[MAX_STACK] = {0};
    size_t sp = 0;
    char *ptr = program;
    while (ptr < (program + program_size)) {
        if (*ptr == '[') {
            stack[sp++] = ptr - program;
        }
        if (*ptr == ']') {
            size_t loop_start = stack[--sp];
            jumpTable[ptr - program] = program + loop_start;
            jumpTable[loop_start] = ptr;
        }
        ptr++;
    }
    if (sp != 0) {
        perror("stack not balanced");
    }
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        perror("must input a bf file");
        exit(-1);
    }
    char memory[30000] = {0};
    char *filename = argv[1];
    FILE *file = fopen(filename, "rb");
    if (file == NULL) {
        printf("error open file %s", filename);
        exit(-1);
    }
    char *program = NULL;
    size_t read;
    size_t program_size = 0;
    do {
        program = program ? realloc(program, program_size + 1024) : malloc(1024);
        if (program == NULL) {
            die("Error allocating memory: %s.", strerror(errno));
        }
        read = fread(program + program_size, 1, 1024, file);
        program_size += read;
    } while (read == 1024);
    if (ferror(file)) {
        printf("error reading file %s", filename);
        exit(-1);
    }
    fclose(file);
    char *ip = program;
    char *ptr = memory;
    //存储跳转信息
    char *jumpTable[MAX_PROGRAM_SIZE] = {0};
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
    free(program);
    return 0;
}
