section .text
;prepare stack
push rbp
mov rbp,rsp
;reserve bf data buffer
sub rsp,0x10000
push rbx
push r12
;rbx -> data pointer offset
xor rbx,rbx
; r12 -> data start
lea r12,[rbp-0x10000]
;fill data buffer with 0
mov rdi,r12
mov rcx,0x10000
xor al,al
rep stosb
; "<"
lea bx,[rbx-0x1]
; ">"
lea bx,[rbx+0x1]
; "+"
add BYTE [r12+rbx],0x1
; "-"
sub BYTE [r12+rbx],0x1
; "."
mov rax, 1
mov rdi, rax
lea rsi,[r12+rbx]
mov rdx,rax
syscall
; "["
; [+] [-] set 0
mov BYTE [r12+rbx],0x0
cmp BYTE [r12+rbx],0x0
;jz loop_end
jz loop_end
loop_start:
; "]"
cmp BYTE [r12+rbx],0x0
;填充127个NOP，避免生成短跳转的jz/jnz
times 127 xchg eax, eax
;jnz loop_start
jnz loop_start
loop_end:
pop r12
pop rbx
leave
ret