section .data
    newline db 0xA
    prompt db "shell> ", 0
    len equ $ - prompt
    clear_seq db 0x1B, '[2J', 0x1B, '[3J', 0x1B, '[H'  ; ANSI sequence
    clear_len equ $ - clear_seq   
    
    ls db "ls", 0
    command db "/usr/bin/ls", 0
    
    pwd db "pwd", 0
    command1 db "/usr/bin/pwd", 0
    
    touch db "touch", 0
    mode equ 0644    ; File permissions (rw-r--r--)
    
    echo db "echo", 0
    cat  db "cat",  0
    mkdir db "mkdir", 0
    rmdir db "rmdir", 0
    rm db "rm", 0
    clear db "clear", 0
    cd db "cd", 0
    
    exits db "exit", 0
    
    current equ 5

    rm_command db "/bin/rm", 0
    rm_arg_r  db "-r", 0
    rmdir_error   db "Failed to remove directory", 0xA
    rmdir_err_len equ $ - rmdir_error

    args_rm:
        dd rm_command    
        dd rm_arg_r      
        dd subs          
        dd 0    
    
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

    ;mkdir
    mov esi, input
    mov edi, mkdir
    mov ecx, 5
    repe cmpsb
    je execute_mkdir

    ;mkdir
    mov esi, input
    mov edi, rmdir
    mov ecx, 5
    repe cmpsb
    je execute_rmdir

    ;rm 
    mov esi, input
    mov edi, rm
    mov ecx, 2
    repe cmpsb
    je execute_rm

    ;clear 
    mov esi, input
    mov edi, clear
    mov ecx, 5
    repe cmpsb
    je execute_clear 

    ;cd 
    mov esi, input
    mov edi, cd
    mov ecx, 2
    repe cmpsb
    je execute_cd 
    
    ; Unknown command
    mov eax, 4
    mov ebx, 1
    mov ecx, unknown_msg
    mov edx, unknown_len
    int 0x80
    
    jmp main

execute_cd:
    mov esi, 3
    xor ecx, ecx

    push edi
    mov edi, subs
    mov ecx, 128
    xor eax, eax
    rep stosb
    pop edi

    xor ecx, ecx

get_foldername_cd:
    cmp byte [input + esi], 0
    je cd_main

    mov bl, [input + esi]
    mov [subs + ecx], bl

    inc esi 
    inc ecx

    jmp get_foldername_cd

cd_main:
    mov byte [subs + ecx], 0  

    mov eax, 12 ;syscall code for changing directory
    mov ebx, subs
    int 0x80

    call execute_pwd

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

execute_mkdir:
    mov esi, 6

    ; Clear subs buffer
    push edi
    mov edi, subs
    mov ecx, 128
    xor al, al
    rep stosb
    pop edi
    
    ; Get filename
    xor ecx, ecx

get_filename_mkdir:
    cmp byte [input + esi], 0
    je mkdir_main

    mov bl, [input + esi]
    mov [subs + ecx], bl
    inc esi
    inc ecx

    jmp get_filename_mkdir

; creating directory here
mkdir_main:
    mov byte [subs + ecx], 0  

    mov eax, 39 ; syscall number for creating a directory
    mov ebx, subs
    mov ecx, 0o755
    int 0x80 

    jmp main

execute_rmdir:
    mov esi, 6           
    xor ecx, ecx         

    ; Clear the subs buffer (optional but safer)
    push edi             
    mov edi, subs        
    xor eax, eax         
    mov ecx, 128        
    rep stosb            
    pop edi       

    xor ecx, ecx         

get_filename_rmdir:
    cmp byte [input + esi], 0  
    je rmdir_main              
    cmp byte [input + esi], ' '
    je rmdir_main              

    mov al, [input + esi]
    mov [subs + ecx], al
    inc esi
    inc ecx
    jmp get_filename_rmdir

rmdir_main:
    mov byte [subs + ecx], 0

    mov eax, 40          
    mov ebx, subs
    int 0x80

    test eax, eax
    js handle_rmdir_error        

    jmp main             

handle_rmdir_error:
    ; Check if error is "Directory not empty" (errno 39)
    cmp eax, -39
    jne print_rmdir_error 

    ; Fork to execute /bin/rm -r <directory>
    mov eax, 2  ; syscall number for fork         
    int 0x80
    test eax, eax
    jz child_rm_r        

    mov eax, 7   ; Syscall 7: waitpid       
    mov ebx, -1  ; Wait for any child        
    xor ecx, ecx         
    xor edx, edx        
    int 0x80
    jmp main             

child_rm_r:
    mov eax, 11   ; syscall 11, exceve (used to call predefined commands)      
    mov ebx, rm_command  
    mov ecx, args_rm    
    mov edx, empty_environ 
    int 0x80

    mov eax, 1
    mov ebx, 1
    int 0x80

print_rmdir_error:
    mov eax, 4
    mov ebx, 1
    mov ecx, rmdir_error
    mov edx, rmdir_err_len
    int 0x80
    jmp main

execute_clear:
    mov eax, 4
    mov ebx, 1
    mov ecx, clear_seq
    mov edx, clear_len
    int 0x80

    jmp main

execute_rm:
    mov esi, 3
    xor ecx, ecx

    push edi
    mov edi, subs
    xor eax, eax
    mov ecx, 128
    repe stosb
    pop edi

    xor ecx, ecx

get_filename_rm:
    cmp byte [input + esi], 0
    je main_rm

    mov bl, [input + esi]
    mov [subs + ecx], bl

    inc esi
    inc ecx

    jmp get_filename_rm

main_rm:
    mov byte [subs + ecx], 0

    mov eax, 10
    mov ebx, subs
    int 0x80

    test eax, eax
    js exit_rm

    jmp main

exit_rm:
    mov eax, 1
    xor ebx, ebx
    int 0x80

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
    mov eax, 2  ;syscall 2 is for fork (to hold the current process)
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