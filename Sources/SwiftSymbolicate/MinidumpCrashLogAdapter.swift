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

import Foundation

#if !os(Windows)

  import Minidump

  @_spi(CrashLog) import Runtime
  @_spi(Contexts) import Runtime
  @_spi(Utils) import Runtime
  @_spi(Formatting) import Runtime

  /// Converts a parsed ``MinidumpFile`` into a ``CrashLog`` suitable for symbolication.
  @_spi(CrashLog)
  public struct MinidumpCrashLogAdapter {
    @_spi(CrashLog)
    public static func crashLog(from minidump: MinidumpFile) -> CrashLog<HostContext.Address> {
      let architecture = minidump.architecture.name
      let platform = minidump.platform.name
      let crashedThreadId = minidump.exception?.threadId

      let threads = minidump.threads.map { thread -> CrashLog<HostContext.Address>.Thread in
        let isCrashed = thread.threadId == crashedThreadId

        let frames: [CrashLog<HostContext.Address>.Frame] = thread.frames.enumerated().map {
          index, address in
          let kind: CrashLog<HostContext.Address>.Frame.Kind =
            index == 0 ? .programCounter : .returnAddress
          return CrashLog<HostContext.Address>.Frame(
            kind: kind,
            address: hex(HostContext.Address(address)))
        }

        let registers: [String: String] = thread.registers.named.reduce(into: [:]) { result, pair in
          result[pair.key] = hex(HostContext.Address(pair.value))
        }

        return CrashLog<HostContext.Address>.Thread(
          name: "Thread \(thread.threadId)",
          crashed: isCrashed,
          registers: registers.isEmpty ? nil : registers,
          frames: frames)
      }

      let images: [CrashLog<HostContext.Address>.Image] = minidump.modules.map { module in
        let endOfText = module.baseAddress + UInt64(module.size)
        let path = module.name
        let name: String
        if let lastSep = path.lastIndex(of: "\\") {
          name = String(path[path.index(after: lastSep)...])
        } else if let lastSep = path.lastIndex(of: "/") {
          name = String(path[path.index(after: lastSep)...])
        } else {
          name = path
        }

        return CrashLog<HostContext.Address>.Image(
          name: name,
          buildId: module.pdbId,
          path: path,
          baseAddress: hex(HostContext.Address(module.baseAddress)),
          endOfText: hex(HostContext.Address(endOfText)))
      }

      let exceptionDescription: String
      let faultAddress: String
      if let exc = minidump.exception {
        exceptionDescription = "Exception 0x\(String(exc.code, radix: 16))"
        faultAddress = hex(HostContext.Address(exc.address))
      } else {
        exceptionDescription = "Unknown"
        faultAddress = "0x0"
      }

      return CrashLog<HostContext.Address>(
        timestamp: ISO8601DateFormatter().string(from: Date()),
        kind: "crashReport",
        description: exceptionDescription,
        faultAddress: faultAddress,
        platform: platform,
        architecture: architecture,
        threads: threads,
        capturedMemory: nil,
        omittedImages: nil,
        images: images,
        backtraceTime: 0.0)
    }
  }

#endif
