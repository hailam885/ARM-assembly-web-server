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
    ldrh w0, [x6, #2]                    ; htons( PORT )
    bl __htons_16
    strh w0, [x6, #2]

    ; bind()
    mov x0, x25                         ; socket_fd
    adrp x1, address @PAGE              ; & struct sock_addr
    add x1, x1, address @PAGEOFF
    adrp x7, addrlen @PAGE
    add x7, x7, addrlen @PAGEOFF
    ldr w2, [x7]                        ; sizeof(struct sock_addr)
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
    ldr w0, [x19]                       ; server file descriptor
    adrp x27, backlog @PAGE
    add x27, x27, backlog @PAGEOFF
    ldr w1, [x27]                       ; backlog count
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

    adrp x1, file_contents_len @PAGE
    add x1, x1, file_contents_len @PAGEOFF
    strh w0, [x1]

    ; print file contents for debugging purposes.
    mov x0, #1
    adrp x1, msg_show_file_contents @PAGE
    add x1, x1, msg_show_file_contents @PAGEOFF
    mov x2, msg_show_file_contents_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, filename @PAGE
    add x1, x1, filename @PAGEOFF
    mov x2, filename_len
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #':'
    mov x2, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #' '
    mov x2, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    adrp x1, file_contents @PAGE
    add x1, x1, file_contents @PAGEOFF
    adrp x3, file_contents_len @PAGE
    add x3, x3, file_contents_len @PAGEOFf
    ldrh w2, [x3]
    mov x16, #4
    svc #0x80

    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #'\n'
    mov x2, #1
    mov x16, #4
    svc #0x80

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
    ldr w0, [x19]                       ; server fd
    adrp x1, address @PAGE
    add x1, x1, address @PAGEOFF        ; addr to write to
    adrp x2, addrlen @PAGE
    add x2, x2, addrlen @PAGEOFF        ; sizeof(struct sock_addr)
    mov x16, #30                        ; accept syscall: 30
    svc #0x80

    adrp x20, client_fd @PAGE
    add x20, x20, client_fd @PAGEOFF
    str w0, [x20]

    cmp w0, #0
    bge _main_accept_create_socket_fail_branch_end

_main_accept_create_socket_fail_branch: ; accept() < 0

    mov x25, x0

    mov x0, #1
    adrp x1, fail_create_socket @PAGE
    add x1, x1, fail_create_socket @PAGEOFF
    mov x2, #33
    mov x16, #4
    svc #0x80

    mov x0, x25
    bl __num_to_ascii
    mov x2, x0
    mov x0, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #':'
    mov x2, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #' '
    mov x2, #1
    svc #0x80

    mov x0, x25
    bl __strerror
    mov x2, x1
    mov x1, x0
    mov x0, #1
    mov x16, #4
    svc #0x80

    ; purposely crash for now
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
    ldr w0, [x20]
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

/*
; check open fds for this process
    adrp x0, debug_fd_dir @PAGE
    add x0, x0, debug_fd_dir @PAGEOFF
    mov x1, #0
    mov x16, #5
    svc #0x80

    mov x6, x0                          ; save fd
    cmp x0, #0
    bgt _main_check_fd_fail_end

_main_check_fd_fail:

    bl __perror
    b _main_program_exit_bad

_main_check_fd_fail_end:

    mov x7, #0                          ; curr pos in dir

_main_check_fd_loop:

    ; fd already in x0
    adrp x1, get_fd_buffer @PAGE
    add x1, x1, get_fd_buffer @PAGEOFF
    mov x2, #4096
    mov x3, x7
    mov x16, #344
    svc #0x80

    cmp x0, #0
    ble _main_check_fd_loop_end

    mov x28, x0

    mov x5, #0                          ; offset

_main_check_fd_inner_loop:

    cmp x5, x28
    blt _main_check_fd_inner_loop_end

    adrp x0, get_fd_buffer @PAGE
    add x0, x0, get_fd_buffer @PAGEOFF
    add x0, x0, x5

    add x0, x0, #160
    adrp x1, str_one_dot @PAGE
    add x1, x1, str_one_dot @PAGEOFF
    bl __strcmp

    mov x25, x2

    adrp x1, str_two_dot @PAGE
    add x1, x1, str_two_dot @PAGEOFF
    bl __strcmp

    mov x26, x2

    orr x0, x25, x26                    ; if both is non zero, then (x25 OR x26) must be non zero.
    cmp x0, #0

_main_check_fd_inner_loop_branch:

    adrp x1, get_fd_buffer @PAGE
    add x1, x1, get_fd_buffer @PAGEOFF
    ldrh w0, [x1, #20]
    uxth x0, w0
    bl __num_to_ascii
    mov x25, x0
    mov x26, x1

    mov x0, #1
    adrp x1, debug_print_fd @PAGE
    add x1, x1, debug_print_fd @PAGEOFF
    mov x2, debug_print_fd_len
    mov x16, #4
    svc #0x80

    adrp x1, process_id @PAGE
    add x1, x1, process_id @PAGEOFF
    str w0, [x1]
    bl __num_to_ascii

    mov x2, x0
    mov x0, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #','
    mov x2, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, x26
    mov x2, x25
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #'\n'
    mov x2, #1
    mov x16, #4
    svc #0x80

_main_check_fd_inner_loop_branch_end:

    adrp x0, get_fd_buffer @PAGE
    add x0, x0, get_fd_buffer @PAGEOFF
    ldrh w2, [x0, #16]
    add x5, x5, x2, uxtx #0

    b _main_check_fd_inner_loop

_main_check_fd_inner_loop_end:

    b _main_check_fd_loop

_main_check_fd_loop_end:

    bl __strerror                         ; at least see what error it is
    mov x2, x1
    mov x1, x0
    mov x0, #1
    mov x16, #4
    svc #0x80

    b _main_program_exit_good
*/

    ; read()
    adrp x20, client_fd @PAGE
    add x20, x20, client_fd @PAGEOFF
    ldr w0, [x20]                       ; client fd
    adrp x1, incoming_buffer @PAGE
    add x1, x1, incoming_buffer @PAGEOFF
    mov x2, #30720                      ; max size to read, leave 1 for '\0'
    mov x16, #3
    svc #0x80

    ; mov x2, x0
    ; mov x0, #1
    ; adrp x1, incoming_buffer @PAGE
    ; add x1, x1, incoming_buffer @PAGEOFF
    ; mov x16, #4
    ; svc #0x80

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
    adrp x1, incoming_buffer @PAGE
    add x1, x1, incoming_buffer @PAGEOFF
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

__htons_16:                             ; x0 -> input, x0 -> output, uint16 implementation

    stp x29, x30, [sp, #-16]!
    mov x29, sp
    lsl x10, x0, #8                     ; new MSB
    lsr x11, x0, #8                     ; new LSB
    orr x0, x10, x11                    ; MSB | LSB
    ; and x0, #0xffff
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

/* close_fd 32-bit implementation
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

__strncat:                              ; x0 += x1, both .asciz only, input: x0, x1 -> str addr, x2 -> x0's max buffer size, x3 -> length to copy from x1; output: x0, x1 -> str addr

    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x5, x2
    mov x6, x3

    mov x2, x0
    mov x0, x1
    bl __strlen

    mov x7, x0
    add x7, x7, x6
    sub x7, x7, #1                      ; assuming x0 has null terminator, doesn't count
    cmp x7, x5
    bgt __strncat_exit

    mov x3, x0
    mov x0, x2

__strncat_copy_loop:

    sub x6, x6, #1
    cmp x6, #0
    ble __strncat_exit
    ldrb w4, [x1], #1
    strb w4, [x0, x3]
    cbnz w4, __strncat_copy_loop

__strncat_exit:

    ldp x29, x30, [sp], #16
    ret

__strcmp:                               ; input: x0, x1 -> string addr, output: x2 = (x0 <=> x1)

    stp x29, x30, [sp, #-16]!
    mov x29, sp

__strcmp_loop:

    ldrb w3, [x1], #1
    ldrb w4, [x0], #1
    cmp w3, w4
    beq __strcmp_loop

    mov x5, #1
    mov x6, #-1

    cmp w3, w4
    csel x2, x5, x2, gt
    csel x2, x6, x2, lt
    csel x2, xzr, x2, eq

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

__strerror_err_0:                       ; 0

    adrp x0, err_str_0 @PAGE
    add x0, x0, err_str_0 @PAGEOFF
    mov x1, #18
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

__clear_buf:                            ; input: x0 -> buffer addr, x1 -> buffer len; output: x0 -> buffer addr
    
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov w3, #0

__clear_buf_loop:

    strb w3, [x0], #1                   ; set every byte to 0b00000000 in a recursive loop
    subs x1, x1, #1
    bne __clear_buf_loop_end

__clear_buf_loop_end:

    ldp x29, x30, [sp], #16
    ret

__perror:                               ; input: x0 -> error code, output: void

    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x5, x0
    bl __strerror
    mov x3, x0
    mov x4, x1
    
    mov x0, #1
    adrp x1, err_str_err_code @PAGE
    add x1, x1, err_str_err_code @PAGEOFF
    mov x2, err_str_err_code_len
    mov x16, #4
    svc #0x80

    mov x0, x5
    bl __num_to_ascii
    mov x2, x0
    mov x0, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #':'
    mov x2, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #' '
    mov x2, #1
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, x3
    mov x2, x4
    mov x16, #4
    svc #0x80

    mov x0, #1
    mov x1, #'\n'
    mov x2, #1
    mov x16, #4
    svc #0x80

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

; debug messages

    debug_checkpoint_str: .asciz "here\n" ; 6
    debug_checkpoint_str_len = . - debug_checkpoint_str
    debug_cwd: .ascii "\nCurrent directory: "
    debug_cwd_len = . - debug_cwd
    debug_open: .ascii "Attempting to open: "
    debug_open_len = . - debug_open

    debug_fd_dir: .asciz "/dev/fd"

    debug_print_fd: .asciz "\n[PID, FD opened]: "
    debug_print_fd_len = . - debug_print_fd

; debug commands & stuff

    cmd_shell_path: .asciz "/bin/sh"
    cmd_dash_c: .asciz "-c"
    cmd_lsof_f: .asciz "lsof -p "
    cmd_lsof_s: .asciz " > /Users/trangtran/Desktop/coding_files/assembly_shi/ARM-assembly-web-server/fds.txt"

.align 5
    cmd_lsof_argv:
        .quad cmd_shell_path
        .quad cmd_dash_c
        .quad cmd_buffer
        .quad 0

.align 2
    dirent_struct:
        .quad 0     ; d_ino
        .quad 0     ; d_seekoff
        .short 0    ; d_reclen
        .short 0    ; d_namlen
        .space 1024 ; d_name

; error messages

; messages for strerror(), supports errno = 1 - 35, 41 - 66
; general errors
    err_str_0: .ascii "Undefined error: 0"                               ; 0
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

    msg_show_file_contents: .ascii "File contents of file "
    msg_show_file_contents_len = . - msg_show_file_contents


.section __DATA, __bss                  ; auto zeroed at startup

; buffers
    incoming_buffer: .space 30721       ; incoming connections buffer
    file_contents: .space 30000         ; html file content buffer
    stat_struct: .space 200             ; file stat buffer, for file size
    send_buffer: .space 30000           ; outgoing response buffer
    general_buffer: .space 2048         ; general buffer for functions
    nta_buffer: .space 32               ; __num_to_ascii's buffer

; for debugging purposes
    cmd_buffer: .space 256              ; for concatenating strings for a command
    get_fd_buffer: .space 4096          ; for retrieving fds from /dev/fd


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
    fail_create_socket: .asciz "Failed to create client socket.\nError code: "
    fail_create_socket_len = . - fail_create_socket
    
    send_success: .asciz "Successfully transmitted data to client.\n"
    send_no_data_to_client: .asciz "The client requested no data or a general read and write error encountered.\n"

    filename: .asciz "/Users/trangtran/Desktop/coding_files/assembly_shi/ARM-assembly-web-server/template.html"
    filename_len = . - filename

    str_one_dot: .asciz "."
    str_two_dot: .asciz ".."