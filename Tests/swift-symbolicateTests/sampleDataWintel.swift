//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

let wintelCrashLog = #"""
S:\swift-symbolicate>.build\debug\crashMe
About to crash

*** Exception c0000005: Backtracing from 0x7ff715ac1464... done ***

*** Program crashed: Access violation at 0x0000000000000006 ***

Platform: x86_64 Windows 11.0 build 26200

Thread 0 crashed:

0               0x00007ff715ac1464 level4() + 388 in crashMe.exe at S:\swift-symbolicate\Sources\crashMe\crashMe.swift:16
1 [ra]          0x00007ff715ac12d9 level3() + 8 in crashMe.exe at S:\swift-symbolicate\Sources\crashMe\crashMe.swift:10
2 [ra]          0x00007ff715ac12c9 level2() + 8 in crashMe.exe at S:\swift-symbolicate\Sources\crashMe\crashMe.swift:6
3 [ra]          0x00007ff715ac12b9 level1() + 8 in crashMe.exe at S:\swift-symbolicate\Sources\crashMe\crashMe.swift:2
4 [ra]          0x00007ff715ac1489 static Crash.main() + 8 in crashMe.exe at S:\swift-symbolicate\Sources\crashMe\crashMe.swift:22
5 [ra] [system] 0x00007ff715ac1499 static Crash.$main() + 8 in crashMe.exe
6 [ra]          0x00007ff715ac14b9 main + 8 in crashMe.exe
7 [ra] [system] 0x00007ff715ac19e4 __scrt_common_main_seh + 267 in crashMe.exe at D:\a\_work\1\s\src\vctools\crt\vcstartup\src\startup\exe_common.inl:288
8 [ra]          0x00007ffd4f50e8d7 <unknown> in KERNEL32.DLL
9 [ra]          0x00007ffd5156c48c <unknown> in ntdll.dll


Registers:

rax 0x0000000000000006  6
rdx 0x0000000000000000  0
rcx 0x000001b7f2e27210  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
rbx 0x000001b7f2e32f10  20 2f e3 f2 b7 01 00 00 00 00 00 00 00 00 00 00   /ãò············
rsi 0x0000000000000000  0
rdi 0x000001b7f2e39bd0  60 33 e3 f2 b7 01 00 00 40 2f e3 f2 b7 01 00 00  `3ãò····@/ãò····
rbp 0x0000000000000000  0
rsp 0x000000a6267df740  77 00 73 00 5c 00 63 00 72 00 61 00 73 00 68 00  w·s·\·c·r·a·s·h·
 r8 0x000001b7f2f21380  c0 0c f2 f2 b7 01 00 00 00 72 e2 f2 b7 01 00 00  À·òò·····râò····
 r9 0x7ffffffefffffffe  9223372032559808510
r10 0x000001b7f2f20000  00 00 00 00 00 00 00 00 e0 6f e2 f2 b7 01 00 00  ········àoâò····
r11 0x00000000ffffffff  4294967295
r12 0x0000000000000000  0
r13 0x0000000000000000  0
r14 0x0000000000000000  0
r15 0x0000000000000000  0
rip 0x00007ff715ac1464  48 c7 00 2a 00 00 00 48 81 c4 a8 00 00 00 c3 66  HÇ·*···H·Ä¨···Ãf

rflags 0x0000000000010206  PF

cs 0x0033  fs 0x0053  gs 0x002b


Images (23 omitted):

0x00007ff715ac0000–0x00007ff715ac2600 8a15f8d333aeebaa4c4c44205044422e01000000 crashMe.exe  S:\swift-symbolicate\.build\debug\crashMe.exe
0x00007ffd4f4e0000–0x00007ffd4f567000 de45b7f7697a1bef7c8be0c4fded10a101000000 KERNEL32.DLL C:\windows\System32\KERNEL32.DLL
0x00007ffd514e0000–0x00007ffd51653000 04409f5a80db506bbcbd7b6c55417b0401000000 ntdll.dll    C:\windows\SYSTEM32\ntdll.dll

Backtrace took 0.03s


S:\swift-symbolicate>
"""#
