1. 使用
   ```shell
   git clone --recurse-submodules https://github.com/brainfusk/brainfuck-c.git
   make build-docker
   make docker
   # 进入docker
   make exec-docker
   # 可执行各种make目标进行测试
   make support && make cachegrind && make run
   ```
2. 机器码生成思路

   1.1 编写所有需要用到的nasm汇编指令的组合版，仅用作反汇编获取对应指令的二进制形式，避免查汇编指令手册

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

   方法一:

   1.1 找到机器码存储位置

   对于666.bf程序，二级制机器码存储在char* code[],length=171中

   1.2 gdb查看指定范围内存数据
    ```shell 
   # 以16进制单字节方式查看code开始向后171个字节，用于查看生成的jit代码
    gdb> x/171xb code
    ```
   方法二(推荐):

   以汇编格式编码指定范围内存并显示(适用于查看生成的jit代码，可同时显示二进制和对应汇编代码)
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

   ```shell
   valgrind --leak-check=full --smc-check=all ./brainfuck-jit programs/mandelbrot.bf 
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
   tree -I ".idea|cmake-*|LuaJIT|*.bf"
   # memcheck*.xml为valgind内存泄漏检测结果文件 (make memcheck)
   # cachegrind.* 为valgind CPU缓存检测和分支预测输出(make cachegrind)
   ├── CMakeLists.txt # cmake配置文件，clion调试使用
   ├── Dockerfile # 用于生成开发，远程调试的容器环境
   ├── LICENSE
   ├── Makefile # 编译 运行 内存检查 生成jit辅助信息
   ├── README.MD
   ├── brainfuck-dynasm.dasc # 使用dynasm编写的jit解释器
   ├── brainfuck-jit-disas.txt # 使用gdb获取的生成的jit代码的二进制和对应的汇编格式代码
   ├── brainfuck-jit.c # 手写的jit解释器
   ├── brainfuck-onepass.c # 单趟遍历实现的解释器
   ├── brainfuck.c # twopass解释器
   ├── commands.asm # 生成jit所需汇编指令列表，用于获取汇编指令的16进制格式
   ├── commands.objdump # commands.asm经过nasm汇编后的反汇编格式，方便对照编写相关指令
   ├── gdb.txt # 用于获取jit代码的二进制和汇编形式的gdb命令文件
   └── programs # 常见brainfuck程序集合
   ```
   
9. 性能对比

   运行programs/mandelbrot.bf性能对比

     |         程序         | 优化 | 耗时/s |
     | :------------------: | :--: | :----: |
     |      brainfuck       | -o0  |   77   |
     |      brainfuck       | -o1  |   51   |
     |      brainfuck       | -o2  | 38.52  |
     |      brainfuck       | -o3  | 38.11  |
     |  brainfuck-onepass   | -o0  |   73   |
     |  brainfuck-onepass   | -o1  | 49.69  |
     |  brainfuck-onepass   | -o2  | 42.45  |
     |  brainfuck-onepass   | -o3  | 44.17  |
     |    brainfuck-jit     | -o0  |  1.28  |
     |    brainfuck-jit     | -o1  |  1.15  |
     |    brainfuck-jit     | -o2  |  1.14  |
     |    brainfuck-jit     | -o3  |  1.31  |
     | brainfuck-dynasm-jit | -o0  |  1.51  |
     | brainfuck-dynasm-jit | -o1  |  1.51  |
     | brainfuck-dynasm-jit | -o2  |  1.52  |
     | brainfuck-dynasm-jit | -o3  |  1.52  |


11. 参考列表

    https://github.com/prplz/brainfuck-jit

12. 跳转指令的区别:

    10.1 指令0x74 0x75 与 0x0f84 0x0f85的区别:

    操作数大小范围不同

    0x74   JE rel8(8位有符号数)

    0x0f84 JE rel32(32位有符号数)
13. 性能分析

    12.1 jit性能更好原因分析

    指令更少
14. git子模块使用

    ```shell
    # 添加子模块
    git submodule add https://github.com/LuaJIT/LuaJIT.git
    # 同步子模块
    git submodule update --remote
    # 设置子模块同步的分支 会在.gitmodules文件新增'branch = v2.1'
    git config -f .gitmodules submodule.LuaJIT.branch v2.1
    ```
