//
// Created by techzealot on 2021/9/29.
// copy from https://corsix.github.io/dynasm-doc/tutorial.html
// just one pass for the entire loop

#include <stdio.h>
#include <stdlib.h>

#define TAPE_SIZE 30000
#define MAX_NESTING 100

typedef struct bf_state
{
    unsigned char* tape;
    //函数指针 用来实现面向对象的封装
    unsigned char (*get_ch)(struct bf_state*);
    void (*put_ch)(struct bf_state*, unsigned char);
} bf_state_t;

// %m.ns：输出占m列，但只取字符串中左端n个字符。这n个字符输出在m列的右侧，左补空格
#define bad_program(s) exit(fprintf(stderr, "bad program near %.16s: %s\n", program, s))

static void bf_interpret(const char* program, bf_state_t* state)
{
    //模拟栈结构，用来保存跳转信息
    const char* loops[MAX_NESTING];
    //stack index
    int nloops = 0;
    //是否可以跳过后续的n个非'[',']'指令，用于实现jz，即当前cell==0时跳过后续所有指令直到遇到匹配的']'，当前cell!=0时，直接执行下一条指令，可实现one-pass;
    //如果 使用jz(cell==0),jump loop end模式,需要提前知道跳转地址，必须two-pass
    //当pc-> '[',cell==0,每遇到一个[,nskip++,遇到],nskip--;当nskip==0时，说明已经跳过匹配的中括号中间的所有指令
    int nskip = 0;
    unsigned char* tape_begin = state->tape - 1;
    unsigned char* ptr = state->tape;
    unsigned char* tape_end = state->tape + TAPE_SIZE - 1;
    //counter
    int n;
    for(;;) {
        switch(*program++) {
            case '<':
                for(n = 1; *program == '<'; ++n, ++program);
                if(!nskip) {
                    ptr -= n;
                    while(ptr <= tape_begin)
                        ptr += TAPE_SIZE;
                }
                break;
            case '>':
                for(n = 1; *program == '>'; ++n, ++program);
                if(!nskip) {
                    ptr += n;
                    while(ptr > tape_end)
                        ptr -= TAPE_SIZE;
                }
                break;
            case '+':
                for(n = 1; *program == '+'; ++n, ++program);
                if(!nskip)
                    *ptr += n;
                break;
            case '-':
                for(n = 1; *program == '-'; ++n, ++program);
                if(!nskip)
                    *ptr -= n;
                break;
            case ',':
                if(!nskip)
                    *ptr = state->get_ch(state);
                break;
            case '.':
                if(!nskip)
                    state->put_ch(state, *ptr);
                break;
            case '[':
                if(nloops == MAX_NESTING)
                    bad_program("Nesting too deep");
                //此时program指向'['下一条指令,而非'[';
                // 如果jumpStack存的是当前指令位置,则每次遇到[执行push,遇到]执行pop;如果jumpStack存的是下一条指令位置,则每次遇到[执行push,遇到]cell==0时执行pop;
                loops[nloops++] = program;
                if(!*ptr)
                    ++nskip;
                break;
            case ']':
                if(nloops == 0)
                    bad_program("] without matching [");
                if(*ptr)
                    program = loops[nloops-1];
                else
                    --nloops;
                if(nskip)
                    --nskip;
                break;
            case 0:
                if(nloops != 0)
                    program = "<EOF>", bad_program("[ without matching ]");
                return;
        }
    }
}

static void bf_putchar(bf_state_t* s, unsigned char c)
{
    putchar((int)c);
}

static unsigned char bf_getchar(bf_state_t* s)
{
    return (unsigned char)getchar();
}

static void bf_run(const char* program)
{
    bf_state_t state;
    unsigned char tape[TAPE_SIZE] = {0};
    state.tape = tape;
    state.get_ch = bf_getchar;
    state.put_ch = bf_putchar;
    bf_interpret(program, &state);
}

int main(int argc, char** argv)
{
    if(argc == 2) {
        long sz;
        char* program;
        FILE* f = fopen(argv[1], "r");
        if(!f) {
            fprintf(stderr, "Cannot open %s\n", argv[1]);
            return 1;
        }
        //移动文件的读写指针到指定的位置,设置读写指针至文件末尾
        fseek(f, 0, SEEK_END);
        //获取文件读写指针的当前位置
        sz = ftell(f);
        program = (char*)malloc(sz + 1);
        //设置读写指针至文件首
        fseek(f, 0, SEEK_SET);
        //读取输入文件所有字节并将最后一个字节设置为0，作为终止标记
        program[fread(program, 1, sz, f)] = 0;
        fclose(f);
        bf_run(program);
        free(program);
        return 0;
    } else {
        fprintf(stderr, "Usage: %s INFILE.bf\n", argv[0]);
        return 1;
    }
}