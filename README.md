# ARM-assembly-web-server

## Overview

A basic HTTP web server written in ARM assembly using Apple's AArch64 architecture. This project is built in pure assembly, all kernel functions are replaced with raw syscalls. Certain function with no kernel implementation are also implemented in Assembly as well.

### ETA:

This server is a work in progress and bugs are everywhere. I can't guarantee any deadlines on the completion of this project.

## Documentation

Documentation is available [here](docs.md).

## Resources

syscalls.txt: https://github.com/apple/darwin-xnu/blob/main/bsd/kern/syscalls.master <br>
ARM Cortex A-Series Manual: https://cs140e.sergio.bz/docs/ARMv8-A-Programmer-Guide.pdf <br>
ARM Manual: https://developer.arm.com/documentation/ddi0487/maa/?lang=en