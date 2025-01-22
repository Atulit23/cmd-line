# x32 Assembly Shell

A simple shell written in x86 32-bit assembly for Linux, supporting basic commands.

## Requirements
- NASM (Netwide Assembler)
- GNU Linker (ld)
- 32-bit libraries (on 64-bit systems):
  ```bash
  sudo apt install gcc-multilib  # Debian/Ubuntu

## Build & Run

### Assemble with NASM:
```bash
nasm -f elf32 shell.asm -o shell.o
ld -m elf_i386 shell.o -o shell
./shell
```

## Supported Commands
- `ls` - List directory contents 
- `pwd` - Print working directory 
- `touch <filename>` - Create new file with 0644 permissions (rw-r--r--)
- `echo <text>` - Print text to standard output
- `cat <filename>` - Display file contents
- `mkdir <dirname>` - Create new directory
- `rmdir <dirname>` - Remove directory
- `rm <filename>` - Delete file
- `clear` - Clear terminal screen (ANSI escape sequence)
- `cd <dirname>` - Change working directory
- `exit` - Quit the shell

## Usage Examples
```bash
shell> touch newfile.txt     # Creates newfile.txt
shell> mkdir documents       # Makes 'documents' directory
shell> ls                    # Lists files: newfile.txt documents/
shell> cd documents          # Change to documents directory
shell> pwd                   # Shows path: /path/to/documents
shell> clear                 # Clears terminal
shell> exit                  # Quits the shell