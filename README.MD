1. 使用
   ```shell
   git clone git@github.com:brainfusk/brainfuck-c.git --recursive
   make build-docker
   make docker
   # 进入docker
   make exec-docker
   # 可执行各种make目标进行测试
   make support && make cachegrind && make run
   ```
2. 机器码生成思路

   1.1 编写所有需要用的nasm汇编代码

   1.2 使用nasm生成64位目标文件(目标文件会被部分优化，寄存器可能使用低位，如rax->eax)

   1.3 使用objdump -d 反汇编出相应的16进制机器码，参照反汇编代码生成jit代码存入数组即可
   
3. jit运行原理

   2.1 mmap + mprotect

   2.2 memalign + mprotect (推荐)

   2.3 汇编代码设计思路
   ```text
   使用sub rsp,0x10000保留栈空间作为数据区
   r12用作数据区起始位置指针
   rbx作为数据指针相对起始位置的偏移量
   jz/jnz的跳转地址使用栈结构进行计算保存，栈中存放各个跳转位置的偏移量，jz/jnz的实际参数为跳转地址与当前位置的偏移量
   ```
   
4. 查看生成的机器码和反汇编代码

   1.1 输出机器码的字节数

   假设length或pc=171,存储在char* code[]中

   1.2 gdb查看指定范围内存数据
    ```shell 
   # 以16进制单字节方式查看code开始向后171个字节，用于查看生成的jit代码
    gdb> x/171xb code
    ```
   1.3 以汇编格式编码指定范围内存并显示(适用于查看生成的jit代码，可同时显示二进制和对应汇编代码，推荐使用)
   ```shell
   gdb > b debug
   gdb > finish
   gdb > disas /mr code,code+pc
   ```
   
5. Linux core dump开启与gdb调试

   4.1 关闭系统内存限制

    ```shell
    ulimit -c unlimited
    ```

   4.2 使用-g 参数开启调试信息并运行，异常后获取生成的coredump文件

   4.3 使用gdb调试(无需增加启动参数)
   ```shell 
   > gdb brainfuck-jit core 
   gdb> bt 或 where
   # 若进入无法定位源码的位置,如jit代码内部,则可反汇编出附近代码配合brainfuck-jit-disas.txt中的汇编代码进行分析
   gdb> disas $pc,+20
   ```

6. 内存泄漏检查

   支持jit代码运行: --smc-check=all-non-file
   ```shell
   valgrind --leak-check=full --smc-check=all-non-file ./brainfuck-jit programs/mandelbrot.bf 
   ```
   
7. jz/jnz指令在汇编中为标签，在机器码中为偏移地址(注意跳转指令的选择0x0f84 0x0f85与0x74 0x75的区别)

8. 输出jit辅助信息

   进入docker后执行以下命令生成辅助文件
   ```shell
   make clean
   make support
   ```
   文件清单：
   ```shell
   # 生成的jit代码的二进制和对应的汇编格式代码，使用gdb获取
   brainfuck-jit-disas.txt
   # 生成jit所需汇编指令列表，用于获取汇编指令的16进制格式
   commands.asm
   # commands.asm经过nasm汇编后的反汇编格式，方便对照编写相关指令
   commands.objdump
   # 用于获取jit代码的二进制和汇编形式的gdb命令文件
   gdb.txt
   # 编译 运行 内存检查 生成jit辅助信息
   Makefile
   # 常见brainfuck程序集合
   programs/
   ```
   
9. 性能对比

   运行programs/mandelbrot.bf性能对比

    |     程序      |       优化       | 耗时/s |
    | :-----------: | :--------------: | :----: |
    |   brainfuck   |       -o0        |        |
    |   brainfuck   |       -o1        |        |
    |   brainfuck   |       -o2        |        |
    |   brainfuck   |       -o3        |        |
    | brainfuck-jit | peephole/jit/-o0 |        |
    | brainfuck-jit |       -o1        |        |
    | brainfuck-jit |       -o2        |        |
    | brainfuck-jit |       -o3        |        |

10. 参考列表

    https://github.com/prplz/brainfuck-jit

11. 跳转指令的区别:

    10.1 指令0x74 0x75 与 0x0f84 0x0f85的区别:

    操作数大小范围不同

    0x74   JE rel8(8位有符号数)

    0x0f84 JE rel32(32位有符号数)
