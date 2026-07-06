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

let plainCrashLogSymbolicatedAllRegistersMultithreaded = """
swift runtime: unknown backtracing setting 'thread'
swift runtime: unknown backtracing setting 'thread'

*** Signal 11: Backtracing from 0x100b68b24... done ***

*** Program crashed: Bad pointer dereference at 0x0000000000000008 ***

Platform: arm64 macOS 26.4 (25E230)

Thread 0:

 x0 0x0000000000000a03  2563
 x1 0x0000000000000000  0
 x2 0x0000000000000001  1
 x3 0x0000000000000001  1
 x4 0x000000000000000a  10
 x5 0x0000000000000000  0
 x6 0x0000000000000034  52
 x7 0x0000000000000000  0
 x8 0x00000001f9a1c898  03 0a 00 00 00 00 00 00 3d 00 65 3b 56 1d 92 c6  ········=·e;V··Æ
 x9 0x0000000000004003  16387
x10 0x0000000000000011  17
x11 0x00000000fffffffd  4294967293
x12 0x0000000000000100  256
x13 0x0000000000000100  256
x14 0x0000000000000100  256
x15 0x0000010000000100  1099511628032
x16 0x000000000000014e  334
x17 0x00000001fb049f10  00 f3 b5 8d 01 00 00 00 18 35 b6 8d 01 00 00 00  ·óµ······5¶·····
x18 0x0000000000000000  0
x19 0x000000016f296ee0  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x20 0x000000016f296ef0  0a 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x21 0x000000016f297108  38 99 06 fb 01 00 00 00 48 c0 75 f9 01 00 00 00  8··û····HÀuù····
x22 0xfffffffffffffff0  18446744073709551600
x23 0x00000001f9a13e20  ff 3f 00 00 00 00 00 00 00 40 00 00 00 00 00 00  ÿ?·······@······
x24 0x0000000000000001  1
x25 0x000000016f297270  48 c0 75 f9 01 00 00 00 2f 64 79 6c 64 00 00 00  HÀuù····/dyld···
x26 0x00000001f9a13e30  03 02 00 00 00 00 00 00 50 3f a1 f9 01 00 00 00  ········P?¡ù····
x27 0x0000000000000000  0
x28 0x0000000000000000  0
 fp 0x000000016f296ed0  10 6f 29 6f 01 00 00 00 24 4e a4 8d 01 00 00 00  ·o)o····$N¤·····
 lr 0x000000018da3bcc0  60 fe ff 36 05 ad 01 94 08 00 40 b9 1f f1 00 71  `þÿ6·­····@¹·ñ·q
 sp 0x000000016f296ea0  30 3e a1 f9 01 00 00 00 70 72 29 6f 01 00 00 00  0>¡ù····pr)o····
 pc 0x000000018db5f308  03 01 00 54 7f 23 03 d5 fd 7b bf a9 fd 03 00 91  ···T·#·Õý{¿©ý···

  0               0x000000018db5f308 __semwait_signal + 8 in libsystem_kernel.dylib
  1 [ra]          0x000000018da44e24 sleep + 52 in libsystem_c.dylib
  2 [ra]          0x0000000100b69208 static MultithreadedCrash.main() + 636 in crashMeMultithreaded at /Users/carlpeto/Code/swift-symbolicate/Sources/crashMeMultithreaded/crashMeMultithreaded.swift:88:7
  3 [ra] [system] 0x0000000100b69450 static MultithreadedCrash.$main() + 12 in crashMeMultithreaded at /<compiler-generated>
  4 [ra] [system] 0x0000000100b69468 crashMeMultithreaded_main + 12 in crashMeMultithreaded at /Users/carlpeto/Code/swift-symbolicate/Sources/crashMeMultithreaded/crashMeMultithreaded.swift
  5 [ra] [system] 0x000000018d7e3da4 start + 6992 in dyld
...

Thread 1:

 x0 0x0000000000000a03  2563
 x1 0x0000000000000000  0
 x2 0x0000000000000001  1
 x3 0x0000000000000001  1
 x4 0x000000000000000a  10
 x5 0x0000000000000000  0
 x6 0x0000000000000034  52
 x7 0x0000000000000000  0
 x8 0x00000001f9a1c898  03 0a 00 00 00 00 00 00 3d 00 65 3b 56 1d 92 c6  ········=·e;V··Æ
 x9 0x0000000000004003  16387
x10 0x0000000000000011  17
x11 0x0000000000000000  0
x12 0x0000000000000000  0
x13 0x0000000000000000  0
x14 0x0000000000000000  0
x15 0x0000000000000000  0
x16 0x000000000000014e  334
x17 0x00000001fb049f10  00 f3 b5 8d 01 00 00 00 18 35 b6 8d 01 00 00 00  ·óµ······5¶·····
x18 0x0000000000000000  0
x19 0x000000016f31ef60  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x20 0x000000016f31ef70  0a 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x21 0x0000000000000000  0
x22 0x0000000000000000  0
x23 0x0000000000000000  0
x24 0x0000000000000000  0
x25 0x0000000000000000  0
x26 0x0000000000000000  0
x27 0x0000000000000000  0
x28 0x0000000000000000  0
 fp 0x000000016f31ef50  90 ef 31 6f 01 00 00 00 24 4e a4 8d 01 00 00 00  ·ï1o····$N¤·····
 lr 0x000000018da3bcc0  60 fe ff 36 05 ad 01 94 08 00 40 b9 1f f1 00 71  `þÿ6·­····@¹·ñ·q
 sp 0x000000016f31ef20  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
 pc 0x000000018db5f308  03 01 00 54 7f 23 03 d5 fd 7b bf a9 fd 03 00 91  ···T·#·Õý{¿©ý···

  0              0x000000018db5f308 __semwait_signal + 8 in libsystem_kernel.dylib
  1 [ra]         0x000000018da44e24 sleep + 52 in libsystem_c.dylib
  2 [ra]         0x0000000100b68f64 closure #2 in static MultithreadedCrash.spawnThread(_:) + 32 in crashMeMultithreaded at /Users/carlpeto/Code/swift-symbolicate/Sources/crashMeMultithreaded/crashMeMultithreaded.swift:62:39
  3 [ra] [thunk] 0x0000000100b68f84 @objc closure #2 in static MultithreadedCrash.spawnThread(_:) + 12 in crashMeMultithreaded at /<compiler-generated>
  4 [ra]         0x000000018db9fc58 _pthread_start + 136 in libsystem_pthread.dylib
...

Thread 2:

 x0 0x0000000000000a03  2563
 x1 0x0000000000000000  0
 x2 0x0000000000000001  1
 x3 0x0000000000000001  1
 x4 0x000000000000000a  10
 x5 0x0000000000000000  0
 x6 0x0000000000000034  52
 x7 0x0000000000000000  0
 x8 0x00000001f9a1c898  03 0a 00 00 00 00 00 00 3d 00 65 3b 56 1d 92 c6  ········=·e;V··Æ
 x9 0x0000000000004003  16387
x10 0x0000000000000011  17
x11 0x0000000000000000  0
x12 0x0000000000000000  0
x13 0x0000000000000000  0
x14 0x0000000000000000  0
x15 0x0000000000000000  0
x16 0x000000000000014e  334
x17 0x00000001fb049f10  00 f3 b5 8d 01 00 00 00 18 35 b6 8d 01 00 00 00  ·óµ······5¶·····
x18 0x0000000000000000  0
x19 0x000000016f3aaf60  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x20 0x000000016f3aaf70  0a 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x21 0x0000000000000000  0
x22 0x0000000000000000  0
x23 0x0000000000000000  0
x24 0x0000000000000000  0
x25 0x0000000000000000  0
x26 0x0000000000000000  0
x27 0x0000000000000000  0
x28 0x0000000000000000  0
 fp 0x000000016f3aaf50  90 af 3a 6f 01 00 00 00 24 4e a4 8d 01 00 00 00  ·¯:o····$N¤·····
 lr 0x000000018da3bcc0  60 fe ff 36 05 ad 01 94 08 00 40 b9 1f f1 00 71  `þÿ6·­····@¹·ñ·q
 sp 0x000000016f3aaf20  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
 pc 0x000000018db5f308  03 01 00 54 7f 23 03 d5 fd 7b bf a9 fd 03 00 91  ···T·#·Õý{¿©ý···

  0              0x000000018db5f308 __semwait_signal + 8 in libsystem_kernel.dylib
  1 [ra]         0x000000018da44e24 sleep + 52 in libsystem_c.dylib
  2 [ra]         0x0000000100b68f64 closure #2 in static MultithreadedCrash.spawnThread(_:) + 32 in crashMeMultithreaded at /Users/carlpeto/Code/swift-symbolicate/Sources/crashMeMultithreaded/crashMeMultithreaded.swift:62:39
  3 [ra] [thunk] 0x0000000100b68f84 @objc closure #2 in static MultithreadedCrash.spawnThread(_:) + 12 in crashMeMultithreaded at /<compiler-generated>
  4 [ra]         0x000000018db9fc58 _pthread_start + 136 in libsystem_pthread.dylib
...

Thread 3:

 x0 0x0000000000000a03  2563
 x1 0x0000000000000000  0
 x2 0x0000000000000001  1
 x3 0x0000000000000001  1
 x4 0x000000000000000a  10
 x5 0x0000000000000000  0
 x6 0x0000000000000034  52
 x7 0x0000000000000000  0
 x8 0x00000001f9a1c898  03 0a 00 00 00 00 00 00 3d 00 65 3b 56 1d 92 c6  ········=·e;V··Æ
 x9 0x0000000000004003  16387
x10 0x0000000000000011  17
x11 0x0000000000000000  0
x12 0x0000000000000000  0
x13 0x0000000000000000  0
x14 0x0000000000000000  0
x15 0x0000000000000000  0
x16 0x000000000000014e  334
x17 0x00000001fb049f10  00 f3 b5 8d 01 00 00 00 18 35 b6 8d 01 00 00 00  ·óµ······5¶·····
x18 0x0000000000000000  0
x19 0x000000016f436f60  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x20 0x000000016f436f70  0a 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x21 0x0000000000000000  0
x22 0x0000000000000000  0
x23 0x0000000000000000  0
x24 0x0000000000000000  0
x25 0x0000000000000000  0
x26 0x0000000000000000  0
x27 0x0000000000000000  0
x28 0x0000000000000000  0
 fp 0x000000016f436f50  90 6f 43 6f 01 00 00 00 24 4e a4 8d 01 00 00 00  ·oCo····$N¤·····
 lr 0x000000018da3bcc0  60 fe ff 36 05 ad 01 94 08 00 40 b9 1f f1 00 71  `þÿ6·­····@¹·ñ·q
 sp 0x000000016f436f20  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
 pc 0x000000018db5f308  03 01 00 54 7f 23 03 d5 fd 7b bf a9 fd 03 00 91  ···T·#·Õý{¿©ý···

  0              0x000000018db5f308 __semwait_signal + 8 in libsystem_kernel.dylib
  1 [ra]         0x000000018da44e24 sleep + 52 in libsystem_c.dylib
  2 [ra]         0x0000000100b68f64 closure #2 in static MultithreadedCrash.spawnThread(_:) + 32 in crashMeMultithreaded at /Users/carlpeto/Code/swift-symbolicate/Sources/crashMeMultithreaded/crashMeMultithreaded.swift:62:39
  3 [ra] [thunk] 0x0000000100b68f84 @objc closure #2 in static MultithreadedCrash.spawnThread(_:) + 12 in crashMeMultithreaded at /<compiler-generated>
  4 [ra]         0x000000018db9fc58 _pthread_start + 136 in libsystem_pthread.dylib
...

Thread 4:

 x0 0x0000000000000a03  2563
 x1 0x0000000000000000  0
 x2 0x0000000000000001  1
 x3 0x0000000000000001  1
 x4 0x000000000000000a  10
 x5 0x0000000000000000  0
 x6 0x0000000000000034  52
 x7 0x0000000000000000  0
 x8 0x00000001f9a1c898  03 0a 00 00 00 00 00 00 3d 00 65 3b 56 1d 92 c6  ········=·e;V··Æ
 x9 0x0000000000004003  16387
x10 0x0000000000000011  17
x11 0x0000000000000000  0
x12 0x0000000000000000  0
x13 0x0000000000000000  0
x14 0x0000000000000000  0
x15 0x0000000000000000  0
x16 0x000000000000014e  334
x17 0x00000001fb049f10  00 f3 b5 8d 01 00 00 00 18 35 b6 8d 01 00 00 00  ·óµ······5¶·····
x18 0x0000000000000000  0
x19 0x000000016f4c2f60  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x20 0x000000016f4c2f70  0a 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x21 0x0000000000000000  0
x22 0x0000000000000000  0
x23 0x0000000000000000  0
x24 0x0000000000000000  0
x25 0x0000000000000000  0
x26 0x0000000000000000  0
x27 0x0000000000000000  0
x28 0x0000000000000000  0
 fp 0x000000016f4c2f50  90 2f 4c 6f 01 00 00 00 24 4e a4 8d 01 00 00 00  ·/Lo····$N¤·····
 lr 0x000000018da3bcc0  60 fe ff 36 05 ad 01 94 08 00 40 b9 1f f1 00 71  `þÿ6·­····@¹·ñ·q
 sp 0x000000016f4c2f20  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
 pc 0x000000018db5f308  03 01 00 54 7f 23 03 d5 fd 7b bf a9 fd 03 00 91  ···T·#·Õý{¿©ý···

  0              0x000000018db5f308 __semwait_signal + 8 in libsystem_kernel.dylib
  1 [ra]         0x000000018da44e24 sleep + 52 in libsystem_c.dylib
  2 [ra]         0x0000000100b68f64 closure #2 in static MultithreadedCrash.spawnThread(_:) + 32 in crashMeMultithreaded at /Users/carlpeto/Code/swift-symbolicate/Sources/crashMeMultithreaded/crashMeMultithreaded.swift:62:39
  3 [ra] [thunk] 0x0000000100b68f84 @objc closure #2 in static MultithreadedCrash.spawnThread(_:) + 12 in crashMeMultithreaded at /<compiler-generated>
  4 [ra]         0x000000018db9fc58 _pthread_start + 136 in libsystem_pthread.dylib
...

Thread 5:

 x0 0x0000000000000a03  2563
 x1 0x0000000000000000  0
 x2 0x0000000000000001  1
 x3 0x0000000000000001  1
 x4 0x000000000000000a  10
 x5 0x0000000000000000  0
 x6 0x0000000000000034  52
 x7 0x0000000000000000  0
 x8 0x00000001f9a1c898  03 0a 00 00 00 00 00 00 3d 00 65 3b 56 1d 92 c6  ········=·e;V··Æ
 x9 0x0000000000004003  16387
x10 0x0000000000000011  17
x11 0x0000000000000000  0
x12 0x0000000000000000  0
x13 0x0000000000000000  0
x14 0x0000000000000000  0
x15 0x0000000000000000  0
x16 0x000000000000014e  334
x17 0x00000001fb049f10  00 f3 b5 8d 01 00 00 00 18 35 b6 8d 01 00 00 00  ·óµ······5¶·····
x18 0x0000000000000000  0
x19 0x000000016f54ef60  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x20 0x000000016f54ef70  0a 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x21 0x0000000000000000  0
x22 0x0000000000000000  0
x23 0x0000000000000000  0
x24 0x0000000000000000  0
x25 0x0000000000000000  0
x26 0x0000000000000000  0
x27 0x0000000000000000  0
x28 0x0000000000000000  0
 fp 0x000000016f54ef50  90 ef 54 6f 01 00 00 00 24 4e a4 8d 01 00 00 00  ·ïTo····$N¤·····
 lr 0x000000018da3bcc0  60 fe ff 36 05 ad 01 94 08 00 40 b9 1f f1 00 71  `þÿ6·­····@¹·ñ·q
 sp 0x000000016f54ef20  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
 pc 0x000000018db5f308  03 01 00 54 7f 23 03 d5 fd 7b bf a9 fd 03 00 91  ···T·#·Õý{¿©ý···

  0              0x000000018db5f308 __semwait_signal + 8 in libsystem_kernel.dylib
  1 [ra]         0x000000018da44e24 sleep + 52 in libsystem_c.dylib
  2 [ra]         0x0000000100b68f64 closure #2 in static MultithreadedCrash.spawnThread(_:) + 32 in crashMeMultithreaded at /Users/carlpeto/Code/swift-symbolicate/Sources/crashMeMultithreaded/crashMeMultithreaded.swift:62:39
  3 [ra] [thunk] 0x0000000100b68f84 @objc closure #2 in static MultithreadedCrash.spawnThread(_:) + 12 in crashMeMultithreaded at /<compiler-generated>
  4 [ra]         0x000000018db9fc58 _pthread_start + 136 in libsystem_pthread.dylib
...

Thread 6 crashed:

 x0 0x0000000000000001  1
 x1 0x000000000000033f  831
 x2 0x000000000000033f  831
 x3 0x0000000000000005  5
 x4 0x0000000101393440  80 00 00 00 20 00 00 00 30 00 00 00 00 00 00 00  ···· ···0·······
 x5 0x000000016f5dab90  0a 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
 x6 0x000000000000000a  10
 x7 0x0000000000000000  0
 x8 0x000000000000002a  42
 x9 0x0000000000000008  8
x10 0x0000000000000002  2
x11 0x00000000fffffffd  4294967293
x12 0x0000000000000000  0
x13 0x0000000000000000  0
x14 0x0000000000000000  0
x15 0x0000000000000000  0
x16 0x92b1000101380040  10570229804730679360
x17 0x000000000000133f  4927
x18 0x0000000000000000  0
x19 0x000000016f5db000  54 43 3b 6a de a6 08 af 00 00 00 00 00 00 00 00  TC;jÞ¦·¯········
x20 0x0000000000000000  0
x21 0x0000000000000000  0
x22 0x0000000000000000  0
x23 0x0000000000000000  0
x24 0x0000000000000000  0
x25 0x0000000000000000  0
x26 0x0000000000000000  0
x27 0x0000000000000000  0
x28 0x0000000000000000  0
 fp 0x000000016f5daf80  90 af 5d 6f 01 00 00 00 bc 89 b6 00 01 00 00 00  ·¯]o····¼·¶·····
 lr 0x0000000100b68aa0  a8 03 5e f8 a8 83 1f f8 a8 83 5f f8 a8 83 1e f8  ¨·^ø¨··ø¨·_ø¨··ø
 sp 0x000000016f5daf00  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
 pc 0x0000000100b68b24  28 01 00 f9 fd 7b 48 a9 ff 43 02 91 c0 03 5f d6  (··ùý{H©ÿC··À·_Ö

  0              0x0000000100b68b24 static MultithreadedCrash.reallyCrashMe() + 352 in crashMeMultithreaded at /Users/carlpeto/Code/swift-symbolicate/Sources/crashMeMultithreaded/crashMeMultithreaded.swift:36:17
  1 [ra]         0x0000000100b689bc crashMe() + 12 in crashMeMultithreaded at /Users/carlpeto/Code/swift-symbolicate/Sources/crashMeMultithreaded/crashMeMultithreaded.swift:14:24
  2 [ra]         0x0000000100b68f0c closure #1 in static MultithreadedCrash.spawnThread(_:) + 28 in crashMeMultithreaded at /Users/carlpeto/Code/swift-symbolicate/Sources/crashMeMultithreaded/crashMeMultithreaded.swift:50:35
  3 [ra] [thunk] 0x0000000100b68f3c @objc closure #1 in static MultithreadedCrash.spawnThread(_:) + 12 in crashMeMultithreaded at /<compiler-generated>
  4 [ra]         0x000000018db9fc58 _pthread_start + 136 in libsystem_pthread.dylib
...

Thread 7:

 x0 0x0000000000000a03  2563
 x1 0x0000000000000000  0
 x2 0x0000000000000001  1
 x3 0x0000000000000001  1
 x4 0x000000000000000a  10
 x5 0x0000000000000000  0
 x6 0x0000000000000034  52
 x7 0x0000000000000000  0
 x8 0x00000001f9a1c898  03 0a 00 00 00 00 00 00 3d 00 65 3b 56 1d 92 c6  ········=·e;V··Æ
 x9 0x0000000000004003  16387
x10 0x0000000000000011  17
x11 0x0000000000000000  0
x12 0x0000000000000000  0
x13 0x0000000000000000  0
x14 0x0000000000000000  0
x15 0x0000000000000000  0
x16 0x000000000000014e  334
x17 0x00000001fb049f10  00 f3 b5 8d 01 00 00 00 18 35 b6 8d 01 00 00 00  ·óµ······5¶·····
x18 0x0000000000000000  0
x19 0x000000016f666f60  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x20 0x000000016f666f70  0a 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x21 0x0000000000000000  0
x22 0x0000000000000000  0
x23 0x0000000000000000  0
x24 0x0000000000000000  0
x25 0x0000000000000000  0
x26 0x0000000000000000  0
x27 0x0000000000000000  0
x28 0x0000000000000000  0
 fp 0x000000016f666f50  90 6f 66 6f 01 00 00 00 24 4e a4 8d 01 00 00 00  ·ofo····$N¤·····
 lr 0x000000018da3bcc0  60 fe ff 36 05 ad 01 94 08 00 40 b9 1f f1 00 71  `þÿ6·­····@¹·ñ·q
 sp 0x000000016f666f20  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
 pc 0x000000018db5f308  03 01 00 54 7f 23 03 d5 fd 7b bf a9 fd 03 00 91  ···T·#·Õý{¿©ý···

  0              0x000000018db5f308 __semwait_signal + 8 in libsystem_kernel.dylib
  1 [ra]         0x000000018da44e24 sleep + 52 in libsystem_c.dylib
  2 [ra]         0x0000000100b68f64 closure #2 in static MultithreadedCrash.spawnThread(_:) + 32 in crashMeMultithreaded at /Users/carlpeto/Code/swift-symbolicate/Sources/crashMeMultithreaded/crashMeMultithreaded.swift:62:39
  3 [ra] [thunk] 0x0000000100b68f84 @objc closure #2 in static MultithreadedCrash.spawnThread(_:) + 12 in crashMeMultithreaded at /<compiler-generated>
  4 [ra]         0x000000018db9fc58 _pthread_start + 136 in libsystem_pthread.dylib
...

Thread 8:

 x0 0x0000000000000a03  2563
 x1 0x0000000000000000  0
 x2 0x0000000000000001  1
 x3 0x0000000000000001  1
 x4 0x000000000000000a  10
 x5 0x0000000000000000  0
 x6 0x0000000000000034  52
 x7 0x0000000000000000  0
 x8 0x00000001f9a1c898  03 0a 00 00 00 00 00 00 3d 00 65 3b 56 1d 92 c6  ········=·e;V··Æ
 x9 0x0000000000004003  16387
x10 0x0000000000000011  17
x11 0x0000000000000000  0
x12 0x0000000000000000  0
x13 0x0000000000000000  0
x14 0x0000000000000000  0
x15 0x0000000000000000  0
x16 0x000000000000014e  334
x17 0x00000001fb049f10  00 f3 b5 8d 01 00 00 00 18 35 b6 8d 01 00 00 00  ·óµ······5¶·····
x18 0x0000000000000000  0
x19 0x000000016f6f2f60  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x20 0x000000016f6f2f70  0a 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x21 0x0000000000000000  0
x22 0x0000000000000000  0
x23 0x0000000000000000  0
x24 0x0000000000000000  0
x25 0x0000000000000000  0
x26 0x0000000000000000  0
x27 0x0000000000000000  0
x28 0x0000000000000000  0
 fp 0x000000016f6f2f50  90 2f 6f 6f 01 00 00 00 24 4e a4 8d 01 00 00 00  ·/oo····$N¤·····
 lr 0x000000018da3bcc0  60 fe ff 36 05 ad 01 94 08 00 40 b9 1f f1 00 71  `þÿ6·­····@¹·ñ·q
 sp 0x000000016f6f2f20  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
 pc 0x000000018db5f308  03 01 00 54 7f 23 03 d5 fd 7b bf a9 fd 03 00 91  ···T·#·Õý{¿©ý···

  0              0x000000018db5f308 __semwait_signal + 8 in libsystem_kernel.dylib
  1 [ra]         0x000000018da44e24 sleep + 52 in libsystem_c.dylib
  2 [ra]         0x0000000100b68f64 closure #2 in static MultithreadedCrash.spawnThread(_:) + 32 in crashMeMultithreaded at /Users/carlpeto/Code/swift-symbolicate/Sources/crashMeMultithreaded/crashMeMultithreaded.swift:62:39
  3 [ra] [thunk] 0x0000000100b68f84 @objc closure #2 in static MultithreadedCrash.spawnThread(_:) + 12 in crashMeMultithreaded at /<compiler-generated>
  4 [ra]         0x000000018db9fc58 _pthread_start + 136 in libsystem_pthread.dylib
...

Thread 9:

 x0 0x0000000000000a03  2563
 x1 0x0000000000000000  0
 x2 0x0000000000000001  1
 x3 0x0000000000000001  1
 x4 0x000000000000000a  10
 x5 0x0000000000000000  0
 x6 0x0000000000000034  52
 x7 0x0000000000000000  0
 x8 0x00000001f9a1c898  03 0a 00 00 00 00 00 00 3d 00 65 3b 56 1d 92 c6  ········=·e;V··Æ
 x9 0x0000000000004003  16387
x10 0x0000000000000011  17
x11 0x0000000000000000  0
x12 0x0000000000000000  0
x13 0x0000000000000000  0
x14 0x0000000000000000  0
x15 0x0000000000000000  0
x16 0x000000000000014e  334
x17 0x00000001fb049f10  00 f3 b5 8d 01 00 00 00 18 35 b6 8d 01 00 00 00  ·óµ······5¶·····
x18 0x0000000000000000  0
x19 0x000000016f77ef60  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x20 0x000000016f77ef70  0a 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
x21 0x0000000000000000  0
x22 0x0000000000000000  0
x23 0x0000000000000000  0
x24 0x0000000000000000  0
x25 0x0000000000000000  0
x26 0x0000000000000000  0
x27 0x0000000000000000  0
x28 0x0000000000000000  0
 fp 0x000000016f77ef50  90 ef 77 6f 01 00 00 00 24 4e a4 8d 01 00 00 00  ·ïwo····$N¤·····
 lr 0x000000018da3bcc0  60 fe ff 36 05 ad 01 94 08 00 40 b9 1f f1 00 71  `þÿ6·­····@¹·ñ·q
 sp 0x000000016f77ef20  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
 pc 0x000000018db5f308  03 01 00 54 7f 23 03 d5 fd 7b bf a9 fd 03 00 91  ···T·#·Õý{¿©ý···

  0              0x000000018db5f308 __semwait_signal + 8 in libsystem_kernel.dylib
  1 [ra]         0x000000018da44e24 sleep + 52 in libsystem_c.dylib
  2 [ra]         0x0000000100b68f64 closure #2 in static MultithreadedCrash.spawnThread(_:) + 32 in crashMeMultithreaded at /Users/carlpeto/Code/swift-symbolicate/Sources/crashMeMultithreaded/crashMeMultithreaded.swift:62:39
  3 [ra] [thunk] 0x0000000100b68f84 @objc closure #2 in static MultithreadedCrash.spawnThread(_:) + 12 in crashMeMultithreaded at /<compiler-generated>
  4 [ra]         0x000000018db9fc58 _pthread_start + 136 in libsystem_pthread.dylib
...


Images (45 omitted):

0x0000000100b68000–0x0000000100b6c000 5c59de45bb123fb7b1ec3e4ca4920a0d crashMeMultithreaded    /Users/carlpeto/Code/swift-symbolicate/.build/arm64-apple-macosx/debug/crashMeMultithreaded
0x000000018d7c4000–0x000000018d869ec8 b04b5a9a488c38e5a29ef48c165f26bf dyld                    /usr/lib/dyld
0x000000018da2e000–0x000000018daaeef8 66ebd32168993863ba245cfc3076a0cb libsystem_c.dylib       /usr/lib/system/libsystem_c.dylib
0x000000018db5b000–0x000000018db98290 b63e3af7df2f386f8917d71c98fbd7ab libsystem_kernel.dylib  /usr/lib/system/libsystem_kernel.dylib
0x000000018db99000–0x000000018dba5b3c e7a730080c0931e39dd90c61652f0e85 libsystem_pthread.dylib /usr/lib/system/libsystem_pthread.dylib

Backtrace took 0.12s


"""
