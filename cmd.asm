section .data
    newline db 0xA
    prompt db "shell> ", 0
    len equ $ - prompt
    
    ls db "ls", 0
    command db "/usr/bin/ls", 0
    
    pwd db "pwd", 0
    command1 db "/usr/bin/pwd", 0
    
    touch db "touch", 0
    mode equ 0644    ; File permissions (rw-r--r--)
    
    echo db "echo", 0
    cat  db "cat",  0

    exits db "exit", 0
    
    current equ 5
    
    args_ls:
        dd command
        dd 0
        
    args_pwd:
        dd command1
        dd 0
        
    unknown_msg db "Command not found", 0xA
    unknown_len equ $ - unknown_msg
    
    empty_environ dd 0
    error_msg db "Error creating file", 0xA
    error_len equ $ - error_msg

section .bss
    input resb 128
    subs resb 128
    buffer resb 4096 
    fd resd 1                   

section .text
    global _start

_start:
main:
    ; Print prompt
    mov eax, 4
    mov ebx, 1
    mov ecx, prompt
    mov edx, len
    int 0x80
    
    ; Read input
    mov eax, 3
    mov ebx, 0
    mov ecx, input
    mov edx, 128
    int 0x80
    
    ; Remove newline and null-terminate
    dec eax
    mov byte [input + eax], 0
    
    ; Compare with "ls"
    mov esi, input
    mov edi, ls
    mov ecx, 2
    repe cmpsb
    je execute_ls
    
    ; Compare with "pwd"
    mov esi, input
    mov edi, pwd
    mov ecx, 3
    repe cmpsb
    je execute_pwd
    
    ; Compare with "echo"
    mov esi, input
    mov edi, echo
    mov ecx, 4
    repe cmpsb
    je execute_echo
    
    ; exit
    mov esi, input
    mov edi, exits
    mov ecx, 5
    repe cmpsb
    je exit
    
    ; touch
    mov esi, input
    mov edi, touch
    mov ecx, 5
    repe cmpsb
    je execute_touch

    ;cat
    mov esi, input
    mov edi, cat
    mov ecx, 3
    repe cmpsb
    je execute_cat
    
    ; Unknown command
    mov eax, 4
    mov ebx, 1
    mov ecx, unknown_msg
    mov edx, unknown_len
    int 0x80
    
    jmp main

execute_echo:
    mov esi, 5
    xor ecx, ecx
    
    ; Clear subs buffer
    mov edi, subs
    mov ecx, 128
    xor al, al
    rep stosb
    
    xor ecx, ecx  ; Reset ECX for the substring loop

substring:
    cmp byte [input + esi], 0
    je sub_end
    mov bl, [input + esi]    
    mov [subs + ecx], bl
    inc esi
    inc ecx
    jmp substring

sub_end:
    mov edx, ecx   
    mov eax, 4
    mov ebx, 1
    mov ecx, subs  
    int 0x80
    
    ; Print newline
    mov eax, 4
    mov ebx, 1
    mov ecx, newline
    mov edx, 1
    int 0x80
    
    jmp main

execute_cat:
    mov esi, 4
    xor ecx, ecx
    
    ; Clear subs buffer
    push edi
    mov edi, subs
    mov ecx, 128
    xor al, al
    rep stosb
    pop edi
    
    ; Get filename
    xor ecx, ecx

get_filename_cat:
    cmp byte [input + esi], 0
    je add_null_cat
    mov bl, [input + esi]
    mov [subs + ecx], bl
    inc esi
    inc ecx
    jmp get_filename_cat

add_null_cat:
    mov byte [subs + ecx], 0  

    mov eax, 5
    mov ebx, subs
    mov ecx, 0  ; O_RDONLY
    int 0x80

    cmp eax, 0
    jl error

    mov [fd], eax
    jmp read_loop

read_loop:
    mov eax, 3  ; syscall number for read                 
    mov ebx, [fd]               
    mov ecx, buffer             
    mov edx, 4096                
    int 0x80                     

    ; Check read result
    cmp eax, 0                   
    jle close_file

    ; Write to stdout using sys_write
    mov edx, eax                
    mov eax, 4                   
    mov ebx, 1                   
    mov ecx, buffer              
    int 0x80                     

    jmp read_loop

close_file:
    mov eax, 6                 
    mov ebx, [fd]               
    int 0x80   

    mov edi, subs
    mov ecx, 128
    xor al, al
    rep stosb                

    jmp main

error:
    jmp main

execute_touch:
    mov esi, 6              
    xor ecx, ecx
    
    ; Clear subs buffer
    push edi               
    mov edi, subs
    mov ecx, 128
    xor al, al
    rep stosb
    pop edi
    
    ; Get filename
    xor ecx, ecx

get_filename:
    cmp byte [input + esi], 0
    je create_file
    mov bl, [input + esi]
    mov [subs + ecx], bl
    inc esi
    inc ecx
    jmp get_filename

get_filename_sub:
    cmp byte [input + esi], 0
    je execute_cat
    mov bl, [input + esi]
    mov [subs + ecx], bl
    inc esi
    inc ecx
    jmp get_filename

create_file:
    mov byte [subs + ecx], 0    
    
    mov eax, 8          
    mov ebx, subs      
    mov ecx, mode       
    int 0x80
    
    cmp eax, 0
    jl error_creating   
    
    jmp main

error_creating:
    mov eax, 4
    mov ebx, 1
    mov ecx, error_msg
    mov edx, error_len
    int 0x80
    jmp main

execute_ls:
    mov eax, 2    
    int 0x80
    test eax, eax
    jz child_ls   

    call exit_parent

child_ls:
    mov ebx, command    
    mov ecx, args_ls    
    mov edx, empty_environ 
    mov eax, 11         
    int 0x80

    mov eax, 1
    mov ebx, 1
    int 0x80

execute_pwd:
    mov eax, 2   
    int 0x80
    test eax, eax
    jz child_pwd  

    call exit_parent

child_pwd:
    mov ebx, command1   
    mov ecx, args_pwd   
    mov edx, empty_environ 
    mov eax, 11         
    int 0x80

    mov eax, 1
    mov ebx, 1
    int 0x80

exit:
    mov eax, 1
    xor ebx, ebx
    int 0x80

exit_parent:
    mov eax, 7    
    mov ebx, -1
    mov ecx, 0
    mov edx, 0
    int 0x80
    jmp main