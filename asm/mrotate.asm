; Funkcja wykonujaca obrot monochromatycznej bitmapy o 90 stopni w prawo
; Przemyslaw Rozwalka, ARKO 2020
; rozwiazanie bez `lookup table` - zbiera fragment 8x8 jako 8 bajtow;
;   w celu odczytania pojednczej 'kolumny' wyjsciowej, maskuje pozadane bity
;   oraz 'zbiera' je do najwyzszego bajtu (mnozac je przez 'magiczna stala')
;       ilustracja:
;
;wejscie            :.......1 .......2 .......3 .......4 .......5 .......6 .......7 .......8
;mnoznik            :00000001 00000010 00000100 00001000 00010000 00100000 01000000 10000000
;wynik              :12345678 2345678. 345678.. 45678... 5678.... 678..... 78...... 8.......
;wynik >> 56        :........ ........ ........ ........ ........ ........ ........ 12345678

; stad
;   maska wejsciowa = 0x0101010101010101
;   mnoznik         = 0x0102040810204080

; Alternatywny sposob moglby wykorzystac instrukcje PEXT z rozszerzenia BMI2,
; ktora przyjmuje maske bitow i zwraca otrzymane bity 'spakowane obok siebie' -
; niestety BMI2 jest dostepne (sprzetowo) tylko na procesorach Intel Haswell lub nowszych.
;

; Porownanie metod (3 obroty obrazu 7212x10740 ~10MB):
; AMD Ryzen 3900x (bez BMI2):
;   - lookup:   ~50ms
; 	- magic:	~90ms
; 	- PEXT:		~300ms
; Intel Xeon E3-1230v6 (sprzętowe BMI2):
;   - lookup:   ~60ms
; 	- PEXT:		~75ms
; 	- magic:	~110ms



; offsets definition for the BitmapDescriptor structure
struc   Desc
        .HeaderPtr  resq 1
        .FileSize   resd 1
        .DataPtr    resq 1
        .Width      resd 1
        .Height     resd 1
        .RowSize    resd 1
endstruc

section .text
global _mrotate

_mrotate:
    ; arguments (IN REVERSE ORDER!)
    ;%arg    pdDst:qword - rbp+0x10            ; pointer to descriptor of destination image
    ;%arg    pdSrc:qword - rbp+0x18            ; pointer to descriptor of source image
; used registers
    ; rdi - temporary register to store byte offsets
    ; r8 - pointer to source image descriptor (*pdSrc)
    ; r9 - pointer to destination image descriptor (*pdDst)
    ; r10 - pointer to current position of the destination image
    ; r11 - pbSrcEnd - byte pointer to the last byte of source image
    ; r12 - pbSrcColumn - byte pointer to the currently proccesed source column
    ; r13 - (constant) bit mask for the copy routines
    ; r14 - pbDstChunkLow - byte pointer to the lowest byte of current destination chunk
    ; r15 - (constant) magic multiplier for the copy routine
    ;%local pfCopy:qword - rbp-0x8
    ;%local pbSrcLastColumn:qword - rbp-0x10
        ; prologue
        push rbp
        mov rbp, rsp
        sub rsp, 16

        ; store non-volatile registers
        push rbx
        push rdi
        push rsi
        push r12
        push r13
        push r14
        push r15
_mrotate_prepare:
        ; copy pointers from arguments
        mov r8, [rbp+0x18]
        mov r9, [rbp+0x10]
        ; calculate and store parameters

        ;   from source
        mov r12, [r8+Desc.DataPtr]
        dec QWORD r12               ; offset the addition ran once in the main loop

        mov ecx, [r8+Desc.Width]
        shr ecx, 3                  ; ecx = pdSrc->Width / 8
        add rcx, [r8+Desc.DataPtr]
        mov [rbp-0x10], rcx       ; (pbSrcLastColumn) = pdSrc->DataPtr + pdSrc->Width / 8


        mov eax, [r8+Desc.FileSize]
        mov r11, [r8+Desc.HeaderPtr]
        add r11, rax; r11 (pbSrcEnd) = pdSrc->HeaderPtr + pdSrc->FileSize


        ;   from destination
        mov eax, [r9+Desc.FileSize]
        mov r14, [r9+Desc.HeaderPtr]
        add r14, rax; r14 (pbDstChunkLow) = pdSrc->HeaderPtr + src->FileSize

        ; store magic constants
        mov r13, 0x0101010101010101
        mov r15, 0x102040810204080

        mov edi, [r8+Desc.RowSize]

        ; set the default copy routine
        mov QWORD [rbp-0x8], _mrotate_copy_8
_mrotate_columns:
        ; pbSrcColumn++
        inc r12
        ; if all 8bytes chunks done, process leftovers
        mov rax, [rbp-0x10]
        cmp r12, rax
        jge _mrotate_leftover
        ; move destination chunk 8 rows lower
        mov eax, [r9+Desc.RowSize]
        shl eax, 3
        sub r14, rax    ; r14 (pbDstChunkLow) -= (obDstNextRow*8)
_mrotate_column:
; registers reserved for inner loop:
;   rax         - buffer for current chunk
;   rcx (cl)    - number of bits left to read into current chunk
;   rsi         - pointer to current position of the source image
;   r10         - pointer to current position of the destination image
        mov rsi, r12
        mov r10, r14
_mrotate_column_new_chunk:
        ; if source pointer is past the end, go to next column
        cmp rsi, r11
        jge _mrotate_columns
        ; reset locals
        xor rax, rax  ; rax (buf) = 0
        mov cl, BYTE 64
        mov edi, [r8+Desc.RowSize] ; edi = pSrc->RowSize (for reading bytes)
