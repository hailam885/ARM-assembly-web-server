
; Register organization:

; x0 - x7           Function I/O
; x8                Syscall/Indirect Result
; x9 - x15          Scratch
; x16               Syscall
; x17               Temp register for compilers/linkers
; x18               Platform

; x19               Server file descriptor
; x20               Client file descriptor
; x21               Bytes read for read() from client connections
; x22               (TBD)
; x23               (TBD)
; x24               (TBD)
; x25 - x28         Scratch
; x29               Stack/Frame pointer
; x30               Link register/Return address

.global _main
.align 2

_main:

    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!
    stp x27, x28, [sp, #-16]!
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    adrp x0, filename @PAGE
    add x0, x0, filename @PAGEOFF
    mov x1, #0
    mov x2, #0
    mov x16, #5
    svc #0x80

    cmp x0, #0
    bge _main_open_file_fail_end

_main_open_file_fail:

    mov x0, #1
    adrp x1, fail_load_file @PAGE
    add x1, x1, fail_load_file @PAGEOFF
    mov x2, fail_load_file_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, filename @PAGE
    add x1, x1, filename @PAGEOFF
    mov x2, filename_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, p_newline @PAGE
    add x1, x1, p_newline @PAGEOFF
    mov x2, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    b _main_exit

_main_open_file_fail_end:

    ; fstat()
    mov x21, x0
    adrp x1, stat_struct @PAGE
    add x1, x1, stat_struct @PAGEOFF
    mov x16, #189
    svc #0x80

    cmp x0, #0
    beq _main_get_file_info_fail_end

_main_get_file_info_fail:

    mov x0, #1
    adrp x1, fail_get_file_info @PAGE
    add x1, x1, fail_get_file_info @PAGEOFF
    mov x2, fail_get_file_info_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, p_newline @PAGE
    add x1, x1, p_newline @PAGEOFF
    mov x2, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    b _main_exit

_main_get_file_info_fail_end:

    adrp x28, stat_struct @PAGE
    add x28, x28, stat_struct @PAGEOFF
    ldr x0, [x28, #72]
    cmp x0, #0
    bgt _main_file_empty_end

_main_file_empty:

    mov x0, #1
    adrp x1, fail_file_empty @PAGE
    add x1, x1, fail_file_empty @PAGEOFF
    mov x2, fail_file_empty_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    b _main_exit

_main_file_empty_end:

    mov x0, x21
    adrp x1, file_contents_buffer @PAGE
    add x1, x1, file_contents_buffer @PAGEOFF
    ldr x2, [x28, #72]
    mov x16, #3
    svc #0x80

    cmp x0, #0
    bgt _main_file_read_error_end

_main_file_read_error:

    mov x0, #1
    adrp x1, fail_read_file @PAGE
    add x1, x1, fail_read_file @PAGEOFF
    mov x2, fail_read_file_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    b _main_exit

_main_file_read_error_end:

    ; save file length
    adrp x2, file_contents_len @PAGE
    add x2, x2, file_contents_len @PAGEOFF
    str w0, [x2]
    
    mov x2, x0
    mov x25, x0

    mov x0, #1
    adrp x1, file_contents_buffer @PAGE
    add x1, x1, file_contents_buffer @PAGEOFF
    
    ; TEMPORARY
    mov x16, #4
    svc #0x80

    ; TEMPORARY
    mov x0, x25
    bl __num_to_ascii
    mov x2, x0
    mov x0, #1
    mov x16, #4
    svc #0x80

    ; TEMPORARY
    mov x0, #0
    b _main_exit

    ; socket()
    mov x0, #2
    mov x1, #1
    mov x2, #0
    mov x16, #97
    svc #0x80

    cmp x0, #3
    bge _main_create_socket_fail_branch_end

_main_create_socket_fail_branch:

    mov x0, #1
    adrp x1, fail_create_socket @PAGE
    add x1, x1, fail_create_socket @PAGEOFF
    mov x2, fail_create_socket_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    b _main_exit

_main_create_socket_fail_branch_end:

    mov x19, x0                         ; server fd

    adrp x1, server_fd @PAGE
    add x1, x1, server_fd @PAGEOFF
    str w0, [x1]

    ; bind()
    mov x0, x19
    adrp x1, address @PAGE
    add x1, x1, address @PAGEOFF
    mov x2, #16
    mov x16, #104
    svc #0x80

    cmp x0, #0
    beq _main_bind_socket_fail_branch_end

_main_bind_socket_fail_branch:

    mov x0, #1
    adrp x1, fail_bind_socket @PAGE
    add x1, x1, fail_bind_socket @PAGEOFF
    mov x2, fail_bind_socket_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    b _main_exit

_main_bind_socket_fail_branch_end:

    ; listen()
    mov x0, x19
    mov x1, #16384
    mov x16, #106
    svc #0x80

    cmp x0, #0
    bge _main_listen_socket_fail_branch_end

_main_listen_socket_fail_branch:

    mov x0, #1
    adrp x1, fail_listen_socket @PAGE
    add x1, x1, fail_listen_socket @PAGEOFF
    mov x2, fail_listen_socket_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    b _main_exit

_main_listen_socket_fail_branch_end:

; configuring socket options, for now failures can be discarded

    ; SO_REUSEADDR | SO_REUSEPORT
    mov x0, x19
    mov x1, #0xFFFF
    mov x2, #0x0204
    adrp x3, opt @PAGE
    add x3, x3, opt @PAGEOFF
    mov x4, #4
    mov x16, #105
    svc #0x80

    ; SO_RCVBUF
    mov x0, x19
    mov x1, #0xFFFF
    mov x2, #0x1002
    mov x3, #30721
    mov x4, #8
    mov x16, #105
    svc #0x80

    ; SO_SNDBUF
    mov x0, x19
    mov x1, #0xFFFF
    mov x2, #0x1001
    mov x3, #30721
    mov x4, #8
    mov x16, #105
    svc #0x80

    ; TCP_FASTOPEN
    mov x0, x19
    mov x1, #6                          ; IPPROTO_TCP
    mov x2, #0x105
    adrp x3, opt @PAGE
    add x3, x3, opt @PAGEOFF
    mov x4, #4
    mov x16, #105
    svc #0x80

    ; SO_NOSIGPIPE
    mov x0, x19
    mov x1, #0xFFFF
    mov x2, #0x1022
    adrp x3, opt @PAGE
    add x3, x3, opt @PAGEOFF
    mov x4, #4
    mov x16, #105
    svc #0x80

    ; fcntl() -> F_GETFL
    mov x0, x19
    mov x1, #3                          ; F_GETFL
    mov x2, #0
    mov x16, #92
    svc #0x80
    mov x5, x0
    orr x5, x5, #0x4                      ; flags | O_NONBLOCK

    ; O_NONBLOCK
    mov x0, x19
    mov x1, #4                          ; F_SETFL
    mov x2, x5
    mov x16, #92
    svc #0x80

    ; kqueue()
    mov x16, #362
    svc #0x80

    cmp x0, #0
    bge _main_kqueue_fail_branch_end
    
_main_kqueue_fail_branch:

    mov x0, #1
    adrp x1, fail_kqueue_fd @PAGE
    add x1, x1, fail_kqueue_fd @PAGEOFF
    mov x2, fail_kqueue_fd_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    b _main_exit

_main_kqueue_fail_branch_end:

    mov x19, x0

    adrp x1, kqueue_fd @PAGE
    add x1, x1, kqueue_fd @PAGEOFF
    str w0, [x1]

    mov x25, #0

_main_create_threads_loop:

    ; space per thread:
    ; sizeof kevent[10] + sizeof connection_state[10] + 4096 extra bytes stack space

    ; adrp x26, ajkljd @PAGE
    ; add x26, x26, ajkljd @PAGEOFF
    ; ldr x25, [x26]
    mov x25, #0x2000

    ; mmap()
    mov x0, #0                          ; default thread attributes
    mov x1, x25                         ; space per threads, ~311 KB
    mov x2, #0x3                        ; PROT_READ | PROT_WRITE
    mov x3, #0x1002                     ; MAP_PRIVATE | MAP_ANON
    mov x4, #-1
    mov x5, #0
    mov x16, #197
    svc #0x80

    add x0, x0, x25                     ; points pointer to top of memory block

    ; check if mmap() < 0 -> error, crash

    ; pointer to mmap() is already return in x0
    adrp x1, _worker @PAGE
    add x1, x1, _worker @PAGEOFF
    mov x2, x19                         ; kqueue_fd
    mov x3, x0                          ; pointer to mem area
    mov x4, #0                          ; NULL = pthread_t
    mov x5, #0                          ; flags
    mov x16, #360
    svc #0x80

    add x25, x25, #1
    cmp x25, #8
    blt _main_create_threads_loop

_main_create_threads_loop_end:

    ; fall-through to loop

_main_accept_loop:

    ; accept()
    adrp x25, server_fd @PAGE
    add x25, x25, server_fd @PAGEOFF
    ldr w0, [x25]
    adrp x1, address @PAGE
    add x1, x1, address @PAGEOFF
    adrp x2, addrlen @PAGE
    add x2, x2, addrlen @PAGEOFF
    mov x16, #30

    ; check accept() errors
    
    mov x20, x0

    ; check if client_fd exceeds 65535, int16 overflow if does

    ; malloc() a pointer to connection_state, store client_fd/zeroes out fields, and call kevent.

    mov x26, sp
    sub sp, sp, #256                    ; alloc kevent

    ; EV_SET()
    str x20, [x26]                      ; client_fd
    mov x27, #-1                        ; EVFILT_READ
    strh w27, [x26, #8]
    mov x27, #0x11                      ; EV_ADD | EV_ONESHOT
    strh w27, [x26, #10]
    str wzr, [x26, #12]
    str xzr, [x26, #16]
    
    str [connection_state], [x26, #24]

    ; kevent()
    adrp x26, kqueue_fd @PAGE
    add x26, x26, kqueue_fd @PAGEOFF
    ldr w0, [x26]                       ; kqueue_fd
    add x1, sp, #256                    ; &change
    mov x2, #1
    mov x3, #0
    mov x4, #0
    mov x5, #0
    mov x16, #363
    svc #0x80

    ; check return value + err code

    b _main_accept_loop

/*
    struct kevent {
8       uintptr_t       ident;     identifier for this event
2       int16_t         filter;    filter for event
2       uint16_t        flags;     general flags
4       uint32_t        fflags;    filter-specific flags
8       intptr_t        data;      filter-specific data
8       void            *udata;    opaque user data identifier
    };*/

_main_exit:                             ; store exit code in x0 already

    mov x16, #1
    svc #0x80

    ldp x19, x20, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x25, x26, [sp], #16
    ldp x27, x28, [sp], #16
    ldp x29, x30, [sp], #16
    ret












; function representing worker threads

_worker:

    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!
    stp x27, x28, [sp, #-16]!
    stp x29, x30, [sp, #-16]!
    

; using x28 as "pointer arithmetic"/"memory access address" register, try to not pollute main sp

    sub sp, sp, #320                   ; struct kevent events[10]

    ; sub sp, sp, #2459520                ; struct connection_state temp_buf[10]

_worker_loop:

; kevent()
    adrp x25, kqueue_fd @PAGE
    add x25, x25, kqueue_fd @PAGEOFF
    ldr w0, [x25]                       ; kqueue_fd
    mov x1, #0                          ; (no changes)
    mov x2, #0
    add x3, sp, #320                    ; &events[0]
    mov x4, #10                         ; nevents
    mov x5, #0                          ; timeout
    mov x16, #363
    svc #0x80

/* let's put the complexities of error-checking for later.
    cmp x0, #0
    bge _worker_loop_kevent_fail_end

_worker_loop_kevent_fail:

    mov x0, #1
    adrp x1, fail_kevent @PAGE
    add x1, x1, fail_kevent @PAGEOFF
    mov x2, fail_kevent_len
    mov x16, #4
    svc #0x80

    b _worker_loop

_worker_loop_kevent_fail_end:*/

    mov x7, x0                          ; ev_count, for for loop

_worker_loop_loop:

    sub x7, x7, #1

    mov x26, #32

    add x28, sp, #320
    mul x27, x7, x26
    sub x28, x28, x27

    ldr x6, [x28, #24]                 ; void* udata

    ; progress check
    ldrb w0, [x6]

    cmp w0, #0
    beq _worker_loop_loop_reading
    cmp w0, #1
    beq _worker_loop_loop_parsing
    cmp w0, #2
    beq _worker_loop_loop_writing

    ; requests with progress = "DONE" will fall-through/discarded.

_worker_loop_loop_increment:

    cmp x7, #0
    bgt _worker_loop_loop

_worker_loop_loop_reading:

    ; read()
    ldr w0, [x6, #1]                    ; client_fd
    add x1, x6, #17
    ldr w5, [x6, #5]
    add x1, x1, x5                      ; &buffer[0] + bytes_read
    mov x2, #30720
    ldr w3, [x6, #5]
    sub x2, x2, x3                      ; sizeof buffer - bytes_read
    mov x16, #3
    svc #0x80

    cmp x0, #0
    bcs _worker_loop_loop_reading_read_finish

_worker_loop_loop_reading_read_success:

    ; assuming bytes_read is zeroed out
    ldr w1, [x6, #5]
    add w1, w1, w0
    str w1, [x6, #5]

    b _worker_loop_loop_increment

_worker_loop_loop_reading_read_finish:

    ; call strerror on x0, x0 has the positive version of err code, and print descrpition
    cmp x0, #35
    bne _worker_loop_loop_reading_read_err

    mov w7, #1
    strb w7, [x6]                        ; change status to PARSING

    b _worker_loop_loop_increment

_worker_loop_loop_reading_read_err:

    ; for now we're going to be aggressive and close fd on error.
    ldr w0, [x6, #1]
    bl __close_fd_64

    b _worker_loop_loop_increment

_worker_loop_loop_parsing:

    ; mainly doing checks for request validity and prepare

    b _worker_loop_loop_increment

_worker_loop_loop_writing:

    ; write()
    ldr w0, [x6, #1]
    adrp x1, file_contents_buffer @PAGE
    add x1, x1, file_contents_buffer @PAGEOFF   ; + total_sent
    adrp x3, file_contents_len @PAGE
    add x3, x3, file_contents_len @PAGEOFF
    ldr w2, [x3]
    mov x16, #4
    svc #0x80

    b _worker_loop_loop_increment















; read()
    ldr w0, [x6]
    ldr w26, [x6, #32]
    add x9, x6, #66
    mov x27, #8
    mul x25, x26, x27
    add x1, x9, x25 
    mov x25, #30720
    sub x2, x25, x26
    mov x16, #3
    svc #0x80

    ; check for errors + EAGAIN

    ldr w10, [x6, #32]
    add x10, x10, x0
    str w10, [x6, #32]

    mov x11, x6
    add x11, x11, #66
    add x11, x11, x26
    sub x11, x11, #1

    mov x12, #0
    ldrb w13, [x11]
    sub x11, x11, #1
    ldrb w14, [x11]

    cmp w13, #'\r'
    bne _worker_loop_loop_is_complete_check_1_end

_worker_loop_loop_is_complete_check_1:

    add x12, x12, #1

_worker_loop_loop_is_complete_check_1_end:

    cmp x14, #'\n'
    bne _worker_loop_loop_is_complete_check_2_end

_worker_loop_loop_is_complete_check_2:

    add x12, x12, #1

_worker_loop_loop_is_complete_check_2_end:

    cmp x12, #2
    bne _worker_loop_loop_is_not_complete_request

_worker_loop_loop_is_complete_request:

    ;

_worker_loop_loop_is_not_complete_request:

    ; technically "continue" statement so fall-through

_worker_loop_loop_is_complete_request_end:

    ;

    cmp x7, #0
    bgt _worker_loop_loop

_worker_loop_loop_end:

    b _worker_loop

_worker_exit:

    adrp x26, jjiijj @PAGE
    add x26, x26, jjiijj @PAGEOFF
    ldr x25, [x26]

    add sp, sp, x25                     ; give back what is taken

    mov x16, #1
    svc #0x80

    ldp x19, x20, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x25, x26, [sp], #16
    ldp x27, x28, [sp], #16
    ldp x29, x30, [sp], #16
    ret










__close_fd_64:                          ; input: x0

    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x16, #6
    svc #0x80

    cmp x0, #0
    beq __close_fd_64_exit

__close_fd_64_fail:

    ; this might returns ENOTSOCK for non-socket fds but who cares
    mov x1, #2                          ; SHUTRDWR: shuts both read/write
    mov x16, #134

__close_fd_64_exit:

    ldp x29, x30, [sp], #16
    ret

__ascii_to_num:                         ; (convert ascii string to number, input: x0 -> string addr, output: x0 -> number)
    ; save registers
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x1, x0                          ; moving string pointer
    mov x0, #0                          ; result = 0
    mov x3, #10                         ; multiplier

__ascii_to_num_parse_loop:
    ldrb w2, [x1], #1                   ; load byte, advance

    ; check if digit
    cmp w2, #'0'
    blt __ascii_to_num_parse_done       ; branch if cmp a, b -> (a < b) -> true
    cmp w2, #'9'
    bgt __ascii_to_num_parse_done       ; branch if cmp a, b -> (a > b) -> true

    ; result = result * 10 + (digit - '0')
    mul x0, x0, x3
    sub x2, x2, #'0'
    add x0, x0, x2

    b __ascii_to_num_parse_loop

__ascii_to_num_parse_done:
    ; restore registers & return
    ldp x29, x30, [sp], #16
    ret

__num_to_ascii:                         ; (convert number in x0 to ascii string, returns length in x0, string in nta_buffer, str addr x1)

    stp x29, x30, [sp, #-16]!
    mov x29, sp

    adrp x1, nta_buffer @PAGE
    add x1, x1, nta_buffer @PAGEOFF
    add x1, x1, #31                    ; point to end (buffer_len - 1)

    mov x2, #0                          ; length num
    mov x3, #10                         ; divisor
    mov x4, x1

    mov w5, #0
    strb w5, [x1]
    sub x1, x1, #1                      ; null terminate buffer

    cbz x0, __num_to_ascii_zero_case    ; compare, then jump if x0 = 0

__num_to_ascii_loop:

    cbz x0, __num_to_ascii_exit         ; compare, then jump if x0 = 0

    udiv x6, x0, x3                     ; x6 = x0 / 10
    msub x7, x6, x3, x0                 ; x7 = x0 % 10 (rem of x0 / 10)
    add x7, x7, #'0'                    ; convert to ascii
    strb w7, [x1]                       ; store byte
    sub x1, x1, #1                      ; move back
    add x2, x2, #1                      ; increment length
    mov x0, x6                          ; quotient becomes new number
    b __num_to_ascii_loop

__num_to_ascii_zero_case:
    mov x5, #'0'
    strb w5, [x1]
    sub x1, x1, #1
    mov x2, #1
    b __num_to_ascii_exit

__num_to_ascii_exit:
    add x1, x1, #1                      ; point to first char

    ; null terminates string
    ; mov x6, #'\0'
    ; strb w6, [x1, x2]
    ; add x2, x2, #1

    mov x0, x2                          ; save length in x0
    ; restore registers & return
    ldp x29, x30, [sp], #16
    ret

__clear_buf:                            ; input: x0 -> buffer addr, x1 -> buffer len; output: x0 -> buffer addr
    
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov w3, #0

__clear_buf_loop:

    strb w3, [x0], #1                   ; set every byte to 0b0 in a recursive loop
    subs x1, x1, #1
    bne __clear_buf_loop

__clear_buf_loop_end:

    ldp x29, x30, [sp], #16
    ret

__strerror:                             ; input: x0 -> error code, output: x0 -> error str addr, x1 -> error str len
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ; check input against accepted/recognized error codes, otherwise return unknown
    cmp x0, #0
    beq __strerror_err_0
    cmp x0, #1
    beq __strerror_err_1
    cmp x0, #2
    beq __strerror_err_2
    cmp x0, #3
    beq __strerror_err_3
    cmp x0, #4
    beq __strerror_err_4
    cmp x0, #5
    beq __strerror_err_5
    cmp x0, #6
    beq __strerror_err_6
    cmp x0, #7
    beq __strerror_err_7
    cmp x0, #8
    beq __strerror_err_8
    cmp x0, #9
    beq __strerror_err_9
    cmp x0, #10
    beq __strerror_err_10
    cmp x0, #11
    beq __strerror_err_11
    cmp x0, #12
    beq __strerror_err_12
    cmp x0, #13
    beq __strerror_err_13
    cmp x0, #14
    beq __strerror_err_14
    cmp x0, #15
    beq __strerror_err_15
    cmp x0, #16
    beq __strerror_err_16
    cmp x0, #17
    beq __strerror_err_17
    cmp x0, #18
    beq __strerror_err_18
    cmp x0, #19
    beq __strerror_err_19
    cmp x0, #20
    beq __strerror_err_20
    cmp x0, #21
    beq __strerror_err_21
    cmp x0, #22
    beq __strerror_err_22
    cmp x0, #23
    beq __strerror_err_23
    cmp x0, #24
    beq __strerror_err_24
    cmp x0, #25
    beq __strerror_err_25
    cmp x0, #26
    beq __strerror_err_26
    cmp x0, #27
    beq __strerror_err_27
    cmp x0, #28
    beq __strerror_err_28
    cmp x0, #29
    beq __strerror_err_29
    cmp x0, #30
    beq __strerror_err_30
    cmp x0, #31
    beq __strerror_err_31
    cmp x0, #32
    beq __strerror_err_32
    cmp x0, #33
    beq __strerror_err_33
    cmp x0, #34
    beq __strerror_err_34
    cmp x0, #35
    beq __strerror_err_35
    cmp x0, #36
    beq __strerror_err_36
    cmp x0, #37
    beq __strerror_err_37
    cmp x0, #38
    beq __strerror_err_38
    cmp x0, #39
    beq __strerror_err_39
    cmp x0, #40
    beq __strerror_err_40
    cmp x0, #41
    beq __strerror_err_41
    cmp x0, #42
    beq __strerror_err_42
    cmp x0, #43
    beq __strerror_err_43
    cmp x0, #44
    beq __strerror_err_44
    cmp x0, #45
    beq __strerror_err_45
    cmp x0, #46
    beq __strerror_err_46
    cmp x0, #47
    beq __strerror_err_47
    cmp x0, #48
    beq __strerror_err_48
    cmp x0, #49
    beq __strerror_err_49
    cmp x0, #50
    beq __strerror_err_50
    cmp x0, #51
    beq __strerror_err_51
    cmp x0, #52
    beq __strerror_err_52
    cmp x0, #53
    beq __strerror_err_53
    cmp x0, #54
    beq __strerror_err_54
    cmp x0, #55
    beq __strerror_err_55
    cmp x0, #56
    beq __strerror_err_56
    cmp x0, #57
    beq __strerror_err_57
    cmp x0, #58
    beq __strerror_err_58
    cmp x0, #59
    beq __strerror_err_59
    cmp x0, #60
    beq __strerror_err_60
    cmp x0, #61
    beq __strerror_err_61
    cmp x0, #62
    beq __strerror_err_62
    cmp x0, #63
    beq __strerror_err_63
    cmp x0, #64
    beq __strerror_err_64
    cmp x0, #65
    beq __strerror_err_65
    cmp x0, #66
    beq __strerror_err_66
    cmp x0, #67
    beq __strerror_err_67
    cmp x0, #68
    beq __strerror_err_68
    cmp x0, #69
    beq __strerror_err_69
    cmp x0, #70
    beq __strerror_err_70
    cmp x0, #71
    beq __strerror_err_71
    cmp x0, #72
    beq __strerror_err_72
    cmp x0, #73
    beq __strerror_err_73
    cmp x0, #74
    beq __strerror_err_74
    cmp x0, #75
    beq __strerror_err_75
    cmp x0, #76
    beq __strerror_err_76
    cmp x0, #77
    beq __strerror_err_77
    cmp x0, #78
    beq __strerror_err_78
    cmp x0, #79
    beq __strerror_err_79
    cmp x0, #80
    beq __strerror_err_80
    cmp x0, #81
    beq __strerror_err_81
    cmp x0, #82
    beq __strerror_err_82
    cmp x0, #83
    beq __strerror_err_83
    cmp x0, #84
    beq __strerror_err_84
    cmp x0, #85
    beq __strerror_err_85
    cmp x0, #86
    beq __strerror_err_86
    cmp x0, #87
    beq __strerror_err_87
    cmp x0, #88
    beq __strerror_err_88
    cmp x0, #89
    beq __strerror_err_89
    cmp x0, #90
    beq __strerror_err_90
    cmp x0, #91
    beq __strerror_err_91
    cmp x0, #92
    beq __strerror_err_92
    cmp x0, #93
    beq __strerror_err_93
    cmp x0, #94
    beq __strerror_err_94
    cmp x0, #95
    beq __strerror_err_95
    cmp x0, #96
    beq __strerror_err_96
    cmp x0, #97
    beq __strerror_err_97
    cmp x0, #98
    beq __strerror_err_98
    cmp x0, #99
    beq __strerror_err_99
    cmp x0, #100
    beq __strerror_err_100
    cmp x0, #101
    beq __strerror_err_101
    cmp x0, #102
    beq __strerror_err_102
    cmp x0, #103
    beq __strerror_err_103
    cmp x0, #104
    beq __strerror_err_104
    cmp x0, #105
    beq __strerror_err_105
    cmp x0, #106
    beq __strerror_err_106
    cmp x0, #107
    beq __strerror_err_107

    b __strerror_err_unknown

__strerror_err_0:                       ; 0: no errors

    adrp x0, err_str_0 @PAGE
    add x0, x0, err_str_0 @PAGEOFF
    mov x1, #12
    b __strerror_exit

__strerror_err_1:                       ; EPERM

    adrp x0, err_str_1 @PAGE
    add x0, x0, err_str_1 @PAGEOFF
    mov x1, #23
    b __strerror_exit

__strerror_err_2:                       ; ENOENT

    adrp x0, err_str_2 @PAGE
    add x0, x0, err_str_2 @PAGEOFF
    mov x1, #26
    b __strerror_exit

__strerror_err_3:                       ; ESRCH

    adrp x0, err_str_3 @PAGE
    add x0, x0, err_str_3 @PAGEOFF
    mov x1, #15
    b __strerror_exit

__strerror_err_4:                       ; EINTR

    adrp x0, err_str_4 @PAGE
    add x0, x0, err_str_4 @PAGEOFF
    mov x1, #22
    b __strerror_exit

__strerror_err_5:                       ; EIO

    adrp x0, err_str_5 @PAGE
    add x0, x0, err_str_5 @PAGEOFF
    mov x1, #17
    b __strerror_exit

__strerror_err_6:                       ; ENXIO

    adrp x0, err_str_6 @PAGE
    add x0, x0, err_str_6 @PAGEOFF
    mov x1, #21
    b __strerror_exit

__strerror_err_7:                       ; E2BIG

    adrp x0, err_str_7 @PAGE
    add x0, x0, err_str_7 @PAGEOFF
    mov x1, #22
    b __strerror_exit

__strerror_err_8:                       ; ENOEXEC

    adrp x0, err_str_8 @PAGE
    add x0, x0, err_str_8 @PAGEOFF
    mov x1, #18
    b __strerror_exit

__strerror_err_9:                       ; EBADF

    adrp x0, err_str_9 @PAGE
    add x0, x0, err_str_9 @PAGEOFF
    mov x1, #19
    b __strerror_exit

__strerror_err_10:                      ; ECHILD

    adrp x0, err_str_10 @PAGE
    add x0, x0, err_str_10 @PAGEOFF
    mov x1, #17
    b __strerror_exit

__strerror_err_11:                      ; EDEADLK

    adrp x0, err_str_11 @PAGE
    add x0, x0, err_str_11 @PAGEOFF
    mov x1, #24
    b __strerror_exit

__strerror_err_12:                      ; ENOMEM

    adrp x0, err_str_12 @PAGE
    add x0, x0, err_str_12 @PAGEOFF
    mov x1, #22
    b __strerror_exit

__strerror_err_13:                      ; EACCES

    adrp x0, err_str_13 @PAGE
    add x0, x0, err_str_13 @PAGEOFF
    mov x1, #17
    b __strerror_exit

__strerror_err_14:                      ; EFAULT

    adrp x0, err_str_14 @PAGE
    add x0, x0, err_str_14 @PAGEOFF
    mov x1, #11
    b __strerror_exit

__strerror_err_15:                      ; ENOTBLK

    adrp x0, err_str_15 @PAGE
    add x0, x0, err_str_15 @PAGEOFF
    mov x1, #21
    b __strerror_exit

__strerror_err_16:                      ; EBUSY

    adrp x0, err_str_16 @PAGE
    add x0, x0, err_str_16 @PAGEOFF
    mov x1, #13
    b __strerror_exit

__strerror_err_17:                      ; EEXIST

    adrp x0, err_str_17 @PAGE
    add x0, x0, err_str_17 @PAGEOFF
    mov x1, #11
    b __strerror_exit

__strerror_err_18:                      ; EXDEV

    adrp x0, err_str_18 @PAGE
    add x0, x0, err_str_18 @PAGEOFF
    mov x1, #17
    b __strerror_exit

__strerror_err_19:                      ; ENODEV

    adrp x0, err_str_19 @PAGE
    add x0, x0, err_str_19 @PAGEOFF
    mov x1, #31
    b __strerror_exit

__strerror_err_20:                      ; ENOTDIR

    adrp x0, err_str_20 @PAGE
    add x0, x0, err_str_20 @PAGEOFF
    mov x1, #16
    b __strerror_exit

__strerror_err_21:                      ; EISDIR

    adrp x0, err_str_21 @PAGE
    add x0, x0, err_str_21 @PAGEOFF
    mov x1, #14
    b __strerror_exit

__strerror_err_22:                      ; EINVAL

    adrp x0, err_str_22 @PAGE
    add x0, x0, err_str_22 @PAGEOFF
    mov x1, #16
    b __strerror_exit

__strerror_err_23:                      ; ENFILE

    adrp x0, err_str_23 @PAGE
    add x0, x0, err_str_23 @PAGEOFF
    mov x1, #31
    b __strerror_exit

__strerror_err_24:                      ; EMFILE

    adrp x0, err_str_24 @PAGE
    add x0, x0, err_str_24 @PAGEOFF
    mov x1, #20
    b __strerror_exit

__strerror_err_25:                      ; ENOTTY

    adrp x0, err_str_25 @PAGE
    add x0, x0, err_str_25 @PAGEOFF
    mov x1, #29
    b __strerror_exit

__strerror_err_26:                      ; ETXTBSY

    adrp x0, err_str_26 @PAGE
    add x0, x0, err_str_26 @PAGEOFF
    mov x1, #14
    b __strerror_exit

__strerror_err_27:                      ; EFBIG

    adrp x0, err_str_27 @PAGE
    add x0, x0, err_str_27 @PAGEOFF
    mov x1, #14
    b __strerror_exit

__strerror_err_28:                      ; ENOSPC

    adrp x0, err_str_28 @PAGE
    add x0, x0, err_str_28 @PAGEOFF
    mov x1, #24
    b __strerror_exit

__strerror_err_29:                      ; ESPIPE

    adrp x0, err_str_29 @PAGE
    add x0, x0, err_str_29 @PAGEOFF
    mov x1, #12
    b __strerror_exit

__strerror_err_30:                      ; EROFS

    adrp x0, err_str_30 @PAGE
    add x0, x0, err_str_30 @PAGEOFF
    mov x1, #22
    b __strerror_exit

__strerror_err_31:                      ; EMLINK

    adrp x0, err_str_31 @PAGE
    add x0, x0, err_str_31 @PAGEOFF
    mov x1, #14
    b __strerror_exit

__strerror_err_32:                      ; EPIPE

    adrp x0, err_str_32 @PAGE
    add x0, x0, err_str_32 @PAGEOFF
    mov x1, #11
    b __strerror_exit

__strerror_err_33:                      ; EDOM

    adrp x0, err_str_33 @PAGE
    add x0, x0, err_str_33 @PAGEOFF
    mov x1, #33
    b __strerror_exit

__strerror_err_34:                      ; ERANGE

    adrp x0, err_str_34 @PAGE
    add x0, x0, err_str_34 @PAGEOFF
    mov x1, #16
    b __strerror_exit

__strerror_err_35:                      ; EAGAIN

    adrp x0, err_str_35 @PAGE
    add x0, x0, err_str_35 @PAGEOFF
    mov x1, #31
    b __strerror_exit

__strerror_err_36:                      ; EINPROGRESS

    adrp x0, err_str_36 @PAGE
    add x0, x0, err_str_36 @PAGEOFF
    mov x1, #24
    b __strerror_exit

__strerror_err_37:                      ; EALREADY

    adrp x0, err_str_37 @PAGE
    add x0, x0, err_str_37 @PAGEOFF
    mov x1, #27
    b __strerror_exit

__strerror_err_38:                      ; ENOTSOCK

    adrp x0, err_str_38 @PAGE
    add x0, x0, err_str_38 @PAGEOFF
    mov x1, #28
    b __strerror_exit

__strerror_err_39:                      ; EDESTADDRREQ

    adrp x0, err_str_39 @PAGE
    add x0, x0, err_str_39 @PAGEOFF
    mov x1, #26
    b __strerror_exit

__strerror_err_40:                      ; EMSGSIZE

    adrp x0, err_str_40 @PAGE
    add x0, x0, err_str_40 @PAGEOFF
    mov x1, #16
    b __strerror_exit

__strerror_err_41:                      ; EPROTOTYPE

    adrp x0, err_str_41 @PAGE
    add x0, x0, err_str_41 @PAGEOFF
    mov x1, #29
    b __strerror_exit

__strerror_err_42:                      ; ENOPROTOOPT

    adrp x0, err_str_42 @PAGE
    add x0, x0, err_str_42 @PAGEOFF
    mov x1, #20
    b __strerror_exit

__strerror_err_43:                      ; EPROTONOSUPPORT

    adrp x0, err_str_43 @PAGE
    add x0, x0, err_str_43 @PAGEOFF
    mov x1, #23
    b __strerror_exit

__strerror_err_44:                      ; ESOCKTNOSUPPORT

    adrp x0, err_str_44 @PAGE
    add x0, x0, err_str_44 @PAGEOFF
    mov x1, #24
    b __strerror_exit

__strerror_err_45:                      ; ENOTSUP

    adrp x0, err_str_45 @PAGE
    add x0, x0, err_str_45 @PAGEOFF
    mov x1, #21
    b __strerror_exit

__strerror_err_46:                      ; EPFNOSUPPORT

    adrp x0, err_str_46 @PAGE
    add x0, x0, err_str_46 @PAGEOFF
    mov x1, #28
    b __strerror_exit

__strerror_err_47:                      ; EAFNOSUPPORT

    adrp x0, err_str_47 @PAGE
    add x0, x0, err_str_47 @PAGEOFF
    mov x1, #44
    b __strerror_exit

__strerror_err_48:                      ; EADDRINUSE

    adrp x0, err_str_48 @PAGE
    add x0, x0, err_str_48 @PAGEOFF
    mov x1, #22
    b __strerror_exit

__strerror_err_49:                      ; EADDRNOTAVAIL

    adrp x0, err_str_49 @PAGE
    add x0, x0, err_str_49 @PAGEOFF
    mov x1, #28
    b __strerror_exit

__strerror_err_50:                      ; ENETDOWN

    adrp x0, err_str_50 @PAGE
    add x0, x0, err_str_50 @PAGEOFF
    mov x1, #14
    b __strerror_exit

__strerror_err_51:                      ; ENETUNREACH

    adrp x0, err_str_51 @PAGE
    add x0, x0, err_str_51 @PAGEOFF
    mov x1, #21
    b __strerror_exit

__strerror_err_52:                      ; ENETRESET

    adrp x0, err_str_52 @PAGE
    add x0, x0, err_str_52 @PAGEOFF
    mov x1, #33
    b __strerror_exit

__strerror_err_53:                      ; ECONNABORTED

    adrp x0, err_str_53 @PAGE
    add x0, x0, err_str_53 @PAGEOFF
    mov x1, #32
    b __strerror_exit

__strerror_err_54:                      ; ECONNRESET

    adrp x0, err_str_54 @PAGE
    add x0, x0, err_str_54 @PAGEOFF
    mov x1, #23
    b __strerror_exit

__strerror_err_55:                      ; ENOBUFS

    adrp x0, err_str_55 @PAGE
    add x0, x0, err_str_55 @PAGEOFF
    mov x1, #26
    b __strerror_exit

__strerror_err_56:                      ; EISCONN

    adrp x0, err_str_56 @PAGE
    add x0, x0, err_str_56 @PAGEOFF
    mov x1, #27
    b __strerror_exit

__strerror_err_57:                      ; ENOTCONN

    adrp x0, err_str_57 @PAGE
    add x0, x0, err_str_57 @PAGEOFF
    mov x1, #21
    b __strerror_exit

__strerror_err_58:                      ; ESHUTDOWN

    adrp x0, err_str_58 @PAGE
    add x0, x0, err_str_58 @PAGEOFF
    mov x1, #31
    b __strerror_exit

__strerror_err_59:                      ; ETOOMANYREFS

    adrp x0, err_str_59 @PAGE
    add x0, x0, err_str_59 @PAGEOFF
    mov x1, #35
    b __strerror_exit

__strerror_err_60:                      ; ETIMEDOUT

    adrp x0, err_str_60 @PAGE
    add x0, x0, err_str_60 @PAGEOFF
    mov x1, #18
    b __strerror_exit

__strerror_err_61:                      ; ECONNREFUSED

    adrp x0, err_str_61 @PAGE
    add x0, x0, err_str_61 @PAGEOFF
    mov x1, #18
    b __strerror_exit

__strerror_err_62:                      ; ELOOP

    adrp x0, err_str_62 @PAGE
    add x0, x0, err_str_62 @PAGEOFF
    mov x1, #33
    b __strerror_exit

__strerror_err_63:                      ; ENAMETOOLONG

    adrp x0, err_str_63 @PAGE
    add x0, x0, err_str_63 @PAGEOFF
    mov x1, #18
    b __strerror_exit

__strerror_err_64:                      ; EHOSTDOWN

    adrp x0, err_str_64 @PAGE
    add x0, x0, err_str_64 @PAGEOFF
    mov x1, #12
    b __strerror_exit

__strerror_err_65:                      ; EHOSTUNREACH

    adrp x0, err_str_65 @PAGE
    add x0, x0, err_str_65 @PAGEOFF
    mov x1, #16
    b __strerror_exit

__strerror_err_66:                      ; ENOTEMPTY

    adrp x0, err_str_66 @PAGE
    add x0, x0, err_str_66 @PAGEOFF
    mov x1, #18
    b __strerror_exit

__strerror_err_67:                      ; EPROCLIM

    adrp x0, err_str_67 @PAGE
    add x0, x0, err_str_67 @PAGEOFF
    mov x1, #18
    b __strerror_exit

__strerror_err_68:                      ; EUSERS

    adrp x0, err_str_68 @PAGE
    add x0, x0, err_str_68 @PAGEOFF
    mov x1, #14
    b __strerror_exit

__strerror_err_69:                      ; EDQUOT

    adrp x0, err_str_69 @PAGE
    add x0, x0, err_str_69 @PAGEOFF
    mov x1, #18
    b __strerror_exit

__strerror_err_70:                      ; ESTALE

    adrp x0, err_str_70 @PAGE
    add x0, x0, err_str_70 @PAGEOFF
    mov x1, #20
    b __strerror_exit

__strerror_err_71:                      ; EREMOTE

    adrp x0, err_str_71 @PAGE
    add x0, x0, err_str_71 @PAGEOFF
    mov x1, #32
    b __strerror_exit

__strerror_err_72:                      ; EBADRPC

    adrp x0, err_str_72 @PAGE
    add x0, x0, err_str_72 @PAGEOFF
    mov x1, #18
    b __strerror_exit

__strerror_err_73:                      ; ERPCMISMATCH

    adrp x0, err_str_73 @PAGE
    add x0, x0, err_str_73 @PAGEOFF
    mov x1, #17
    b __strerror_exit

__strerror_err_74:                      ; EPROGUNAVAIL

    adrp x0, err_str_74 @PAGE
    add x0, x0, err_str_74 @PAGEOFF
    mov x1, #21
    b __strerror_exit

__strerror_err_75:                      ; EPROGMISMATCH

    adrp x0, err_str_75 @PAGE
    add x0, x0, err_str_75 @PAGEOFF
    mov x1, #21
    b __strerror_exit

__strerror_err_76:                      ; EPROCUNAVAIL

    adrp x0, err_str_76 @PAGE
    add x0, x0, err_str_76 @PAGEOFF
    mov x1, #26
    b __strerror_exit

__strerror_err_77:                      ; ENOLCK

    adrp x0, err_str_77 @PAGE
    add x0, x0, err_str_77 @PAGEOFF
    mov x1, #19
    b __strerror_exit

__strerror_err_78:                      ; ENOSYS

    adrp x0, err_str_78 @PAGE
    add x0, x0, err_str_78 @PAGEOFF
    mov x1, #23
    b __strerror_exit

__strerror_err_79:                      ; EFTYPE

    adrp x0, err_str_79 @PAGE
    add x0, x0, err_str_79 @PAGEOFF
    mov x1, #31
    b __strerror_exit

__strerror_err_80:                      ; EAUTH

    adrp x0, err_str_80 @PAGE
    add x0, x0, err_str_80 @PAGEOFF
    mov x1, #19
    b __strerror_exit

__strerror_err_81:                      ; ENEEDAUTH

    adrp x0, err_str_81 @PAGE
    add x0, x0, err_str_81 @PAGEOFF
    mov x1, #18
    b __strerror_exit

__strerror_err_82:                      ; EPWROFF

    adrp x0, err_str_82 @PAGE
    add x0, x0, err_str_82 @PAGEOFF
    mov x1, #19
    b __strerror_exit

__strerror_err_83:                      ; EDEVERR

    adrp x0, err_str_83 @PAGE
    add x0, x0, err_str_83 @PAGEOFF
    mov x1, #12
    b __strerror_exit

__strerror_err_84:                      ; EOVERFLOW

    adrp x0, err_str_84 @PAGE
    add x0, x0, err_str_84 @PAGEOFF
    mov x1, #39
    b __strerror_exit

__strerror_err_85:                      ; EBADEXEC

    adrp x0, err_str_85 @PAGE
    add x0, x0, err_str_85 @PAGEOFF
    mov x1, #32
    b __strerror_exit

__strerror_err_86:                      ; EBADARCH

    adrp x0, err_str_86  @PAGE
    add x0, x0, err_str_86 @PAGEOFF
    mov x1, #27
    b __strerror_exit

__strerror_err_87:                      ; ESHLIBVERS

    adrp x0, err_str_87 @PAGE
    add x0, x0, err_str_87 @PAGEOFF
    mov x1, #30
    b __strerror_exit

__strerror_err_88:                      ; EBADMACHO

    adrp x0, err_str_88 @PAGE
    add x0, x0, err_str_88 @PAGEOFF
    mov x1, #20
    b __strerror_exit

__strerror_err_89:                      ; ECANCELED

    adrp x0, err_str_89 @PAGE
    add x0, x0, err_str_89 @PAGEOFF
    mov x1, #18
    b __strerror_exit

__strerror_err_90:                      ; EIDRM

    adrp x0, err_str_90 @PAGE
    add x0, x0, err_str_90 @PAGEOFF
    mov x1, #18
    b __strerror_exit

__strerror_err_91:                      ; ENOMSG

    adrp x0, err_str_91 @PAGE
    add x0, x0, err_str_91 @PAGEOFF
    mov x1, #28
    b __strerror_exit

__strerror_err_92:                      ; EILSEQ

    adrp x0, err_str_92 @PAGE
    add x0, x0, err_str_92 @PAGEOFF
    mov x1, #20
    b __strerror_exit

__strerror_err_93:                      ; ENOATTR

    adrp x0, err_str_93 @PAGE
    add x0, x0, err_str_93 @PAGEOFF
    mov x1, #19
    b __strerror_exit

__strerror_err_94:                      ; EBADMSG

    adrp x0, err_str_94 @PAGE
    add x0, x0, err_str_94 @PAGEOFF
    mov x1, #11
    b __strerror_exit

__strerror_err_95:                      ; EMULTIHOP

    adrp x0, err_str_95 @PAGE
    add x0, x0, err_str_95 @PAGEOFF
    mov x1, #20
    b __strerror_exit

__strerror_err_96:                      ; ENODATA

    adrp x0, err_str_96 @PAGE
    add x0, x0, err_str_96 @PAGEOFF
    mov x1, #31
    b __strerror_exit

__strerror_err_97:                      ; ENOLINK

    adrp x0, err_str_97 @PAGE
    add x0, x0, err_str_97 @PAGEOFF
    mov x1, #19
    b __strerror_exit

__strerror_err_98:                      ; ENOSR

    adrp x0, err_str_98 @PAGE
    add x0, x0, err_str_98 @PAGEOFF
    mov x1, #20
    b __strerror_exit

__strerror_err_99:                      ; ENOSTR

    adrp x0, err_str_99 @PAGE
    add x0, x0, err_str_99 @PAGEOFF
    mov x1, #14
    b __strerror_exit

__strerror_err_100:                     ; EPROTO

    adrp x0, err_str_100 @PAGE
    add x0, x0, err_str_100 @PAGEOFF
    mov x1, #14
    b __strerror_exit

__strerror_err_101:                     ; ETIME

    adrp x0, err_str_101 @PAGE
    add x0, x0, err_str_101 @PAGEOFF
    mov x1, #21
    b __strerror_exit

__strerror_err_102:                     ; EOPNOTSUPP

    adrp x0, err_str_102 @PAGE
    add x0, x0, err_str_102 @PAGEOFF
    mov x1, #31
    b __strerror_exit

__strerror_err_103:                     ; ENOPOLICY

    adrp x0, err_str_103 @PAGE
    add x0, x0, err_str_103 @PAGEOFF
    mov x1, #16
    b __strerror_exit

__strerror_err_104:                     ; ENOTRECOVERABLE

    adrp x0, err_str_104 @PAGE
    add x0, x0, err_str_104 @PAGEOFF
    mov x1, #20
    b __strerror_exit

__strerror_err_105:                     ; EOWNERDEAD

    adrp x0, err_str_105 @PAGE
    add x0, x0, err_str_105 @PAGEOFF
    mov x1, #19
    b __strerror_exit

__strerror_err_106:                     ; EQFULL

    adrp x0, err_str_106 @PAGE
    add x0, x0, err_str_106 @PAGEOFF
    mov x1, #32
    b __strerror_exit

__strerror_err_107:                     ; ENOTCAPABLE

    adrp x0, err_str_107 @PAGE
    add x0, x0, err_str_107 @PAGEOFF
    mov x1, #25
    b __strerror_exit

__strerror_err_unknown:                 ; unrecognized errors

    adrp x0, err_str_unknown @PAGE
    add x0, x0, err_str_unknown @PAGEOFF
    mov x1, #15
    b __strerror_exit

__strerror_exit:

    ldp x29, x30, [sp], #16
    ret

.section __DATA, __data

; structs

.align 4
    address:
        .byte 16                        ; sin_len
        .byte 2                         ; sin_family
        .short 0x5000                   ; sin_port
        .word 0                         ; sin_addr
        .space 8                        ; sin_zero

; variables

.align 1
    addrlen: .word 16

.align 2
    server_fd: .word 0

.align 2
    kqueue_fd: .word 0

.align 2
    file_contents_len: .word 0




; DO NOT MESS WITH THESE NUMBERS

.align 3
    ajkljd: .quad 311856
    jjiijj: .quad 307760

.section __DATA, __const

    http_header_1: .asciz "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: "
    http_header_2: .asciz "\r\nConnection: close\r\nX-Content-Type-Options: nosniff\r\nX-Frame-Options: DENY\r\nX-XSS-Protection: 1; mode=block\r\n\r\n"
    http_header_1_len = . - http_header_1
    http_header_2_len = . - http_header_2

    ; file_contents: .asciz "<!--Basic HTML file for server to serve-->\n<!DOCTYPE html>\n<html>\n<head>\n<title>Website in Assembly</title>\n<meta charset=\"UTF-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n</head>\n<body>\n<h1>It works!</h1>\n<p>This is a website made from pure Assembly. No C/C++ functions. No frameworks. No external modules/languages. A singular, think and dense .s file. Just pure insanity and CPU instructions.</p>\n</body>\n</html>"

    resp: .asciz "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: 433\r\nConnection: close\r\nX-Content-Type-Options: nosniff\r\nX-Frame-Options: DENY\r\nX-XSS-Protection: 1; mode=block\r\n\r\n<!--Basic HTML file for server to serve--><!DOCTYPE html><html><head><title>Website in Assembly</title><meta charset=\"UTF-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\"></head><body><h1>It works!</h1><p>This is a website made from pure Assembly. No C/C++ functions. No frameworks. No external modules/languages. A singular, think and dense .s file. Just pure insanity and CPU instructions.</p></body></html>"
    resp_len = . - resp

    ; status messages

    msg_before_accept: .asciz "Waiting...\n"

    msg_send_success: .asciz "Successful data transmission to the client.\n"
    msg_send_success_len = . - msg_send_success

    msg_send_none: .asciz "0 bytes sent to the client.\n"
    msg_send_none_len = . - msg_send_none

    msg_show_sent_bytes: .asciz "Successfully sent (bytes): "
    msg_show_sent_bytes_len = . - msg_show_sent_bytes

    msg_show_sent_bytes_: .asciz "Failed to send complete response: "
    msg_show_sent_bytes_len_ = . - msg_show_sent_bytes_

    ; error messages
    fail_create_socket: .asciz "Failed to establish socket on server side.\n"
    fail_create_socket_len = . - fail_create_socket

    fail_bind_socket: .asciz "Failed to bind server side socket.\n"
    fail_bind_socket_len = . - fail_bind_socket

    fail_listen_socket: .asciz "Failed to enable listening on server side socket.\n"
    fail_listen_socket_len = . - fail_listen_socket

    fail_accept_conn: .asciz "Failed to establish socket on client side.\n"
    fail_accept_conn_len = . - fail_accept_conn

    fail_read_request: .asciz "General read error encountered while trying to read client's request.\n"
    fail_read_request_len = . - fail_read_request

    fail_request_overflow: .asciz "A client's request might trigger a buffer overflow.\n"
    fail_request_overflow_len = . - fail_request_overflow

    fail_client_disconnected: .asciz "A client is disconnected from the server.\n"
    fail_client_disconnected_len = . - fail_client_disconnected

    fail_send_data: .asciz "A client failed to receive data. Tries: \n"
    fail_send_data_len = . - fail_send_data

    fail_send_data_max_retries: .asciz "Failed to send data after retries: "
    fail_send_data_max_retries_len = . - fail_send_data_max_retries

    fail_kqueue_fd: .asciz "Failed to initialize kqueue."
    fail_kqueue_fd_len = . - fail_kqueue_fd

    fail_kevent: .asciz "kevent() failed. Continuing..."
    fail_kevent_len = . - fail_kevent

    fail_load_file: .asciz "Failed to open file "
    fail_load_file_len = . - fail_load_file

    fail_get_file_info: .asciz "Failed to retrieve file information."
    fail_get_file_info_len = . - fail_get_file_info

    fail_file_empty: .asciz "Specified file is empty"
    fail_file_empty_len = . - fail_file_empty

    fail_read_file: .asciz "Failed to read file."
    fail_read_file_len = . - fail_read_file

; messages for strerror(), supports errno = 1 - 35, 41 - 66
; general/IO errors
    err_str_0: .ascii "No errors: 0"                                     ; 0
    err_str_1: .ascii "Operation not permitted"                          ; EPERM
    err_str_2: .ascii "No such file or directory"                        ; ENOENT
    err_str_3: .ascii "No such process"                                  ; ESRCH
    err_str_4: .ascii "Interrupted system call"                          ; EINTR
    err_str_5: .ascii "Input/output error"                               ; EIO
    err_str_6: .ascii "Device not configured"                            ; ENXIO
    err_str_7: .ascii "Argument list too long"                           ; E2BIG
    err_str_8: .ascii "Exec format error"                                ; ENOEXEC
    err_str_9: .ascii "Bad file descriptor"                              ; EBADF
    err_str_10: .ascii "No child processes"                              ; ECHILD
    err_str_11: .ascii "Resource deadlock avoided"                       ; EDEADLK
    err_str_12: .ascii "Cannot allocate memory"                          ; ENOMEM
    err_str_13: .ascii "Permission denied"                               ; EACCES
    err_str_14: .ascii "Bad address"                                     ; EFAULT
    err_str_15: .ascii "Block device required"                           ; ENOTBLK
    err_str_16: .ascii "Resource busy"                                   ; EBUSY
    err_str_17: .ascii "File exists"                                     ; EEXIST
    err_str_18: .ascii "Cross-device link"                               ; EXDEV
    err_str_19: .ascii "Operation not supported by device"               ; ENODEV
    err_str_20: .ascii "Not a directory"                                 ; ENOTDIR
    err_str_21: .ascii "Is a directory"                                  ; EISDIR
    err_str_22: .ascii "Invalid argument"                                ; EINVAL
    err_str_23: .ascii "Too many open files in system"                   ; ENFILE
    err_str_24: .ascii "Too many open files"                             ; EMFILE
    err_str_25: .ascii "Inappropriate ioctl for device"                  ; ENOTTY
    err_str_26: .ascii "Text file busy"                                  ; ETXTBSY
    err_str_27: .ascii "File too large"                                  ; EFBIG
    err_str_28: .ascii "No space left on device"                         ; ENOSPC
    err_str_29: .ascii "Illegal seek"                                    ; ESPIPE
    err_str_30: .ascii "Read-only file system"                           ; EROFS
    err_str_31: .ascii "Too many links"                                  ; EMLINK
    err_str_32: .ascii "Broken pipe"                                     ; EPIPE
    err_str_33: .ascii "Numerical argument out of domain"                ; EDOM
    err_str_34: .ascii "Result too large"                                ; ERANGE
    err_str_35: .ascii "Resource temporarily unavailable"                ; EAGAIN
    err_str_36: .ascii "Operation now in progress"                       ; EINPROGRESS
;
    err_str_37: .ascii "Operation already in progress"                   ; EALREADY
    err_str_38: .ascii "Socket operation on non-socket"                  ; ENOTSOCK
    err_str_39: .ascii "Destination address required"                    ; EDESTADDRREQ
    err_str_40: .ascii "Message too long"                                ; EMSGSIZE
; protocol/socket errors
    err_str_41: .ascii "Protocol wrong type for socket"                  ; EPROTOTYPE
    err_str_42: .ascii "Protocol not available"                          ; ENOPROTOOPT
    err_str_43: .ascii "Protocol not supported"                          ; EPROTONOSUPPORT
    err_str_44: .ascii "Socket type not supported"                       ; ESOCKTNOSUPPORT
    err_str_45: .ascii "Operation not supported"                         ; ENOTSUP
    err_str_46: .ascii "Protocol family not supported"                   ; EPFNOSUPPORT
    err_str_47: .ascii "Address family not supported by protocol family" ; EAFNOSUPPORT
; networking errors
    err_str_48: .ascii "Address already in use"                          ; EADDRINUSE
    err_str_49: .ascii "Can't assign requested address"                  ; EADDRNOTAVAIL
    err_str_50: .ascii "Network is down"                                 ; ENETDOWN
    err_str_51: .ascii "Network is unreachable"                          ; ENETUNREACH
    err_str_52: .ascii "Network dropped connection on reset"             ; ENETRESET
    err_str_53: .ascii "Software caused connection abort"                ; ECONNABORTED
    err_str_54: .ascii "Connection reset by peer"                        ; ECONNRESET
    err_str_55: .ascii "No buffer space available"                       ; ENOBUFS
    err_str_56: .ascii "Socket is already connected"                     ; EISCONN
    err_str_57: .ascii "Socket is not connected"                         ; ENOTCONN
    err_str_58: .ascii "Can't send after socket shutdown"                ; ESHUTDOWN
    err_str_59: .ascii "Too many references: can't splice"               ; ETOOMANYREFS
    err_str_60: .ascii "Operation timed out"                             ; ETIMEDOUT
    err_str_61: .ascii "Connection refused"                              ; ECONNREFUSED
    err_str_62: .ascii "Too many levels of symbolic links"               ; ELOOP
    err_str_63: .ascii "File name too long"                              ; ENAMETOOLONG
    err_str_64: .ascii "Host is down"                                    ; EHOSTDOWN
    err_str_65: .ascii "No route to host"                                ; EHOSTUNREACH
; others
    err_str_66: .ascii "Directory not empty"                             ; ENOTEMPTY
    err_str_67: .ascii "Too many processes"                              ; EPROCLIM
    err_str_68: .ascii "Too many users"                                  ; EUSERS
    err_str_69: .ascii "Disc quota exceeded"                             ; EDQUOT
    err_str_70: .ascii "Stale NFS file handle"                           ; ESTALE
    err_str_71: .ascii "Too many levels of remote in path"               ; EREMOTE
    err_str_72: .ascii "RPC struct is bad"                               ; EBADRPC
    err_str_73: .ascii "RPC version wrong"                               ; ERPCMISMATCH
    err_str_74: .ascii "RPC prog. not avail"                             ; EPROGUNAVAIL
    err_str_75: .ascii "Program version wrong"                           ; EPROGMISMATCH
    err_str_76: .ascii "Bad procedure for program"                       ; EPROCUNAVAIL
    err_str_77: .ascii "No locks available"                              ; ENOLCK
    err_str_78: .ascii "Function not implemented"                        ; ENOSYS
    err_str_79: .ascii "Inappropriate file type or format"               ; EFTYPE
    err_str_80: .ascii "Authentication error"                            ; EAUTH
    err_str_81: .ascii "Need authenticator"                              ; ENEEDAUTH
    err_str_82: .ascii "Device power is off"                             ; EPWROFF
    err_str_83: .ascii "Device error"                                    ; EDEVERR
    err_str_84: .ascii "Value too large to be stored in data type"       ; EOVERFLOW
    err_str_85: .ascii "Bad executable (or shared library)"              ; EBADEXEC
    err_str_86: .ascii "Bad CPU type in executable"                      ; EBADARCH
    err_str_87: .ascii "Shared library version mismatch"                 ; ESHLIBVERS
    err_str_88: .ascii "Malformed Mach-o file"                           ; EBADMACHO
    err_str_89: .ascii "Operation canceled"                              ; ECANCELED
    err_str_90: .ascii "Identifier removed"                              ; EIDRM
    err_str_91: .ascii "No message of desired type"                      ; ENOMSG
    err_str_92: .ascii "Illegal byte sequence"                           ; EILSEQ
    err_str_93: .ascii "Attribute not found"                             ; ENOATTR
    err_str_94: .ascii "Bad message"                                     ; EBADMSG
    err_str_95: .ascii "EMULTIHOP (Reserved)"                            ; EMULTIHOP
    err_str_96: .ascii "No message available on STREAM"                  ; ENODATA
    err_str_97: .ascii "ENOLINK (Reserved)"                              ; ENOLINK
    err_str_98: .ascii "No STREAM resources"                             ; ENOSR
    err_str_99: .ascii "Not a STREAM"                                    ; ENOSTR
    err_str_100: .ascii "Protocol error"                                 ; EPROTO
    err_str_101: .ascii "STREAM ioctl timeout"                           ; ETIME
    err_str_102: .ascii "Operation not supported on socket"              ; EOPNOTSUPP
    err_str_103: .ascii "Policy not found"                               ; ENOPOLICY
    err_str_104: .ascii "State not recoverable"                          ; ENOTRECOVERABLE
    err_str_105: .ascii "Previous owner died"                            ; EOWNERDEAD
    err_str_106: .ascii "Interface output queue is full"                 ; EQFULL
    err_str_107: .ascii "Capabilities insufficient"                      ; ENOTCAPABLE
    err_str_unknown: .ascii "Unknown error: "
    
    ; assume err code is smaller than 0 and negated to become positive
    err_str_err_code: .ascii "Error code: -"
    err_str_err_code_len = . - err_str_err_code

; common punctuations:

    p_newline: .ascii "\n"
    p_terminator: .ascii "\0"
    p_forward_slash: .ascii "/"
    p_dot: .ascii "."

; option for setsockopt()

    opt: .word 1

.section __DATA, __bss

    incoming_buffer: .space 30721
    nta_buffer: .space 32
    file_contents_buffer: .space 65536

    stat_struct: .space 200

; connection pool
;   conn_state_pool: .space 30856

.section __TEXT, __cstring

    response: .asciz "Hello, World!"

    debug_checkpoint_str: .asciz "here"
    debug_checkpoint_str_len = . - debug_checkpoint_str

    filename: .asciz "/Users/trangtran/Desktop/coding_files/assembly_shi/ARM-assembly-web-server/template.html"
    filename_len = . - filename

/* MPMC Queue */

.global _main
/*enum connection_progress {
    READING,
    PARSING,
    WRITING,
    DONE
};

struct connection_state {            // Offset
    enum connection_progress status; // 0       int8
    uint32_t client_fd;              // 1
    uint32_t bytes_read;             // 5
    uint32_t total_sent;             // 9
    uint32_t total_length;           // 13
    char buffer[30721];              // 17
};*/
_main:

    ret

; capacity in x0
_queue_alloc:

    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x0, #1024

    mov x25, x0

    adrp x1, index_mask @PAGE
    add x1, x1, index_mask @PAGEOFF
    mov x2, x0
    sub x2, x2, #1
    str x2, [x1]

    adrp x0, storage @PAGE
    add x0, x0, storage @PAGEOFF
    adrp x1, buffer @PAGE
    add x1, x1, buffer @PAGEOFF
    str x0, [x1]

    ; buffer already zeroed out so we're chilling

    mov x9, x25
    mov x11, #0x7818
    mul x9, x9, 
    adrp x1, buffer @PAGE
    add x1, x1, buffer @PAGEOFF

_queue_alloc_loop:

    sub x9, x9, #1
    mul x12, x9, x11
    add x10, x1, x12
    prfm pldl1strm, x10
    cbnz x9, _queue_alloc_loop

; loop ends here

    dmb ish

    ldp x29, x30, [sp], #16
    ret

_queue_dealloc:

    ; discard everything in queue
    ret

_queue_new:

    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ; fetch add explicit
    adrp x0, enqueue_pos @PAGE
    add x0, x0, enqueue_pos @PAGEOFF
    mov x1, #1

    mov x22, sp
    sub sp, sp, #20                     ; space for 2 x uint64 + uint32
    sub x23, sp, #12
    sub x24, sp, #4

_queue_new_1:

    ldaxr x22, [x0]
    add x23, x22, x1
    stlxr w24, x23, [x0]
    cbnz w24, _queue_new_1

    ldr x2, [x22]
    adrp x3, index_mask @PAGE
    add x3, x3, index_mask @PAGEOFF
    ldr x6, [x3]
    and x2, x2, x6
    
    adrp x5, sizeof_slot @PAGE
    add x5, x5, sizeof_slot @PAGEOFF
    ldr x4, [x5]
    mul x7, x2, x4
    
    adrp x1, buffer @PAGE
    add x1, x1, buffer @PAGEOFF
    add x1, x1, x2

    mov x19, x1                         ; slot* slot

    ; prefetch write two slots ahead
    add x2, x2, #1
    and x2, x2, x6
    mul x7, x2, x4
    prfm pstl1keep, x7
    add x2, x2, x4
    and x2, x2, x6
    mul x7, x2, x4
    prfm pstl1keep, x7

    sub sp, sp, #12
    str wzr, [sp, #-4]                  ; spin_count

_queue_spin_loop:

    sub sp, sp, #8
    sub x27, sp, #8
    ldar x25, [x19]                     ; slot.sequence in offset 0
    add sp, sp, #8
    ldr x21, [x22]                      ; x22 has &pos
    cmp x25, x21
    bne _queue_spin_loop_slot_empty_end

_queue_spin_loop_slot_empty:

    b _queue_spin_loop_end

_queue_spin_loop_slot_empty_end:

    cmp x25, x21
    bge _queue_spin_loop_next_iteration
    sub x7, x21, x25
    adrp x6, capacity @PAGE
    add x6, x6, capacity @PAGEOFF
    ldr w5, [x6]
    cmp x7, x5
    blt _queue_spin_loop_next_iteration

    ldr w3, [sp, #-4]
    add w3, w3, #1
    str w3, [sp, #-4]

    cmp w3, #64
    blt _queue_spin_loop_yield_short
    cmp w3, #256
    blt _queue_spin_loop_yield_medium
    b _queue_spin_loop_yield_long

_queue_spin_loop_yield_short:

    yield

_queue_spin_loop_yield_medium:

    yield
    yield
    yield
    yield

_queue_spin_loop_yield_long:

    yield
    yield
    yield
    yield
    yield
    yield
    yield
    yield
    yield
    yield
    yield
    yield
    yield
    yield
    yield
    yield

    cmp w3, #1000
    ble _queue_spin_loop_yield_long_reset_spin_counter_end

_queue_spin_loop_yield_long_reset_spin_counter:

    mov w3, #256

_queue_spin_loop_yield_long_reset_spin_counter_end:

    b _queue_spin_loop
    
_queue_spin_loop_next_iteration:

    yield

    b _queue_spin_loop

_queue_spin_loop_end:

    prfm pstl1keep, x19

    

    add sp, sp, #12
    add sp, sp, #20

    ldp x29, x30, [sp], #16
    ret

_queue_recycle:

    ;

.section __DATA, __data

.align 3
    buffer: .quad 0                     ; ptr to storage
.align 3
    enqueue_pos: .quad 0
.align 3
    dequeue_pos: .quad 0
.align 3
    index_mask: .quad 0
.align 3
    sizeof_slot: .quad 30744
.align 3:
    capacity: .word 1024


.section __DATA, __const

.align 2
    max_size: .word 1024

.section __DATA, __bss

storage: .space 251854848               ; storage[]