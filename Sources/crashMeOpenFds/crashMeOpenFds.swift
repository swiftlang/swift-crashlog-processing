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

#if os(macOS)
  internal import Darwin
#elseif os(Windows)
  internal import ucrt
#elseif canImport(Glibc)
  internal import Glibc
#elseif canImport(Musl)
  internal import Musl
#endif

#if os(Windows)
  // ucrt deprecates the POSIX names in favour of underscore-prefixed variants;
  // shadow them with the POSIX names so the call sites below stay portable.
  // _open is itself deprecated, so open() routes through _sopen_s, the only
  // non-deprecated way to obtain a file descriptor.
  private let O_CREAT = _O_CREAT
  private let O_WRONLY = _O_WRONLY
  private let O_TRUNC = _O_TRUNC
  private func getpid() -> Int32 { _getpid() }
  private func open(_ path: String, _ oflag: Int32, _ mode: Int32) -> Int32 {
    var fd: Int32 = -1
    guard _sopen_s(&fd, path, oflag, _SH_DENYNO, mode) == 0 else {
      return -1
    }
    return fd
  }
  @discardableResult private func close(_ fd: Int32) -> Int32 { _close(fd) }
  @discardableResult private func unlink(_ path: String) -> Int32 { _unlink(path) }
#endif

func level1() {
  level2()
}

func level2() {
  level3()
}

func level3() {
  level4()
}

func level4() {
  print("About to crash: [\(getpid())]")
  let ptr = UnsafeMutablePointer<Int>(bitPattern: 6)!
  ptr.pointee = 42
}

// The purpose of this test is to check how well the crash handler deals
// with a crash when there are open file descriptors. The backtracer has a flag
// that asks the runtime to close any open file handles, where possible, before
// starting the process of creating backtraces/crash logs. This tool allows us
// to test this.

@main
struct Crash {
  static func main() {
    let fd1 = open("tmp1.txt", O_CREAT | O_WRONLY | O_TRUNC, 0o644)
    guard fd1 > 0 else {
      perror("failed to open fd1")
      exit(-1)
    }

    let fd2 = open("tmp2.txt", O_CREAT | O_WRONLY | O_TRUNC, 0o644)
    guard fd1 > 0 else {
      perror("failed to open fd2")
      exit(-1)
    }

    defer {
      close(fd1)
      close(fd2)

      unlink("tmp1.txt")
      unlink("tmp2.txt")
    }

    print("created and opened: [\(fd1), \(fd2)]")

    level1()
  }
}
