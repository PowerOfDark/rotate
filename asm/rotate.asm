; Funkcja wykonujaca obrot monochromatycznej bitmapy o 90 stopni w prawo
; Przemyslaw Rozwalka, ARKO 2020
; rozwiazanie wykorzystujace `lookup table`, pozostajace najszybszym

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
global _rotate

_rotate:
    ; arguments (IN REVERSE ORDER!)
    ;%arg    pdDst:qword - rbp+0x10            ; pointer to descriptor of destination image
    ;%arg    pdSrc:qword - rbp+0x18            ; pointer to descriptor of source image
; used registers
    ; rdi - obDstNextChunk - byte offset to advance to the next chunk in destination image
    ; r8 - pointer to source image descriptor (*pdSrc)
    ; r9 - pointer to destination image descriptor (*pdDst)
    ; r11 - pbSrcEnd - byte pointer to the last byte of source image
    ; r12 - pbSrcColumn - byte pointer to the currently proccesed source column
    ; r13 - pbSrcLastColumn - byte pointer to the last source column to be processed
    ; r14 - pbDstChunkLow - byte pointer to the lowest byte of current destination chunk
    ; r15 - pfCopy - pointer to the copy routine to be used for current scan column

        ; prologue
        push rbp
        mov rbp, rsp

        ; store non-volatile registers
        push rbx
        push rdi
        push rsi
        push r12
        push r13
        push r14
        push r15
_rotate_prepare:
        ; copy pointers from arguments
        mov r8, [rbp+0x18]
        mov r9, [rbp+0x10]
        ; calculate and store parameters

        ;   from source
        mov r12, [r8+Desc.DataPtr]
        dec QWORD r12               ; offset the addition ran once in the main loop

        mov ecx, [r8+Desc.Width]
        shr ecx, 3                  ; ecx = pdSrc->Width / 8
        mov r13, [r8+Desc.DataPtr]
        add r13, rcx                ; r13 (pbSrcLastColumn) = pdSrc->DataPtr + rcx

        mov eax, [r8+Desc.FileSize]
        mov r11, [r8+Desc.HeaderPtr]
        add r11, rax; r11 (pbSrcEnd) = pdSrc->HeaderPtr + pdSrc->FileSize


        ;   from destination
        mov eax, [r9+Desc.FileSize]
        mov r14, [r9+Desc.HeaderPtr]
        add r14, rax; r14 (pbDstChunkLow) = pdSrc->HeaderPtr + src->FileSize

        mov edi, [r8+Desc.RowSize]

        ; set the default copy routine
        mov QWORD r15, _rotate_copy_8
_rotate_columns:
        ; pbSrcColumn++
        inc r12
        ; if all 8bytes chunks done, process leftovers
        cmp r12, r13
        jge _rotate_leftover
        ; move destination chunk 8 rows lower
        mov eax, [r9+Desc.RowSize]
        shl eax, 3
        sub r14, rax    ; r14 (pbDstChunkLow) -= (obDstNextRow*8)
_rotate_column:
; registers reserved for inner loop:
;   rax         - buffer for current chunk
;   rcx (cl)    - number of bits left to read into current chunk
;   rsi         - pointer to current position of the source image
;   r10         - pointer to current position of the destination image
        mov rsi, r12
        mov r10, r14
_rotate_column_new_chunk:
        ; if source pointer is past the end, go to next column
        cmp rsi, r11
        jge _rotate_columns
        ; reset locals
        xor rax, rax  ; rax (buf) = 0
        mov cl, BYTE 8
_rotate_column_continue:
        ; process next source byte
        movzx edx, BYTE [rsi]           ; edx = *rsi

        ; read first lookup and combine bits
        shl rax, 1                      ; make room for read bits
        or rax, QWORD [LOOKUP + edx*8]  ; add bits from lookup
        ; advance source ptr by one row
        add rsi, rdi

        ; if all bits are ready, go copy them
        dec cl
        jz _rotate_copy
        ; if end of column, flush read bits
        cmp rsi, r11
        jge _rotate_shift_copy
        ; otherwise, keep reading this chunk

        jmp _rotate_column_continue
_rotate_shift_copy:
        shl rax, cl             ; push bits in the buffer by number of unused bits
_rotate_copy:
; rcx is no longer used below
        mov rbx, r10                ; set rbx to base chunk destination
        mov ecx, [r9+Desc.RowSize]  ; set ecx to pdDst->RowSize
        jmp r15                     ; jump to the adequate copy routine
; extract bytes from the buffer
_rotate_copy_8:
        mov BYTE [rbx], al      ; *rbx = lowest byte from buffer
        add rbx, rcx            ; advance write address by one row
_rotate_set_7:
        mov BYTE [rbx], ah      ; *rbx = higher byte from ax
        add rbx, rcx
        shr rax, 16             ; push 2 new bytes into ax
_rotate_set_6:
        mov BYTE [rbx], al
        add rbx, rcx
_rotate_set_5:
        mov BYTE [rbx], ah
        add rbx, rcx
        shr rax, 16             ; push 2 new bytes into ax
_rotate_set_4:
        mov BYTE [rbx], al
        add rbx, rcx
_rotate_set_3:
        mov BYTE [rbx], ah
        add rbx, rcx
        shr rax, 16             ; push remaining 2 bytes into ax
_rotate_set_2:
        mov BYTE [rbx], al
        add rbx, rcx
_rotate_set_1:
        mov BYTE [rbx], ah

        inc r10
        jmp _rotate_column_new_chunk
; copy routines for less than 8 bytes
;_rotate_copy_7:
        ; reading from ah, all fine!
        ; inlined and therefore commented out
;        jmp _rotate_set_7
_rotate_copy_6:
        ; skip one word
        shr rax, 16
        jmp _rotate_set_6
_rotate_copy_5:
        ; reading from ah
        shr rax, 16
        jmp _rotate_set_5
_rotate_copy_4:
        ; skip two words
        shr rax, 32
        jmp _rotate_set_4
_rotate_copy_3:
        ; reading from ah
        shr rax, 32
        jmp _rotate_set_3
_rotate_copy_2:
        ; skip three words
        shr rax, 48
        jmp _rotate_set_2
_rotate_copy_1:
        ; reading from ah
        shr rax, 48
        jmp _rotate_set_1

_rotate_leftover:
        ; cmp r12 (pbSrcColumn), r13 (pbLastColumn)
        ; comparison evaluated before jump
        jg _rotate_exit
        mov eax, [r8+Desc.Width]    ; eax = pdSrc->Width
        and eax, 7                  ; eax %= 8 (remaining bits)
        ; end if width is divisible by 8; ZF set by `and`
        jz _rotate_exit
        ; set address of custom copy routine
        mov QWORD r15, [COPY_ROUTINES + eax*8]

        ; lower the destination chunk by (remaining bits)*rows

        mul DWORD [r9+Desc.RowSize] ; edx:eax = (remaining bits)*pdDst->RowSize
                                    ; the resulting value is 32-bit (eax only)
        sub r14, rax                ; r14 (pbDstChunkLow) -= rax
        ; perform one last column scan
        jmp _rotate_column


_rotate_exit:
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
                dq _rotate_copy_1
                dq _rotate_copy_2
                dq _rotate_copy_3
                dq _rotate_copy_4
                dq _rotate_copy_5
                dq _rotate_copy_6
                dq _rotate_set_7
                dq _rotate_copy_8

LOOKUP:     incbin "lookup.bin",0,2048
