1. 机器码生成思路

   1.1 编写所有需要用的nasm汇编指令wenjian

   1.2 使用nasm生成64位目标文件

   1.3 使用objdump -d 反汇编出相应的16进制机器码存入数组即可
2. jit运行原理

   2.1 mmap + mprotect

   2.2 memalign + mprotect (推荐)

   2.3 汇编代码设计思路
   ```text

   ```
3. 查看生成的机器码和反汇编代码

   1.1 输出机器码的字节数

   假设length或pc=171,存储在char* code[]中

   1.2 gdb查看指定范围内存数据
    ```shell 
    gdb> x/($pc)xb code
    # 以16进制单字节方式查看code开始向后171个字节，用于查看生成的jit代码
    ```
   1.3 以汇编格式编码指定范围内存并显示(适用于查看生成的jit代码，可同时显示二进制和对应汇编代码，推荐使用)
   ```shell
   gdb > b 316
   gdb > disas /mr code,code+pc
   ```
4. Linux core dump开启与gdb调试

   4.1 关闭系统内存限制

    ```shell
    ulimit -c unlimited
    ```

   4.2 使用-g 参数开启调试信息并运行，异常后获取生成的coredump文件

   4.3 使用gdb调试(无需增加启动参数)
   ```shell 
   gdb brainfuck-jit core gdb >bt 或 where
   ```

5. 内存泄漏检查

   支持jit代码运行: --smc-check=all-non-file
   
   valgrind --leak-check=full --smc-check=all-non-file ./brainfuck-jit programs/mandelbrot.bf 
6. jz/jnz指令在汇编中为标签，在机器码中为4字节偏移地址