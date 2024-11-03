;; 80 byte x86_64 Linux ELF executable
;; Just exits with status 0.
;;
;; The ELF and program headers are overlapped to save 40 bytes.
;; Assemble with NASM:
;;   nasm -f bin tiny.asm
;; Tested on Linux 6.10.
;;
;; Inspired by:
;;   http://www.muppetlabs.com/~breadbox/software/tiny/teensy.html
;;   https://nathanotterness.com/2021/10/tiny_elf_modernized.html

;; Copyright (C) 2024 by Lucas Ransan <lucas@ransan.fr>
;;
;; Permission to use, copy, modify, and/or distribute this software for any
;; purpose with or without fee is hereby granted.
;;
;; THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
;; REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
;; AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
;; INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
;; LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
;; OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
;; PERFORMANCE OF THIS SOFTWARE.

bits 64

;; p_vaddr - p_offset
org 0x500000000

eh:
    ; ELF magic has to be present
    db 0x7f
    ; Entry point is forced here by p_type.
entry:
    db "ELF"                    ; rex.RB rex.WR rex.RX
    ; clobberable
    push 60
    pop rax
    syscall
    times 7 db 0
e_ident_end:

    ; e_type has to be ET_EXEC
    dw 2                        ; e_type
    ; clobberable
    dw 0x3e                     ; e_machine
    dd 1                        ; e_version
ph:
    ; p_type has to be PT_LOAD
    dd 1                        ; e_entry           p_type
    ; p_flags first 3 bits have to be rx or rwx
    ;         last 29 bits could be clobbered
    dd 5                        ; |                 p_flags
    ; e_phoff has to be the offset of the program header in the file
    dq 24                       ; e_phoff           p_offset
    ; As p_offset is forced to 0x18 by e_phoff, and (p_vaddr - p_offset) %
    ; page_size has to be 0, the low bytes of p_vaddr are forced to 0x18.
    ; e_entry is forced to 0x500000001 by p_type and p_flags, so we can load the
    ; program at 0x500000000.
    dq 0x500000018              ; e_shoff           p_vaddr
    ; clobberable
    dd 0                        ; e_flags           p_paddr
    dw 0                        ; e_ehsize          |
    ; e_phentsize has to be right
    dw 56                       ; e_phentsize       |
    ; p_filesz and p_memsz have to be nonzero and equal. They cannot be too big,
    ; because Linux will try to allocate p_memsz bytes, rounded up to page size.
    ; e_phnum has to be right
    dw 1                        ; e_phnum           p_filesz
    dw 0                        ; e_shentsize       |
    dw 0                        ; e_shnum           |
    dw 0                        ; e_shstrndx        |
eh_end:
    dq 1                        ;                   p_memsz
    ; clobberable
    dq 0                        ;                   p_align
ph_end:


;; ELF header checks to catch dumb errors
%assign e_ident_bytes e_ident_end - eh
%if e_ident_bytes != 16
%error e_ident is e_ident_bytes bytes, should be 16
%endif

%assign eh_size eh_end - eh
%if eh_size != 64
%error ELF header is eh_size bytes, should be 64
%endif

%assign ph_off ph - eh
%if ph_off != 24
%error program header offset is ph_off bytes, should be 24
%endif

%assign ph_size ph_end - ph
%if ph_size != 56
%error program header is ph_size bytes, should be 56
%endif

