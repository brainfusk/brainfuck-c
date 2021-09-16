
bf.o:     file format elf64-x86-64


Disassembly of section .text:

0000000000000000 <.text>:
   0:	55                   	push   %rbp
   1:	48 89 ec             	mov    %rbp,%rsp
   4:	48 81 ec 00 00 01 00 	sub    $0x10000,%rsp
   b:	53                   	push   %rbx
   c:	41 54                	push   %r12
   e:	48 31 db             	xor    %rbx,%rbx
  11:	4c 8d a5 00 00 ff ff 	lea    -0x10000(%rbp),%r12
  18:	4c 89 e7             	mov    %r12,%rdi
  1b:	b9 00 00 01 00       	mov    $0x10000,%ecx
  20:	30 c0                	xor    %al,%al
  22:	f3 aa                	rep stos %al,%es:(%rdi)
  24:	66 8d 5b ff          	lea    -0x1(%rbx),%bx
  28:	66 8d 5b 01          	lea    0x1(%rbx),%bx
  2c:	41 80 04 1c 01       	addb   $0x1,(%r12,%rbx,1)
  31:	41 80 2c 1c 01       	subb   $0x1,(%r12,%rbx,1)
  36:	b8 01 00 00 00       	mov    $0x1,%eax
  3b:	48 89 c7             	mov    %rax,%rdi
  3e:	49 8d 34 1c          	lea    (%r12,%rbx,1),%rsi
  42:	48 89 c2             	mov    %rax,%rdx
  45:	0f 05                	syscall
  47:	41 c6 04 1c 00       	movb   $0x0,(%r12,%rbx,1)
  4c:	41 80 3c 1c 00       	cmpb   $0x0,(%r12,%rbx,1)
  51:	0f 84 fd ff ff ff    	je     0x54
  57:	41 80 3c 1c 00       	cmpb   $0x0,(%r12,%rbx,1)
  5c:	0f 85 fd ff ff ff    	jne    0x5f
  62:	41 5c                	pop    %r12
  64:	5b                   	pop    %rbx
  65:	c9                   	leaveq
  66:	c3                   	retq