_mrotate_column_continue:
        ; process next source byte
        shl rax, 8
        mov al, BYTE [rsi]
        ; advance source ptr by one row
        add rsi, rdi

        sub cl, 8
        ; if all bits are ready, go copy them
        jz _mrotate_copy
        ; if end of column, flush read bits
        cmp rsi, r11
        jge _mrotate_shift_copy
        ; otherwise, keep reading this chunk
        jmp _mrotate_column_continue
_mrotate_shift_copy:
        shl rax, cl             ; push bits in the buffer by number of unused bits
_mrotate_copy:
; free registers to be used below: rbx, rcx, rdi
; rdx will be overwritten by multiplications
        mov rbx, r10                ; set rbx to base chunk destination
        mov rcx, rax                ; backup buffer into rcx
        mov edi, [r9+Desc.RowSize]  ; edi = pdDst->RowSize (for writing bytes)
        jmp [rbp-0x8]               ; jump to the adequate copy routine
; extract columns as bytes
_mrotate_copy_8:
; two ways to extract the column:
    ; using multiplication by magic constant:
        ;and rax, r13 ; mask only the least significant bit in each byte
        ;mul r15      ; shift/aggregate by multiplication
        ;shr rax, 56  ; shift output from highest byte
    ; using PEXT from BMI2 extension (Intel Haswell+)
        ; PEXT rax, rcx, r13
    ; PEXT is ~4 times slower on AMD Zen (supported only via CPU microcode)
        and rax, r13
        mul r15
        shr rax, 56
        mov BYTE [rbx], al      ; *rbx = lowest byte from buffer
        add rbx, rdi            ; advance write address by one row
        shr rcx, 1              ; shift buffer to read next column
_mrotate_set_7:
        mov rax, rcx            ; restore rax
        and rax, r13
        mul r15
        shr rax, 56
        mov BYTE [rbx], al
        add rbx, rdi
        shr rcx, 1
_mrotate_set_6:
        mov rax, rcx
        and rax, r13
        mul r15
        shr rax, 56
        mov BYTE [rbx], al
        add rbx, rdi
        shr rcx, 1
_mrotate_set_5:
        mov rax, rcx
        and rax, r13
        mul r15
        shr rax, 56
        mov BYTE [rbx], al
        add rbx, rdi
        shr rcx, 1
_mrotate_set_4:
        mov rax, rcx
        and rax, r13
        mul r15
        shr rax, 56
        mov BYTE [rbx], al
        add rbx, rdi
        shr rcx, 1
_mrotate_set_3:
        mov rax, rcx
        and rax, r13
        mul r15
        shr rax, 56
        mov BYTE [rbx], al
        add rbx, rdi
        shr rcx, 1
_mrotate_set_2:
        mov rax, rcx
        and rax, r13
        mul r15
        shr rax, 56
        mov BYTE [rbx], al
        add rbx, rdi
        shr rcx, 1
_mrotate_set_1:
        mov rax, rcx
        and rax, r13
        mul r15
        shr rax, 56
        mov BYTE [rbx], al

        inc r10
        jmp _mrotate_column_new_chunk
; copy routines for less than 8 bytes
_mrotate_copy_7:
        shr rcx, 1
        jmp _mrotate_set_7
_mrotate_copy_6:
        shr rcx, 2
        jmp _mrotate_set_6
_mrotate_copy_5:
        shr rcx, 3
        jmp _mrotate_set_5
_mrotate_copy_4:
        shr rcx, 4
        jmp _mrotate_set_4
_mrotate_copy_3:
        shr rcx, 5
        jmp _mrotate_set_3
_mrotate_copy_2:
        shr rcx, 6
        jmp _mrotate_set_2
_mrotate_copy_1:
        shr rcx, 7
        jmp _mrotate_set_1

_mrotate_leftover:
        ; cmp r12 (pbSrcColumn), r13 (pbLastColumn)
        ; comparison evaluated before jump
        jg _mrotate_exit
        mov eax, [r8+Desc.Width]    ; eax = pdSrc->Width
        and eax, 7                  ; eax %= 8 (remaining bits)
        ; end if width is divisible by 8; ZF set by `and`
        jz _mrotate_exit
        ; set address of custom copy routine
        mov rdx, [COPY_ROUTINES + eax*8]
        mov [rbp-0x8], rdx

        ; lower the destination chunk by (remaining bits)*rows

        mul DWORD [r9+Desc.RowSize] ; edx:eax = (remaining bits)*pdDst->RowSize
                                    ; the resulting value is 32-bit (eax only)
        sub r14, rax                ; r14 (pbDstChunkLow) -= rax
        ; perform one last column scan
        jmp _mrotate_column


_mrotate_exit:
        ; return 0
        mov rax, 0
        ; restore registers from the stack
        pop r15
        pop r14
        pop r13
        pop r12
        pop rsi
        pop rdi
        pop rbx
        ; epilogue
        mov rsp, rbp
        pop rbp

        ret


section .data
COPY_ROUTINES:  dq 0             ; 0 bytes .. impossible
                dq _mrotate_copy_1
                dq _mrotate_copy_2
                dq _mrotate_copy_3
                dq _mrotate_copy_4
                dq _mrotate_copy_5
                dq _mrotate_copy_6
                dq _mrotate_copy_7
                dq _mrotate_copy_8
