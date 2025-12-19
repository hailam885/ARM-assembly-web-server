; clang -o server server.s && ./server

; ARMv8.6-A AArch64

; register structure (for organization & avoid register corruption):

;   x0 - x7         arguments & scratch if needed
;   x8              indirect result location
;   x9 - x15        (scratch/temporary, assume overwritten every syscall)
;   x16             syscall
;   x17             link register
;   x18             platform register

;   x19             server fd            
;   x20             client socket fd
;   x21             file fd
;   x22             send buffer
;   x23             incoming buffer
;   x24             file contents
;   x25             (scratch/temporary)
;   x26             (scratch/temporary)
;   x27             (scratch/temporary)
;   x28             (scratch/temporary)


; commented out code are either broken code, temporary code (but do not remove), or debugging checkpoints.


.global _main
.align 2

_main:
    ; allocate 96 bytes on the stack for registers x19-x28
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!
    stp x27, x28, [sp, #-16]!
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x16, #20
    svc #0x80

    mov x25, x0

    mov x0, #1
    adrp x1, msg_show_proc_num @PAGE
    add x1, x1, msg_show_proc_num @PAGEOFF
    mov x2, msg_show_proc_num_len
    mov x16, #4
    svc #0x80

    mov x0, x25
    bl __num_to_ascii
    mov x2, x0
    mov x0, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, str_newline @PAGE
    add x1, x1, str_newline @PAGEOFF
    mov x2, #1
    mov x16, #4
    svc #0x80

    adrp x26, process_id @PAGE
    add x26, x26, process_id @PAGEOFF
    str w25, [x26]

    ; socket()
    mov x0, #2                          ; AF_INET (IPv4)
    mov x1, #1                          ; SOCK_STREAM
    mov x2, #0                          ; 0 = default protocol
    mov x16, #97                        ; socket syscall: 97
    svc #0x80

    cmp x0, #0
    bne _main_socket_fail_branch_end

_main_socket_fail_branch:               ; socket() < 0

    mov x0, #1
    adrp x1, fail_in_socket @PAGE
    add x1, x1, fail_in_socket @PAGEOFF
    mov x2, #12
    mov x16, #4
    svc #0x80

    b _main_program_exit_bad

_main_socket_fail_branch_end:

    mov x25, x0

    mov x0, #1
    adrp x1, msg_show_server_fd @PAGE
    add x1, x1, msg_show_server_fd @PAGEOFF
    mov x2, msg_show_server_fd_len
    mov x16, #4
    svc #0x80

    mov x0, x25
    bl __num_to_ascii
    mov x2, x0
    mov x0, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, str_newline @PAGE
    add x1, x1, str_newline @PAGEOFF
    mov x2, #1
    mov x16, #4
    svc #0x80

    mov x0, x25

    adrp x19, server_fd @PAGE
    add x19, x19, server_fd @PAGEOFF
    str w0, [x19]                       ; store value of server's file descriptor to &server_fd

    adrp x6, address @PAGE
    add x6, x6, address @PAGEOFF
    ldr x9, [x6, #2]                    ; htons( PORT )
    bl __htons_16
    str x9, [x6, #2]

    ; bind()
    mov x0, x25                         ; socket_fd
    adrp x1, address @PAGE              ; & struct sock_addr
    add x1, x1, address @PAGEOFF
    adrp x7, addrlen @PAGE
    add x7, x7, addrlen @PAGEOFF
    ldr x2, [x7]                        ; sizeof(struct sock_addr)
    mov x16, #104                     ; bind syscall: 104
    svc #0x80

    cmp x0, #0
    bge _main_bind_fail_branch_end

_main_bind_fail_branch:                 ; bind() < 0

    mov x0, #1
    adrp x1, fail_in_bind @PAGE
    add x1, x1, fail_in_bind @PAGEOFF
    mov x2, #8
    mov x16, #4
    svc #0x80

    b _main_program_exit_bad

_main_bind_fail_branch_end:

    ; listen()
    ldr x0, [x19]                       ; server file descriptor
    adrp x27, backlog @PAGE
    add x27, x27, backlog @PAGEOFF
    ldr x1, [x27]                       ; backlog count
    mov x16, #106                     ; listen syscall: 106
    svc #0x80

    cmp x0, #0
    bge _main_listen_fail_branch_end

_main_listen_fail_branch:               ; listen() < 0

    mov x0, #1
    adrp x1, fail_in_listen @PAGE
    add x1, x1, fail_in_listen @PAGEOFF
    mov x2, 11
    mov x16, #4
    svc #0x80

    b _main_program_exit_bad

_main_listen_fail_branch_end:

    ; open()
    adrp x0, filename @PAGE             ; addr
    add x0, x0, filename @PAGEOFF
    mov x1, #0                          ; O_RDONLY: open file as read only
    mov x2, #0                          ; permission
    mov x16, #5                         ; open syscall: 5
    svc #0x80

    mov x21, x0                         ; save file fd
    ; if open() return 0, 1, 2, that's unusual (corresponds to stdout, stdin, stderr)
    
    cmp x0, #0
    bgt _main_file_open_fail_end

_main_file_open_fail:                   ; open() < 0

    bl __strerror
    mov x2, x1
    mov x1, x0
    mov x0, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, filename @PAGE
    add x1, x1, filename @PAGEOFF
    mov x2, filename_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #'\n'
    mov x2, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #'\0'
    mov x2, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, err_str_err_code @PAGE
    add x1, x1, err_str_err_code @PAGEOFF
    mov x2, err_str_err_code_len
    mov x16, #4
    svc #0x80

    mov x0, x21
    bl __num_to_ascii

    mov x2, x0
    mov x0, #1
    ; addr already in x1
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #'\n'
    mov x2, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #'\0'
    mov x2, #1
    mov x16, #4
    svc #0x80

    b _main_program_exit_bad

_main_file_open_fail_end:

    mov x0, #1
    adrp x1, filename @PAGE
    add x1, x1, filename @PAGEOFF
    mov x2, filename_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, msg_show_file_fd @PAGE
    add x1, x1, msg_show_file_fd @PAGEOFF
    mov x2, msg_show_file_fd_len
    mov x16, #4
    svc #0x80

    mov x0, x21
    bl __num_to_ascii
    mov x2, x0
    mov x0, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, str_newline @PAGE
    add x1, x1, str_newline @PAGEOFF
    mov x2, #1
    mov x16, #4
    svc #0x80

    ; fstat()
    mov x0, x21
    adrp x1, stat_struct @PAGE            ; & struct stat
    add x1, x1, stat_struct @PAGEOFF
    mov x16, #189                       ; fstat systall: 189
    svc #0x80

    cmp x0, #0
    beq _main_get_file_info_end

_main_get_file_info_fail:               ; fstat() < 0

    mov x0, #0
    adrp x1, fail_get_file_info @PAGE
    add x1, x1, fail_get_file_info @PAGEOFF
    mov x2, #42
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, filename @PAGE
    add x1, x1, filename @PAGEOFF
    mov x2, filename_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #'\n'
    mov x2, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #'\0'
    mov x2, #1
    mov x16, #4
    svc #0x80

    b _main_program_exit_bad

_main_get_file_info_end:

    adrp x28, stat_struct @PAGE
    add x28, x28, stat_struct @PAGEOFF
/*  debugging: printing stat_struct contents
    mov x20, #0                          ; byte index counter
__loop:
    cmp x20, #144
    bge _main_program_exit_good

    mov x0, x20
    bl __num_to_ascii
    mov x2, x0
    mov x0, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, str_newline @PAGE
    add x1, x1, str_newline @PAGEOFF
    mov x2, #1
    mov x16, #4
    svc #0x80

    ldrb w0, [x28, x20]
    bl __num_to_ascii
    mov x2, x0
    mov x0, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, str_newline @PAGE
    add x1, x1, str_newline @PAGEOFF
    mov x2, #1
    mov x16, #4
    svc #0x80

    add x20, x20, #1
    b __loop

__loop_e:
    b _main_program_exit_good*/

    ldr x0, [x28, #72]                   ; struct stat::st_size, (macOS 13+): st_size is offset 72 instead of 96.

    ; bl __num_to_ascii
    ; mov x2, x0
    ; mov x0, #1
    ; mov x16, #4
    ; svc #0x80
    ; b _main_program_exit_good

    cmp x0, #0
    bgt _main_file_empty_end

_main_file_empty:                       ; st_size <= 0

    mov x0, #0
    adrp x1, fail_file_read_size @PAGE
    add x1, x1, fail_file_read_size @PAGEOFF
    mov x2, fail_file_read_size_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, filename @PAGE
    add x1, x1, filename @PAGEOFF
    mov x2, filename_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #'\n'
    mov x2, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #'\0'
    mov x2, #1
    mov x16, #4
    svc #0x80

    b _main_program_exit_bad

_main_file_empty_end:

    ; read()
    mov x0, x21                         ; retrieve file fd
    adrp x1, file_contents @PAGE        ; buffer to write to
    add x1, x1, file_contents @PAGEOFF
    adrp x28, stat_struct @PAGE
    add x28, x28, stat_struct @PAGEOFF
    ldr x2, [x28, #72]                   ; only read for a certain file size
    mov x16, #3                         ; read syscall: 3
    svc #0x80

    cmp x0, #0
    blt _main_file_read_error
    bge _main_file_read_error_end

_main_file_read_error:                  ; read() < 0

    mov x0, #0
    adrp x1, fail_file_read @PAGE
    add x1, x1, fail_file_read @PAGEOFF
    mov x2, fail_file_read_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, filename @PAGE
    add x1, x1, filename @PAGEOFF
    mov x2, filename_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #'\n'
    mov x2, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #'\0'
    mov x2, #1
    mov x16, #4
    svc #0x80

    b _main_program_exit_bad

_main_file_read_error_end:

    adrp x22, send_buffer @PAGE
    add x22, x22, send_buffer @PAGEOFF

    adrp x23, incoming_buffer @PAGE
    add x23, x23, incoming_buffer @PAGEOFF

    adrp x24, file_contents @PAGE
    add x24, x24, file_contents @PAGEOFF

    ; close(); close() < 0 -> shutdown
    mov x0, x21                         ; file fd
    mov x16, #6
    svc #0x80

    cmp x0, #0
    beq _main_file_fd_close_error_end

_main_file_fd_close_error:

    b _main_program_exit_bad

_main_file_fd_close_error_end:

    mov x21, #0

    ; checkpoint before the main loop, prints the file contents buffer, can disable/remove in the future.
    ; mov x0, #1
    ; adrp x1, file_contents @PAGE
    ; add x1, x1, file_contents @PAGEOFF
    ; mov x16, #4
    ; svc #0x80

    ; mov x0, #1
    ; adrp x1, str_newline @PAGE
    ; add x1, x1, str_newline @PAGEOFF
    ; mov x2, #1
    ; mov x16, #4
    ; svc #0x80

    mov x0, #1
    adrp x1, file_contents @PAGE
    add x1, x1, file_contents @PAGEOFF
    

    ; b _main_program_exit_good

_main_main_server_loop:

    mov x0, #1
    adrp x1, msg_waiting_conn @PAGE
    add x1, x1, msg_waiting_conn @PAGEOFF
    mov x2, #33
    mov x16, #4
    svc #0x80

    ; accept()
    ldr x0, [x19]                       ; server fd
    adrp x1, address @PAGE
    add x1, x1, address @PAGEOFF        ; addr to write to
    adrp x2, addrlen @PAGE
    add x2, x2, addrlen @PAGEOFF        ; sizeof(struct sock_addr)
    mov x16, #30                        ; accept syscall: 30
    svc #0x80

    adrp x20, client_fd @PAGE
    add x20, x20, client_fd @PAGEOFF
    str x0, [x20]

    cmp x0, #0
    bge _main_accept_create_socket_fail_branch_end

_main_accept_create_socket_fail_branch: ; accept() < 0

    mov x0, #1
    adrp x1, fail_create_socket @PAGE
    add x1, x1, fail_create_socket @PAGEOFF
    mov x2, #33
    mov x16, #4
    svc #0x80

    b _main_program_exit_bad

    ; b _main_main_server_loop

_main_accept_create_socket_fail_branch_end:
    ; mov x25, x0

    mov x0, #1
    adrp x1, msg_accept_conn @PAGE
    add x1, x1, msg_accept_conn @PAGEOFF
    mov x2, msg_accept_conn_len
    mov x16, #4
    svc #0x80

    ; debugging
    mov x0, #1
    adrp x1, msg_show_client_fd @PAGE
    add x1, x1, msg_show_client_fd @PAGEOFF
    mov x2, msg_show_client_fd_len
    mov x16, #4
    svc #0x80

    ; debugging
    ldr x0, [x20]
    bl __num_to_ascii
    mov x2, x0
    mov x0, #1
    mov x16, #4
    svc #0x80

    ; debugging
    mov x0, #1
    adrp x1, str_newline @PAGE
    add x1, x1, str_newline @PAGEOFF
    mov x2, #1
    mov x16, #4
    svc #0x80

    ; debugging purposes - check open fds
    mov x16, #2
    svc #0x80
    cmp x0, #0
    beq child_
    mov x0, #-1
    mov x1, #0
    mov x2, 30
    mov x16, #6
    svc #0x80
    b _main_program_exit_good

child_:

    adrp x0, cmd_shell_path @PAGE
    add x0, x0, cmd_shell_path @PAGEOFF
    adrp x1, cmd_lsof_argv @PAGE
    add x1, x1, cmd_lsof_argv @PAGEOFF
    mov x2, #0
    mov x16, #59
    svc #0x80

    b _main_program_exit_good

child_end_:

    ; read()
    adrp x20, client_fd @PAGE
    add x20, x20, client_fd @PAGEOFF
    ldr x0, [x20]                       ; client fd
    mov x1, x23                         ; buffer to write to
    mov x2, #30719                      ; max size to read, leave 1 for '\0'
    mov x16, #3
    svc #0x80

    mov x0, #1
    adrp x1, incoming_buffer @PAGE
    add x1, x1, incoming_buffer @PAGEOFF
    mov x2, #10000
    mov x16, #4
    svc #0x80

    b _main_program_exit_good

    ; check bytes read
    cmp x0, #0
    bgt _main_read_branch_success
    beq _main_read_branch_disconnected
    b _main_read_branch_err

_main_read_branch_success:
    ; read at the limit, likely an overflow
    mov x15, #30719
    cmp x0, x15
    bge _main_read_branch_buf_overflow

    adrp x27, valread @PAGE
    add x27, x27, valread @PAGEOFF
    str x0, [x27]

    mov w14, #'\0'                      ; null terminate buffer
    strb w14, [x23, x0]

    mov x0, #1
    adrp x1, read_success @PAGE
    add x1, x1, read_success @PAGEOFF
    mov x2, #42
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, x23                         ; print incoming request
    mov x2, x12
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, msg_show_bytes_read @PAGE
    add x1, x1, msg_show_bytes_read @PAGEOFF
    mov x2, msg_show_bytes_read_len
    mov x16, #4
    svc #0x80

    ldr x0, [x27]
    bl __num_to_ascii
    mov x2, x0
    mov x0, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, str_newline @PAGE
    add x1, x1, str_newline @PAGEOFF
    mov x2, #1
    mov x16, #4
    svc #0x80

    b _main_read_branch_end

_main_read_branch_disconnected:         ; read() == 0, no bytes sent

    mov x0, #1
    adrp x1, read_disconnected @PAGE
    add x1, x1, read_disconnected @PAGEOFF
    mov x2, #44
    mov x16, #4
    svc #0x80

    mov x0, x20
    bl __close_fd_64

    b _main_main_server_loop

_main_read_branch_buf_overflow:         ; read() == 30719 bytes, overflow or an attack, will cause crash if not handled

    mov x0, #1
    adrp x1, read_buffer_overflow @PAGE
    add x1, x1, read_buffer_overflow @PAGEOFF
    mov x2, #53
    mov x16, #4
    svc #0x80

    mov x0, x20
    bl __close_fd_64

    b _main_main_server_loop

_main_read_branch_err:                  ; read() < 0, error occured reading data

    mov x0, #1
    adrp x1, read_err_unknown @PAGE
    add x1, x1, read_err_unknown @PAGEOFF
    mov x2, #73
    mov x16, #4
    svc #0x80

    mov x0, x20
    bl __close_fd_64

    b _main_main_server_loop

_main_read_branch_end:

    mov x0, x24
    bl __strlen                         ; calculate file length & check for len == 0 -> err

    cmp x0, #0
    bge _main_file_contents_length_is_zero_end

_main_file_contents_length_is_zero:     ; checks if template.html, or file_contents is empty

    mov x0, #0
    adrp x1, fail_file_empty @PAGE
    add x1, x1, fail_file_empty @PAGEOFF
    mov x2, #43
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, filename @PAGE
    add x1, x1, filename @PAGEOFF
    mov x2, filename_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #'\n'
    mov x2, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #'\0'
    mov x2, #1
    mov x16, #4
    svc #0x80

    b _main_program_exit_bad

_main_file_contents_length_is_zero_end:

    ; building http response, store in send_buffer

    ; strlen in x0

    bl __num_to_ascii

    mov x12, x1                                     ; Content-Length

    mov x0, x22                                     ; http response buffer (send_buffer)

    adrp x9,  http_header @PAGE                     ; HTTP Header
    add  x9,  x9, http_header @PAGEOFF
    adrp x10, http_content_type @PAGE               ; Content-Type
    add  x10, x10, http_content_type @PAGEOFF
    adrp x11, http_content_length @PAGE
    add  x11, x11, http_content_length @PAGEOFF

    adrp x13, http_content_security @PAGE
    add  x13, x13, http_content_security @PAGEOFF   ; Connection, X-Content-Type-Options, X-Frame-Options, X-XSS-Protection
    adrp x14, line_break @PAGE
    add  x14, x14, line_break @PAGEOFF
    adrp x15, file_contents @PAGE
    add  x15, x15, file_contents @PAGEOFF

    mov x1, x9
    bl __strcat
    mov x1, x10
    bl __strcat
    mov x1, x11
    bl __strcat
    mov x1, x12
    bl __strcat
    mov x1, x14
    bl __strcat
    mov x1, x13
    bl __strcat
    mov x1, x14
    bl __strcat
    mov x1, x15
    bl __strcat

    ; address in x22 already see changes : x0 & x22 both point to same thing

    bl __strlen
    cmp x0, #0
    beq _main_buffer_empty

_main_buffer_empty:                     ; http request buffer (send_buffer) is empty, error with creating one

    mov x0, #1
    adrp x1, fail_send_buffer_empty @PAGE
    add x1, x1, fail_send_buffer_empty @PAGEOFF
    mov x2, #24
    mov x16, #4
    svc #0x80

    b _main_program_exit_bad

_main_buffer_empty_end:

    ; send()
    mov x2, x0                          ; response buffer len
    ldr x0, [x20]                       ; client socket fd
    ; send buffer address already in x1
    mov x3, #0x80000                    ; MSG_NOSIGNAL: prevents SIGPIPE when client close connection
    mov x16, #101                       ; send syscall: 101
    svc #0x80

    cmp x0, #0
    beq _main_data_sent_empty
    bge _main_data_sent_success

_main_data_sent_fail:                   ; send() < 0

    mov x0, #1
    adrp x1, fail_send_data_to_client @PAGE
    add x1, x1, fail_send_data_to_client @PAGEOFF
    mov x2, #59
    mov x16, #4
    svc #0x80

    b _main_main_server_loop

_main_data_sent_success:

    mov x0, #1
    adrp x1, send_success @PAGE
    add x1, x1, send_success @PAGEOFF
    mov x2, #43
    mov x16, #4
    svc #0x80

    b _main_main_server_loop

_main_data_sent_empty:                  ; send() == 0, no bytes sent/read error, or client request nothing

    mov x0, #1
    adrp x1, send_no_data_to_client @PAGE
    add x1, x1, send_no_data_to_client @PAGEOFF
    mov x2, #78
    mov x16, #4
    svc #0x80

    b _main_main_server_loop

_main_program_exit_good:                ; exit w/ exit code 0: good

    ; exit()
    mov x0, #0
    mov x16, #1                         ; exit syscall: 1
    svc #0x80

    ; free allocated bytes & restore registers
    ldp x19, x20, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x25, x26, [sp], #16
    ldp x27, x28, [sp], #16
    mov sp, x29
    ldp x29, x30, [sp], #16
    ret

_main_program_exit_bad:                 ; exit w/ exit code 1: bad

    ; exit()
    mov x0, #1
    mov x16, #1
    svc #0x80

    ; free allocated bytes & restore registers
    ldp x19, x20, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x25, x26, [sp], #16
    ldp x27, x28, [sp], #16
    mov sp, x29
    ldp x29, x30, [sp], #16
    ret

; functions

__htons_16:                             ; x9 -> input, x9 -> output, uint16 implementation

    stp x29, x30, [sp, #-16]!
    mov x29, sp
    lsl x10, x9, #8                     ; new MSB
    lsr x11, x9, #8                     ; new LSB
    orr x9, x10, x11                    ; MSB | LSB
    ldp x29, x30, [sp], #16
    ret

__close_fd_64:                          ; (input: x0 -> file descriptor, output: x0 -> none), force closes a file descriptor

    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ; close()
    mov x16, #6                         ; close syscall: 6
    svc #0x80

    cmp x0, #0
    beq __close_fd_64_exit

__close_fd_64_fail:                     ; close() fail, shutdown() to be safe

    ; shutdown()
                                        ; fd already in x0
    mov x1, #2                          ; SHUT_RDWR: shut down both sides
    mov x16, #134                       ; shutdown syscall: 134
    svc #0x80

__close_fd_64_exit:
    
    ldp x29, x30, [sp], #16
    ret

/*
__close_fd_32:                          ; (input: x0 -> file descriptor, output: x0 -> none), force closes a file descriptor

    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x16, #6                         ; close syscall: 6
    svc #0x80

    cmp x0, #0
    beq __close_fd_64_exit

__close_fd_32_fail:

    ; shutdown()
                                        ; fd already in x0
    mov x1, #2                          ; SHUT_RDWR: shut down both sides
    mov x16, #134                       ; shutdown syscall: 134
    svc #0x80

__close_fd_32_exit:

    ldp x29, x30, [sp], #16
    ret*/

__strlen:                               ; .asciz only (input: x0 -> string addr; output: x0 -> strlen, x1 -> string addr)

    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x1, x0                          ; move str pointer, prepare for operation
    
__strlen_loop:

    ldrb w2, [x0], #1                   ; load byte & move pointer by 1
    cbnz w2, __strlen_loop              ; continue if not null
    
    sub x0, x0, x1                      ; x0 = end - start
    sub x0, x0, #1                      ; exclude null

    ldp x29, x30, [sp], #16
    ret

__strcat:                               ; x0 += x1, .asciz only (x0, x1 is str addr)

    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x2, x0
    mov x0, x1
    bl __strlen
    mov x3, x0
    mov x0, x2

    sub x3, x3, #1                      ; "overwrite" null terminator in x0

__strcat_copy_loop:

    ldrb w4, [x1], #1                   ; load byte & move pointer by 1
    strb w4, [x0, x3]
    cbnz w4, __strcat_copy_loop

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
    mov x0, x2                          ; save length in x0
    ; restore registers & return
    ldp x29, x30, [sp], #16
    ret

__strerror:                             ; input: x0 -> code, output: x0 -> error str addr, x1 -> error str len

    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ; check input against accepted/recognized error codes, otherwise return unknown
    cmp x0, #1
    beq __strerror_err_eperm
    cmp x0, #2
    beq __strerror_err_enoent
    cmp x0, #3
    beq __strerror_err_esrch
    cmp x0, #4
    beq __strerror_err_eintr
    cmp x0, #5
    beq __strerror_err_eio
    cmp x0, #6
    beq __strerror_err_enxio
    cmp x0, #9
    beq __strerror_err_ebadf
    cmp x0, #13
    beq __strerror_err_eacces
    cmp x0, #14
    beq __strerror_err_efault
    cmp x0, #17
    beq __strerror_err_eexist
    cmp x0, #20
    beq __strerror_err_enotdir
    cmp x0, #21
    beq __strerror_err_eisdir
    cmp x0, #22
    beq __strerror_err_einval
    cmp x0, #24
    beq __strerror_err_emfile
    cmp x0, #28
    beq __strerror_err_enospc
    cmp x0, #30
    beq __strerror_err_erofs
    cmp x0, #63
    beq __strerror_err_enametoolong
    b __strerror_err_unknown

__strerror_err_eperm:                   ; operation not permitted

    adrp x0, err_str_eperm @PAGE
    add x0, x0, err_str_eperm @PAGEOFF
    mov x1, err_str_eperm_len
    b __strerror_exit

__strerror_err_enoent:                  ; no entry/doesn't exist

    adrp x0, err_str_enoent @PAGE
    add x0, x0, err_str_enoent @PAGEOFF
    mov x1, err_str_enoent_len
    b __strerror_exit

__strerror_err_esrch:                   ; no such process

    adrp x0, err_str_esrch @PAGE
    add x0, x0, err_str_esrch @PAGEOFF
    mov x1, err_str_esrch_len
    b __strerror_exit

__strerror_err_eintr:                   ; interrupted system call

    adrp x0, err_str_eintr @PAGE
    add x0, x0, err_str_eintr @PAGEOFF
    mov x1, err_str_eintr_len
    b __strerror_exit

__strerror_err_eio:                     ; input/output error

    adrp x0, err_str_eio @PAGE
    add x0, x0, err_str_eio @PAGEOFF
    mov x1, err_str_eio_len
    b __strerror_exit

__strerror_err_enxio:                   ; no such device/address

    adrp x0, err_str_enxio @PAGE
    add x0, x0, err_str_enxio @PAGEOFF
    mov x1, err_str_enxio_len
    b __strerror_exit

__strerror_err_ebadf:                   ; bad file desriptor

    adrp x0, err_str_ebadf @PAGE
    add x0, x0, err_str_ebadf @PAGEOFF
    mov x1, err_str_ebadf_len
    b __strerror_exit

__strerror_err_eacces:                  ; permission denied

    adrp x0, err_str_eacces @PAGE
    add x0, x0, err_str_eacces @PAGEOFF
    mov x1, err_str_eacces_len
    b __strerror_exit

__strerror_err_efault:                  ; bad address

    adrp x0, err_str_efault @PAGE
    add x0, x0, err_str_efault @PAGEOFF
    mov x1, err_str_efault_len
    b __strerror_exit

__strerror_err_eexist:                  ; file/dir already exist

    adrp x0, err_str_efault @PAGE
    add x0, x0, err_str_efault @PAGEOFF
    mov x1, err_str_efault_len
    b __strerror_exit

__strerror_err_enotdir:                 ; treating file as folder and vice versa

    adrp x0, err_str_enotdir @PAGE
    add x0, x0, err_str_enotdir @PAGEOFF
    mov x1, err_str_enotdir_len
    b __strerror_exit

__strerror_err_eisdir:                  ; treating directory as file

    adrp x0, err_str_eisdir @PAGE
    add x0, x0, err_str_eisdir @PAGEOFF
    mov x1, err_str_eisdir_len
    b __strerror_exit

__strerror_err_einval:                  ; invalid argument/value

    adrp x0, err_str_einval @PAGE
    add x0, x0, err_str_einval @PAGEOFF
    mov x1, err_str_einval_len
    b __strerror_exit

__strerror_err_emfile:                  ; maxed out max file descriptor per process

    adrp x0, err_str_emfile @PAGE
    add x0, x0, err_str_emfile @PAGEOFF
    mov x1, err_str_emfile_len
    b __strerror_exit

__strerror_err_enospc:                  ; no space, typically refers to disk

    adrp x0, err_str_enospc @PAGE
    add x0, x0, err_str_enospc @PAGEOFF
    mov x1, err_str_enospc_len
    b __strerror_exit

__strerror_err_erofs:                   ; write to read only file

    adrp x0, err_str_erofs @PAGE
    add x0, x0, err_str_erofs @PAGEOFF
    mov x1, err_str_erofs_len
    b __strerror_exit

__strerror_err_enametoolong:            ; literally what it means

    adrp x0, err_str_enametoolong @PAGE
    add x0, x0, err_str_enametoolong @PAGEOFF
    mov x1, err_str_enametoolong_len
    b __strerror_exit

__strerror_err_unknown:                 ; for unknown errors

    adrp x0, err_str_unknown @PAGE
    add x0, x0, err_str_unknown @PAGEOFF
    mov x1, err_str_unknown_len
    b __strerror_exit

__strerror_exit:                        ; exit

    ldp x29, x30, [sp], #16
    ret

__clear_buf:                            ; input: x0 -> buffer addr, x1 -> buffer len; output: x0 -> buffer addr
    
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov w3, #0

__clear_buf_loop:

    strb w3, [x0], #1                   ; set every byte to 0b00000000 in a recursive loop
    subs x1, x1, #1
    b.ne __clear_buf_loop_end

__clear_buf_loop_end:

    ldp x29, x30, [sp], #16
    ret

; __getcwd:                               ; get current working directory, (input: x0 -> dest str addr, output: x0 -> cwd str addr)
; 
;     stp x29, x30, [sp, #-16]!
;     mov x29, sp
; 
;     ;
; 
;     ldp x29, x30, [sp], #16
;     ret

.section  __DATA, __data                ; readable/writable section

.align 2
    server_fd: .word 0
.align 2
    client_fd: .word 0
.align 3
    valread: .quad 0
.align 1
    file_contents_len: .short 0
.align 2
    process_id: .word 0

; struct sockaddr_in
.align 4
    address:
        .byte 0                          ; sin_len                       uint8
        .byte 2                          ; sin_family    AF_INET         unsigned char
        .short 80                        ; sin_port                      uint8
        .word 0                          ; sin_addr      INADDR_ANY      uint32
        .byte 0, 0, 0, 0, 0, 0, 0, 0     ; sin_zero                      char[8]

.section  __DATA, __const                ; read only section

; debug utilities

    debug_checkpoint_str: .asciz "here\n" ; 6
    debug_checkpoint_str_len = . - debug_checkpoint_str
    debug_cwd: .ascii "\nCurrent directory: "
    debug_cwd_len = . - debug_cwd
    debug_open: .ascii "Attempting to open: "
    debug_open_len = . - debug_open

; error messages
    err_str_eperm: .ascii "Operation not permitted: "
    err_str_eperm_len = . - err_str_eperm
    
    err_str_enoent: .ascii "No such file or directory: "
    err_str_enoent_len = . - err_str_enoent
    
    err_str_esrch: .ascii "No such process: "
    err_str_esrch_len = . - err_str_esrch
    
    err_str_eintr: .ascii "Interrupted system call: "
    err_str_eintr_len = . - err_str_eintr
    
    err_str_eio: .ascii "Input/output error: "
    err_str_eio_len = . - err_str_eio
    
    err_str_enxio: .ascii "Device not configured: "
    err_str_enxio_len = . - err_str_enxio
    
    err_str_ebadf: .ascii "Bad file descriptor: "
    err_str_ebadf_len = . - err_str_ebadf
    
    err_str_eacces: .ascii "Permission denied: "
    err_str_eacces_len = . - err_str_eacces
    
    err_str_efault: .ascii "Bad address: "
    err_str_efault_len = . - err_str_efault
    
    err_str_eexist: .ascii "File exists: "
    err_str_eexist_len = . - err_str_eexist
    
    err_str_enotdir: .ascii "Not a directory: "
    err_str_enotdir_len = . - err_str_enotdir
    
    err_str_eisdir:.ascii "Is a directory: "
    err_str_eisdir_len = . - err_str_eisdir
    
    err_str_einval: .ascii "Invalid argument: "
    err_str_einval_len = . - err_str_einval
    
    err_str_emfile: .ascii "Too many open files: "
    err_str_emfile_len = . - err_str_emfile
    
    err_str_enospc: .ascii "No space left on device: "
    err_str_enospc_len = . - err_str_enospc
    
    err_str_erofs: .ascii "Read-only file system: "
    err_str_erofs_len = . - err_str_erofs
    
    err_str_enametoolong: .ascii "File name too long: "
    err_str_enametoolong_len = . - err_str_enametoolong
    
    err_str_unknown: .ascii "Unknown error: "
    err_str_unknown_len = . - err_str_unknown
    
    ; assume err code is smaller than 0 and negated to become positive
    err_str_err_code: .ascii "\nError code: -"
    err_str_err_code_len = . - err_str_err_code

    fail_file_open: .ascii "Failed to open file " ; 20
    fail_file_open_: .ascii "; open() return error code: " ; 28

    fail_file_open_no_exist: .ascii "File doesnt exist in specified directory: " ; 42
    fail_file_open_no_permission: .ascii "No permission to open file: " ; 28
    fail_file_open_bad_addr: .ascii "File name pointer invalid for file: " ; 36

    fail_get_file_info: .ascii "Failed to retrieve information for file: "

    fail_file_empty: .ascii "File is likely empty or an error occured: "
    fail_file_empty_len = . - fail_file_empty

    fail_file_read: .ascii "An error occured when reading the file, or the file is empty: "
    fail_file_read_len = . - fail_file_read

    fail_file_close: .ascii "Failed to close file: "

    fail_file_read_size: .ascii "Error retrieving file length: "
    fail_file_read_size_len = . - fail_file_read_size

; http stuff

    http_header: .ascii "HTTP/1.1 200 Ok\r\n" ; 25
    http_content_type: .ascii "Content-Type: text/html\r\n" ; 26
    http_content_length: .ascii "Content-Length: " ; 16
    http_content_security: .ascii "Connection: close\r\nX-Content-Type-Options: nosniff\r\nX-Frame-Options: DENY\r\nX-XSS-Protection: 1; mode=block\r\n" ; 116

    line_break: .ascii "\r\n" ; 2
    str_newline: .ascii "\n"
    str_terminator: .ascii "\0"

.align 2
    addrlen: .word 16
.align 0
    port: .byte 80
.align 2
    backlog: .word 16384

; status / update messages
    msg_accept_conn: .asciz "\nAccepted a connection. Processing...\n"
    msg_accept_conn_len = . - msg_accept_conn

    msg_show_server_fd: .ascii "Server file descriptor: "
    msg_show_server_fd_len = . - msg_show_server_fd

    msg_show_file_fd: .ascii " file descriptor: "
    msg_show_file_fd_len = . - msg_show_file_fd

    msg_show_client_fd: .ascii "Client socket fd: "
    msg_show_client_fd_len = . - msg_show_client_fd

    msg_show_bytes_read: .ascii "\nBytes read: "
    msg_show_bytes_read_len = . - msg_show_bytes_read

    msg_show_proc_num: .ascii "\nProcess ID (for debugging purposes): "
    msg_show_proc_num_len = . - msg_show_proc_num

.section __DATA, __bss                  ; auto zeroed at startup

; buffers
.align 14
    incoming_buffer: .space 30720       ; incoming connections buffer
.align 4
    file_contents: .space 30000         ; html file content buffer
.align 3
    stat_struct: .space 200             ; file stat buffer, for file size
.align 4
    send_buffer: .space 30000           ; outgoing response buffer
.align 11
    general_buffer: .space 2048         ; general buffer for functions
.align 5
    nta_buffer: .space 32               ; __num_to_ascii's buffer


.section  __TEXT, __cstring             ; null terminated strings & read only strings here

    fail_send_buffer_empty: .asciz "Send buffer is empty.\n"
    fail_send_data_to_client: .asciz "Failed to send data to client. The lion can't care less.\n"
    
    msg_waiting_conn: .asciz "\nWaiting for new connection...\n\n"
    
    read_success: .asciz "Successfully read from client. Message: \n"
    read_disconnected: .asciz "A client is disconnected from the server.\n"
    read_buffer_overflow: .asciz "A client's packet could trigger a buffer overflow.\n"
    read_err_unknown: .asciz "An unknown error encountered when trying to read the client's request.\n"
    
    fail_in_socket: .asciz "In sockets\n"
    fail_in_bind: .asciz "In bind\n"
    fail_in_listen: .asciz "In listen\n"
    fail_create_socket: .asciz "Failed to create client socket.\n"
    
    send_success: .asciz "Successfully transmitted data to client.\n"
    send_no_data_to_client: .asciz "The client requested no data or a general read and write error encountered.\n"

    filename: .asciz "/Users/trangtran/Desktop/coding_files/assembly_shi/ARM-assembly-web-server/template.html"
    filename_len = . - filename

; debugging purposes

    cmd_shell_path: .asciz "/bin/sh"
    cmd_dash_c: .asciz "-c"
    cmd_lsof: .asciz "lsof -p $PPID > /Users/trangtran/Desktop/coding_files/assembly_shi/ARM-assembly-web-server/fds.txt"
.align 3
    cmd_lsof_argv:
        .quad cmd_shell_path
        .quad cmd_dash_c
        .quad cmd_lsof
        .quad 0
/*
_main:
0000000100000460        stp     x28, x27, [sp, #-0x20]!
0000000100000464        stp     x29, x30, [sp, #0x10]
0000000100000468        add     x29, sp, #0x10
000000010000046c        sub     sp, sp, #0x4b0
0000000100000470        adrp    x8, 4 ; 0x100004000
0000000100000474        ldr     x8, [x8, #0x8] ; literal pool symbol address: ___stack_chk_guard
0000000100000478        ldr     x8, [x8]
000000010000047c        stur    x8, [x29, #-0x18]
0000000100000480        mov     x8, sp
0000000100000484        mov     w1, #0x0
0000000100000488        str     xzr, [x8]
000000010000048c        adrp    x0, 0 ; 0x100000000
0000000100000490        add     x0, x0, #0x5c0 ; literal pool for: "/Users/trangtran/Desktop/coding_files/assembly_shi/ARM-assembly-web-server/template.html"
0000000100000494        bl      0x10000059c ; symbol stub for: _open
0000000100000498        str     w0, [sp, #0x14]
000000010000049c        ldr     w8, [sp, #0x14]
00000001000004a0        tbz     w8, #0x1f, 0x1000004b0
00000001000004a4        b       0x1000004a8
00000001000004a8        mov     w0, #0x1
00000001000004ac        bl      0x100000584 ; symbol stub for: _exit
00000001000004b0        ldr     w0, [sp, #0x14]
00000001000004b4        add     x1, sp, #0x18
00000001000004b8        bl      0x100000590 ; symbol stub for: _fstat
00000001000004bc        str     w0, [sp, #0x10]
00000001000004c0        ldr     w8, [sp, #0x10]
00000001000004c4        tbz     w8, #0x1f, 0x1000004d4
00000001000004c8        b       0x1000004cc
00000001000004cc        mov     w0, #0x1
00000001000004d0        bl      0x100000584 ; symbol stub for: _exit
00000001000004d4        ldr     x8, [sp, #0x78]
00000001000004d8        mov     x9, sp
00000001000004dc        str     x8, [x9]
00000001000004e0        adrp    x0, 0 ; 0x100000000
00000001000004e4        add     x0, x0, #0x619 ; literal pool for: "%lld"
00000001000004e8        bl      0x1000005a8 ; symbol stub for: _printf
00000001000004ec        ldr     w0, [sp, #0x14]
00000001000004f0        add     x1, sp, #0xa8
00000001000004f4        mov     x2, #0x1f5
00000001000004f8        bl      0x1000005b4 ; symbol stub for: _read
00000001000004fc        str     x0, [sp, #0x8]
0000000100000500        ldr     x8, [sp, #0x8]
0000000100000504        subs    x8, x8, #0x0
0000000100000508        b.gt    0x100000518
000000010000050c        b       0x100000510
0000000100000510        mov     w0, #0x1
0000000100000514        bl      0x100000584 ; symbol stub for: _exit
0000000100000518        add     x0, sp, #0xa8
000000010000051c        bl      0x1000005a8 ; symbol stub for: _printf
0000000100000520        ldr     w0, [sp, #0x14]
0000000100000524        bl      0x100000578 ; symbol stub for: _close
0000000100000528        tbz     w0, #0x1f, 0x100000538
000000010000052c        b       0x100000530
0000000100000530        mov     w0, #0x1
0000000100000534        bl      0x100000584 ; symbol stub for: _exit
0000000100000538        ldur    x9, [x29, #-0x18]
000000010000053c        adrp    x8, 4 ; 0x100004000
0000000100000540        ldr     x8, [x8, #0x8] ; literal pool symbol address: ___stack_chk_guard
0000000100000544        ldr     x8, [x8]
0000000100000548        subs    x8, x8, x9
000000010000054c        b.eq    0x100000558
0000000100000550        b       0x100000554
0000000100000554        bl      0x10000056c ; symbol stub for: ___stack_chk_fail
0000000100000558        mov     w0, #0x0
000000010000055c        add     sp, sp, #0x4b0
0000000100000560        ldp     x29, x30, [sp, #0x10]
0000000100000564        ldp     x28, x27, [sp], #0x20
0000000100000568        ret


Contents of (__TEXT,__cstring) section
0000000100000608        6573552f 742f7372 676e6172 6e617274 
0000000100000618        7365442f 706f746b 646f632f 5f676e69 
0000000100000628        656c6966 73612f73 626d6573 735f796c 
0000000100000638        412f6968 612d4d52 6d657373 2d796c62 
0000000100000648        2d626577 76726573 742f7265 6c706d65 
0000000100000658        2e657461 6c6d7468 00642500 646c6c25 
0000000100000668        6c250a00 25000a75 6c 75 00
*/