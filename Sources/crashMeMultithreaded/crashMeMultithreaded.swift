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

import CxxCrashHelper

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#elseif canImport(Android)
  import Android
#elseif os(Windows)
  import CRT
  import WinSDK
#else
  #error("Unsupported platform")
#endif

func crashMe() {
  MultithreadedCrash.reallyCrashMe()
}

#if os(Windows)

  func lockMutex() {
    unsafe EnterCriticalSection(MultithreadedCrash.criticalSection)
  }

  func unlockMutex() {
    unsafe LeaveCriticalSection(MultithreadedCrash.criticalSection)
  }

#else

  func lockMutex() {
    guard unsafe pthread_mutex_lock(MultithreadedCrash.mutex) == 0 else {
      fatalError("pthread_mutex_lock failed")
    }
  }

  func unlockMutex() {
    guard unsafe pthread_mutex_unlock(MultithreadedCrash.mutex) == 0 else {
      fatalError("pthread_mutex_unlock failed")
    }
  }

#endif

@main
struct MultithreadedCrash {
  #if os(Windows)
    static nonisolated(unsafe) let criticalSection = UnsafeMutablePointer<CRITICAL_SECTION>
      .allocate(capacity: 1)
  #else
    static nonisolated(unsafe) let mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(
      capacity: 1)
  #endif

  static func reallyCrashMe() {
    print("I'm going to crash now (through C++ frames)")
    cxx_crash_through_cpp_frames()
  }

  static func spawnThread(_ shouldCrash: Bool) {
    #if os(Windows)
      if shouldCrash {
        _ = CreateThread(
          nil, 0,
          { _ in
            lockMutex()
            crashMe()
            // from here onward should never be executed
            unlockMutex()
            return 0
          }, nil, 0, nil)
      } else {
        _ = CreateThread(
          nil, 0,
          { _ in
            while true {
              Sleep(10000)
            }
            // from here onward should never be executed
            return 0
          }, nil, 0, nil)
      }
    #else
      #if os(Linux)
        var thread: pthread_t = 0
      #elseif os(macOS)
        var thread = pthread_t(nil)
      #endif
      if shouldCrash {
        pthread_create(
          &thread, nil,
          { _ in
            lockMutex()
            crashMe()
            unlockMutex()

            while true {
              sleep(10)
            }
          }, nil)
      } else {
        pthread_create(
          &thread, nil,
          { _ in
            while true {
              sleep(10)
            }
          }, nil)
      }
    #endif
  }

  static func main() {
    #if os(Windows)
      unsafe InitializeCriticalSection(criticalSection)
    #else
      guard unsafe pthread_mutex_init(mutex, nil) == 0 else {
        fatalError("pthread_mutex_init failed")
      }
    #endif

    let crashingThreadIndex = (1..<10).randomElement()

    print("Taking mutex, starting threads...")

    lockMutex()

    for threadIndex in 1..<10 {
      spawnThread(threadIndex == crashingThreadIndex)
    }

    unlockMutex()

    while true {
      #if os(Windows)
        Sleep(10000)
      #else
        sleep(10)
      #endif
    }
  }
}
