# ARM-assembly-web-server

A basic HTTP web server written in ARM assembly using Apple's AArch64 architecture. This project is built in pure assembly, all kernel functions are replaced with raw syscalls, and certain functions are implemented in raw Assembly.

## Side Note:

This server is a work in progress. This is an initial upload to make sure I don't lose my work. Documentation will be available as soon as the server is functional.

## Sources/Documentation

syscalls.txt: https://github.com/apple/darwin-xnu/blob/main/bsd/kern/syscalls.master
ARM Cortex A-Series Manual: https://cs140e.sergio.bz/docs/ARMv8-A-Programmer-Guide.pdf
ARM Manual: https://developer.arm.com/documentation/ddi0487/maa/?lang=en