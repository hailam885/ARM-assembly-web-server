# Documentation

## Overview

This is a quick overview of some of the functions/procedures in the code without going too much in technical details.

Clarifications (unless specified otherwise):
 - "Integer" refers to 64-bit integers, signed or unsigned
 - "Address" refers memory address

*The Registers Used section specifies exactly what registers the function uses. Always assume their previous values are discarded and replaced with garbage. The section will only specify any other register besides ones explicitly stated in Input/Output sections. All registers in Input/Output will be used. If a register in the Input section is not specified in the Output section, assume it contains garbage values. If the section specified "All safe", that means there are no other besides ones specified in Input/Output. Hopefully, in the future, if I'm feeling energized to work, I will save & restore registers on the stack for every functoin.*

*I am doing a massive rewrite so certain functions aren't included in the codebase.*

---

## Functions

### __htons_16

Converts input integer from host's endian to network's endian format (in this case a little endian to big endian conversion). The user is responsible for ensuring input data integrity (zeroing upper 48 bits).

Input:
 - x0: Integer in host's format

Output:
 - x0: Integer in network's format

*Registers Used: x9, x10, x11*

---

### __close_fd_64

Takes in an integer representing a file descriptor and closes it. If close() is unsuccessful, shutdown() is used instead.

*Note: This only applies to file descriptors corresponding to networking sockets. While using it is fine to use with regular file descriptors since it returns -1 with ENOTSOCK, it is recommended to use close() and terminate program if fails.*

Input:
 - x0: Integer/file descriptor

Output:
 - Nothing

*Registers Used: x1*

---

### __strlen

Takes in the string address (or a raw C array), and returns the string length. Only applies to null-terminated strings.

Input:
 - x0: String address

Output:
 - x0: String length
 - x1: String address

*Registers Used: x2*

---

### __strcat

Takes in two string addresses, and concatenates the second one to the first one at the end, overwriting the first one's null terminator. Only applies to null-terminated strings. Does not do bounds checking

Input:
 - x0: First string address
 - x1: Second string address

Output:
 - x0: First string address
 - x1: Second string address

*Registers Used: x3, x4*

---

### __strncat (NOT TESTED)

Takes in two string addresses and two sizes, and concatenates the second one to the first one at the end, overwriting the first one's null terminator. Only applies to null-terminated strings. Will return & do nothing if the length to copy from x1 will cause a buffer overflow on x0 (assuming x0 is type ".space"). If the specified length to copy from second string does not include a null terminator at the end, the function will not add a null terminator.

Input:
 - x0: First string address
 - x1: Second string address
 - x2: Max buffer size of first string
 - x3: Length to copy from second string

Output:
 - x0: First string address
 - x1: Second string address

*Registers Used: x4, x5, x6, x7*

---

### __strcmp (NOT TESTED)

Compares two strings, return 0 if they are equal, and return 1 if "x0 > x1" in terms of ASCII and -1 if "x1 > x0" in terms of ASCII (generally who comes first in a dictionary). Both strings are intact before, during, and after execution.

Input:
 - x0: First string address
 - x1: Second string address

Output:
 - x2: Result of strcmp(x0, x1)
 - (addresses in x0, x1 left intact)

*Registers Used: x3, x4, x5*

---

### __ascii_to_num (NOT TESTED)

Converts an ASCII string into an integer. This does not account for integer overflows. String has to be null-terminated or contains a character (that signifies stop parsing) with an ASCII code not in range 48-57.

Input:
 - x0: String address

Output:
 - x1: Number

*Registers Used: x2, x3*

---

### __num_to_ascii

Converts an integer to an ASCII string. Doesn't come with the null terminator

*Note: String output data will be stored in nta_buffer regardless if nta_buffer has previous data or not; clear nta_buffer or deal with it before calling this function. Any existing data will be overwritten, and any data that is not within the "length" of the integer will be left intact, causing corruption. User will have to manually call __clear_buf before using this function.*

Input:
 - x0: Integer

Output:
 - x0: String length
 - x1: String address

*Registers Used: x2, x3, x4, x5, x6, x7*

---

### __strerror

Converts error codes into an ASCII string description. Returned strings do not have null terminator and it's the user's job to handle it.

Input:
 - x0: Integer

Output:
 - x0: String address
 - x1: String length

*Registers Used: All safe*

---

### __perror (NOT TESTED)

Prints the error code with the description.

Input: 
 - x0: Integer

Output:
 - void

*Registers Used: x2, x3, x4, x5*

---

### __clear_buf (NOT TESTED)

Zeros the buffer in the given address and for a given length.

*Assume x1 will be used as scratch register.*

Input:
 - x0: Buffer address
 - x1: Desired length to zero

Output:
 - x0: Buffer address

*Registers Used: x3*