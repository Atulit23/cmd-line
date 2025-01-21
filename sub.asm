section .data
    string db "hello"
    start equ 1
    len equ $ - string

section .bss    
    subs resb 128 

section .text
    global _start

_start:
    mov esi, start
    xor ecx, ecx

substring:
    cmp esi, len
    jge loop_end

    mov ebx, [string + esi]
    mov [subs + ecx], ebx

    inc esi 
    inc ecx

    jmp substring

loop_end:
    mov eax, 4
    mov ebx, 1
    mov ecx, subs
    mov edx, len - start
    int 0x80 

    mov eax, 1
    xor ebx, ebx
    int 0x80