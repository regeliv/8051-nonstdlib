; PUSHR [MACRO]
; push register onto stack
; usage: pushr r7
pushr    macro    reg
    mov     b, reg
    push     b
endm

; POPR [MACRO]
; pop from stack into register
; usage: popr r6
popr    macro    reg
    pop     b
    mov     reg, b
endm

; CMP [MACRO]
; compare two registers
; if reg1 = reg2, then acc is 0
; if reg1 < reg2, then c (carry bit) is 1
; if reg1 > reg,  then c (carry bit) is 0
; usage: cmp r1, r3
;        jz  equal_label   
;        jc  less_label
;        jnc greater_laber
cmp        macro    reg1, reg2
    clr     c
    mov     a, reg1
    subb    a, reg2
endm

; bank{0,1,2,3} [MACRO]
; change register back to specified number
; usage: bank3
bank0     macro
    anl     psw, #11100111b
endm

bank1    macro
    setb    rs0
    clr     rs1
endm

bank2    macro
    clr     rs0
    setb    rs1
endm

bank3    macro
    orl        psw, #00011000b
endm

; movr    [MACRO]
; move reg2 to r1
; usage: movr r3, r7
movr    macro   reg1, reg2
    mov     b, reg2
    mov     reg1, b
endm

; add16 [MACRO]
; add 16bit numbers: num1h:num1l + num2h:num2l
; leaves the answer in a:b
; usage: add16 r1, r0, r3, r2
add16   macro   num1h, num1l, num2h, num2l
    mov     a, num1l
    add     a, num2l
    mov     b, a
    mov     a, num1h
    addc    a, num2h
endm

; ABI:
; arguments to procedurs are passed in registers of bank3 and dptr:
; rN@bM means the N-th register of M-th bank
; r0@b3 - first argument
; r1@b3 - second argument etc.
; dptr  - 16-bit address argument
;
; bank3 registers, a, b, psw, dptr are caller saved
; other registers are callee saved
; in interrupts all registers are callee saved
;
; after a procedure the cpu is left in bank3
    

; fn memcpy(dst: u8, src: u8, cnt: u8) void
; copy cnt bytes from src to dst
; cpu is left in bank3 after returning
; r0@b3 (18h) := dst
; r1@b3 (19h) := src
; r2@b3 (1Ah) := cnt
memcpy:
    bank3
__memcpy_loop:
    mov     a, r2
    jz      __memcpy_end
    
    mov     a, @r1
    mov     @r0, a
    
    dec     r2
    inc     r1
    inc     r0
    jmp     __memcpy_loop

__memcpy_end:
    ret

; fn memcpy(dst: u8, src: u16, cnt: u8) void
; copy cnt bytes from src to dst
; cpu is left in bank3 after returning
; r0@b3 (18h) := dst
; dptr        := src
; r1@b3 (19h) := cnt
memcpy_disk:
    bank3
__memcpy_disk_loop:
    mov     a, r1
    jz      __memcpy_disk_end
    
    clr     a
    movc    a, @a+dptr
    mov     @r0, a
    
    inc     dptr
    inc     r0
    dec     r1
    jmp     __memcpy_disk_loop
__memcpy_disk_end:
    ret
    
; fn dec_cycle_cnt(ptr: u8, beg_addr: u8, cnt: u8)
; decrement ptr, if ptr < beg_addr, then set ptr to beg_addr+cnt-1
; this function is used to facilitate cyclical buffer usage
; cpu is left in bank3 after returning
; r0@b3 (18h):= ptr
; r1@b3 (19h):= beg_addr
; r2@b3 (1Ah):= cnt
; returns the adjusted ptr in r0@b3 (18h)
dec_cycle_cnt:
    bank3
    dec     r0
    cmp     r0, r1
    
    jz      __dec_cycle_cnt_end     ; if equal
    jnc     __dec_cycle_cnt_end     ; if greater than
    
    dec     r2
    mov     a, r1
    add     a, r2
    mov     r0, a
__dec_cycle_cnt_end:
    ret
    
; fn modulo(dividend: u8, divisor: u8) u8
; compute dividend mod divisor
; cpu is left in bank3 after returning
; r0@b3 (18h) := dividend
; r1@b3 (19h) := divisor
; returns result in r0@b3 (18h)
modulo:
    bank3
    mov     a, r0
    mov     b, r1
    div     ab
    mov     r0, b
    ret
    
; fn rand(seed_addr: u8) void
; generate pseudo random number (galois lfsr)
; cpu is left in bank3 after returning
; r0@b3 (18h) := seed_addr
; result is written to seed_addr
rand:
    bank3
    mov     a, @r0
    mov     b, #2
    div     ab
    mov     r1, a
    
    clr     c
    clr     a
    subb    a, b        ; b stores the remainder - 1 or 0
    anl     a, #0xb8
    xrl     a, r1
    mov     @r0, a
    ret