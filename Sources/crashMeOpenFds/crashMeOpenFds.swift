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
// Windows deprecates the POSIX names in favour of underscore-prefixed
// variants; shadow them with the POSIX names so the call sites below stay
// portable.
  private func getpid() -> Int32 { _getpid() }
  private func creat(_ path: String, _ mode: Int32) -> Int32 { _creat(path, mode) }
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

@main
struct Crash {
  static func main() {
    let fd1 = creat("tmp1.txt", 0o644)
    guard fd1 > 0 else {
      perror("failed to open fd1")
      exit(-1)
    }

    let fd2 = creat("tmp2.txt", 0o644)
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
