//
// Created by techzealot on 2021/9/15.
//


#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <malloc.h>
#include <string.h>
#include <sys/mman.h>

#define MAX_STACK 1000

#define emit(x) code[pc++] =x

#define die(...) do { fprintf(stderr, __VA_ARGS__); fputc('\n', stderr); exit(EXIT_FAILURE); } while (0)


int debug(){
    return 1;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        die("must input a bf file");
    }
    char *filename = argv[1];
    FILE *file = fopen(filename, "rb");
    if (file == NULL) {
        die("error open file %s", filename);
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
        die("error reading file %s", filename);
        exit(-1);
    }
    fclose(file);
    //prepare jit code memory
    size_t pageSize = (size_t) sysconf(_SC_PAGESIZE);
    size_t code_len = pageSize;
    char *code = memalign(pageSize, code_len);
    if (code == NULL) {
        die("Error allocating aligned memory: %s.", strerror(errno));
    }
    //prepare stack for asm jump
    size_t pc = 0;
    size_t stack[MAX_STACK];
    size_t sp = 0;
    //保存函数调用栈
    //push rbp
    emit(0x55);
    //mov rbp,rsp
    emit(0x48);
    emit(0x89);
    emit(0xe5);
    //栈上开辟空间作为bf的data buffer
    //sub rsp,0x10000
    emit(0x48);
    emit(0x81);
    emit(0xec);
    emit(0x00);
    emit(0x00);
    emit(0x01);
    emit(0x00);
    //push rbx
    emit(0x53);
    //push r12
    emit(0x41);
    emit(0x54);
    //use rbx as data pointer offset
    //set rbx 0
    //xor rbx,rbx
    emit(0x48);
    emit(0x31);
    emit(0xdb);
    //use r12 as data pointer
    //lea r12,[rbp-0x10000]
    emit(0x4c);
    emit(0x8d);
    emit(0xa5);
    emit(0x00);
    emit(0x00);
    emit(0xff);
    emit(0xff);
    //init data buffer with zeros
    //rep stosb就是从EDI所指的内存开始，将连续的ECX个字节写成AL的内容，多用于清零
    // mov rdi,r12
    emit(0x4c);
    emit(0x89);
    emit(0xe7);
    // mov rcx,0x10000
    emit(0xb9);
    emit(0x00);
    emit(0x00);
    emit(0x01);
    emit(0x00);
    //set al to 0
    // xor al,al
    emit(0x30);
    emit(0xc0);
    // rep stosb
    emit(0xf3);
    emit(0xaa);
    //can skip cmp ,skip cmp when add/sub is the previous instruction;add/sub will set zf,for optimizing
    int need_cmp_command = 1;
    for (size_t i = 0; i < program_size; i++) {
        // if less than 100 bytes remain in code buffer, double it
        if (code_len - pc < 100) {
            char *new_code = memalign(pageSize, code_len * 2);
            if (new_code == NULL) {
                die("Error allocating aligned memory: %s.", strerror(errno));
            }
            memcpy(new_code, code, code_len);
            code_len *= 2;
            free(code);
            code = new_code;
        }
        int amount = 0;
        switch (program[i]) {
            case '>':
                //-128<= cell <=127
                amount = 1;
                while (i + 1 < program_size && program[i + 1] == '>' && amount < 127) {
                    amount++;
                    i++;
                }
                //amount ~[-128,127]
                //lea bx,[rbx+amount]
                emit(0x66);
                emit(0x8d);
                emit(0x5b);
                emit(amount);
                //need cmp to set zf
                need_cmp_command = 1;
                break;
            case '<':
                amount = -1;
                while (i + 1 < program_size && program[i + 1] == '<' && amount > -128) {
                    amount--;
                    i++;
                }
                //amount ~[-128,127]
                //lea bx,[rbx+amount]
                emit(0x66);
                emit(0x8d);
                emit(0x5b);
                emit(amount);
                //need cmp to set zf
                need_cmp_command = 1;
                break;
            case '+':
                amount = 1;
                while (i + 1 < program_size && program[i + 1] == '+' && amount < 255) {
                    amount++;
                    i++;
                }
                //add BYTE [r12+rbx],amount
                emit(0x41);
                emit(0x80);
                emit(0x04);
                emit(0x1c);
                emit(amount);
                //don't need cmp to set zf
                need_cmp_command = 0;
                break;
            case '-':
                amount = 1;
                while (i + 1 < program_size && program[i + 1] == '-' && amount < 255) {
                    amount++;
                    i++;
                }
                // sub BYTE [r12+rbx],amount
                emit(0x41);
                emit(0x80);
                emit(0x2c);
                emit(0x1c);
                emit(amount);
                //don't need cmp to set zf
                need_cmp_command = 0;
                break;
            case '.':
                //call sys_write
                /*
                rax, 临时寄存器. 当我们调用 syscall 时, rax 必须包含 syscall 号码
                rdi, 用于将第 1 个参数传递给函数
                rsi, 用于将第 2 个参数传递给函数
                rdx, 用于将第 3 个参数传递给函数
                sys_write 的定义:
                size_t sys_write(unsigned int fd, const char * buf, size_t count);
                它具有3个参数:
                fd, 文件描述符. 对于 stdin，stdout 和 stderr 来说，其值分别为 0, 1 和 2
                buf, 指向字符数组
                count, 指定要写入的字节数
                */
                //syscall
                //mov rax 1
                emit(0xb8);
                emit(0x01);
                emit(0x00);
                emit(0x00);
                emit(0x00);
                //fd
                // mov rdi, rax
                emit(0x48);
                emit(0x89);
                emit(0xc7);
                //buf
                // lea rsi,[r12+rbx]
                emit(0x49);
                emit(0x8d);
                emit(0x34);
                emit(0x1c);
                //count
                // mov rdx,rax
                emit(0x48);
                emit(0x89);
                emit(0xc2);
                // syscall
                emit(0x0f);
                emit(0x05);
                break;
            case ',':
                //ignore ,
                break;
            case '[':
                if (i < program_size - 2 && (program[i + 1] == '+' || program[i + 1] == '-') && program[i + 2] == ']') {
                    //[+] [-] set cell to 0
                    //mov BYTE [r12+rbx],0x0
                    emit(0x41);
                    emit(0xc6);
                    emit(0x04);
                    emit(0x1c);
                    emit(0x00);
                    i += 2;
                } else {
                    if (need_cmp_command) {
                        // cmp BYTE [r12+rbx],0x0
                        emit(0x41);
                        emit(0x80);
                        emit(0x3c);
                        emit(0x1c);
                        emit(0x00);
                        need_cmp_command = 0;
                    }
                    //jz loop_end(4byte)(偏移地址)
                    emit(0x74);
                    //暂时空出跳转地址
                    pc += 4;
                    //存储jz指令的结束位置即"["的下一条指令开始
                    stack[sp++] = pc;
                    if (sp == MAX_STACK) {
                        die("Maximum stack depth exceeded.");
                    }
                }
                break;
            case ']':
                if (need_cmp_command) {
                    // cmp BYTE [r12+rbx],0x0
                    emit(0x41);
                    emit(0x80);
                    emit(0x3c);
                    emit(0x1c);
                    emit(0x00);
                    need_cmp_command = 0;
                }
                //jnz loop_start(偏移地址)
                emit(0x75);
                //keep jump address
                pc += 4;
                if (sp == 0) {
                    die("Unexpected loop end.");
                }
                size_t loop_start = stack[--sp];
                //set ] loop_start offset
                *(int *) (code + pc - 4) = (int) (loop_start - pc);
                *(int *) (code + loop_start - 4) = (int) (pc - loop_start);
                //set matched [ loop_end offset
                break;
            default:
                //ignore unrecognized token
                break;
        }
    }
    if (sp != 0) {
        die("Unterminated loop.");
    }

    // pop r12
    emit(0x41);
    emit(0x5c);
    // pop rbx
    emit(0x5b);
    // leave
    emit(0xc9);
    // ret
    emit(0xc3);

    if (mprotect(code, code_len, PROT_EXEC) == -1) {
        die("Error making program memory executable: %s.", strerror(errno));
    }
    //gdb debug断点使用,b debug,避免使用代码行数这种不可扩展的方式设置断点
    debug();

    ((void (*)()) code)();

    free(code);

    free(program);

    return EXIT_SUCCESS;
}