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
import Runtime
@_spi(Contexts) import Runtime
@_spi(Formatting) import Runtime
@_spi(Registers) import Runtime
@_spi(Utils) import Runtime
@_spi(CrashLog) import Runtime
@_spi(Internal) import Runtime

/// The output width strategy for formatted crash log output.
public enum LogWidth {
  /// Automatically detect the terminal width.
  case auto
  /// Use a fixed character width.
  case fixed(Int)
}

@_spi(CrashLog) public struct PlainCrashLogWriter<Address: FixedWidthInteger> {
  let crashLog: CrashLog<Address>
  let options: BacktraceFormattingOptions
  let lineSeparator: Character
  let width: LogWidth
  let haveSymbolicatedThreads: Bool

  /// Creates a writer for serializing a crash log to plain text.
  ///
  /// - Parameters:
  ///   - crashLog: The crash log to serialize.
  ///   - options: Formatting options controlling backtrace display.
  ///   - lineSeparator: The line separator character to use in output.
  ///   - width: The output width strategy.
  ///   - haveSymbolicatedThreads: Whether the threads have been symbolicated.
  public init(
    _ crashLog: CrashLog<Address>,
    options: BacktraceFormattingOptions,
    lineSeparator: Character,
    width: LogWidth,
    haveSymbolicatedThreads: Bool
  ) {
    self.crashLog = crashLog
    self.options = options
    self.lineSeparator = lineSeparator
    self.width = width
    self.haveSymbolicatedThreads = haveSymbolicatedThreads
  }

  private func formatMemory(_ memoryHex: String) -> (String, String) {
    let bytes = CrashLog<Address>.bytesFromHexString(memoryHex)

    let formattedMemory =
      bytes
      .map { hex($0, prefix: false) + " " }
      .reduce("", { $0 + $1 })
      .trimmingCharacters(in: CharacterSet.whitespaces)

    let printableBytes =
      bytes
      .map {
        switch $0 {
        case 0..<32, 127, 0x80..<0xa0: "·"
        default: String(Unicode.Scalar($0))
        }
      }
      .joined(separator: "")

    return (formattedMemory, printableBytes)
  }

  private func decimal(_ memoryHex: String) -> Address {
    if let address: Address = CrashLog<Address>.addressFromString(memoryHex) {
      address
    } else {
      0
    }
  }

  static func backtraceFormatter(
    options: BacktraceFormattingOptions,
    width: LogWidth
  ) -> BacktraceFormatter {
    var formattedWidth = 80

    if case .fixed(let w) = width {
      formattedWidth = w
    } else {  // .auto
      #if os(Windows)
        var consoleInfo = CONSOLE_SCREEN_BUFFER_INFO()
        if let outputStream,
          GetConsoleScreenBufferInfo(
            outputStream.handle,
            &consoleInfo)
        {
          formattedWidth = Int(consoleInfo.dwSize.X)
        }
      #else
        var terminalSize = winsize(
          ws_row: 24, ws_col: 80,
          ws_xpixel: 1024, ws_ypixel: 768)
        _ = ioctl(0, CUnsignedLong(TIOCGWINSZ), &terminalSize)
        formattedWidth = Int(terminalSize.ws_col)
      #endif
    }

    let formattingOptions =
      options
      // the backtrace formatter should not show images per backtrace
      // we do it once at the end
      .showImages(.none)

    // theme is always "plain" as we don't support symbolicating colored backtraces
    return BacktraceFormatter(
      formattingOptions
        .width(formattedWidth))
  }

  /// Serializes the crash log to a plain text string.
  ///
  /// - Returns: The formatted crash log as a string.
  public func write() -> String {
    var buffer = ""

    func writeLn(_ string: String) {
      buffer += "\(string)\(lineSeparator)"
    }

    func writeRegisters(_ registers: [String: String]) {
      writeLn("")

      let registerOrder: [String] =
        switch crashLog.architecture {
        case "x86_64": X86_64Context.registerDumpOrder
        case "i386": I386Context.registerDumpOrder
        case "arm": ARMContext.registerDumpOrder
        default: ARM64Context.registerDumpOrder
        }

      // x86_64: blank line before rflags, blank line before cs/fs/gs (compact)
      let x86_64FlagsRegister = "rflags"
      let x86_64CompactRegisters: Set<String> = ["cs", "fs", "gs"]

      // i386: blank line before eflags, blank line before es/cs/ss/ds/fs/gs (compact)
      let i386FlagsRegister = "eflags"
      let i386CompactRegisters: Set<String> = ["es", "cs", "ss", "ds", "fs", "gs"]

      let flagsRegister: String?
      let compactRegisters: Set<String>

      switch crashLog.architecture {
      case "x86_64":
        flagsRegister = x86_64FlagsRegister
        compactRegisters = x86_64CompactRegisters
      case "i386":
        flagsRegister = i386FlagsRegister
        compactRegisters = i386CompactRegisters
      default:
        flagsRegister = nil
        compactRegisters = []
      }

      var inCompactSection = false

      for var register in registerOrder {
        guard let registerValue = registers[register] else { continue }

        if register == flagsRegister {
          writeLn("")
        }

        if !inCompactSection && compactRegisters.contains(register) {
          inCompactSection = true
          writeLn("")
          var compactLine = ""
          for compactReg in registerOrder where compactRegisters.contains(compactReg) {
            guard let value = registers[compactReg] else { continue }
            let shortValue = String(value.suffix(6))
            if !compactLine.isEmpty { compactLine += "  " }
            compactLine += "\(compactReg) \(shortValue)"
          }
          writeLn(compactLine)
          break
        }

        if inCompactSection { continue }

        if register.count < 3 {
          register = String(repeating: " ", count: max(3 - register.count, 0)) + register
        }
        if let memory = crashLog.capturedMemory?[registerValue] {
          let (formattedBytes, printableBytes) = formatMemory(memory)
          writeLn("\(register) \(registerValue)  \(formattedBytes)  \(printableBytes)")
        } else {
          let decimal = decimal(registerValue)
          writeLn("\(register) \(registerValue)  \(decimal)")
        }
      }
    }

    writeLn("*** Program crashed: \(crashLog.description) ***\(lineSeparator)")
    writeLn("Platform: \(crashLog.platform)")

    let images = crashLog.imageMap()

    // get the formatting options anew each time, so we pick up the correct
    // current screen width
    let backtraceFormatter = Self.backtraceFormatter(options: options, width: width)

    // try to decipher if this was a "registers=crashed" dump
    let registersOnlyFromCrashedThread =
      crashLog.threads.filter { !$0.crashed && $0.registers != nil }.count == 0

    // show the crashed thread first in the listing
    func sortCrashed(
      thread1: (Int, CrashLog<Address>.Thread), thread2: (Int, CrashLog<Address>.Thread)
    ) -> Bool {
      return thread1.1.crashed && !thread2.1.crashed
    }

    // threads/backtrace
    for (threadIdx, thread)
      in crashLog.threads.enumerated().sorted(by: sortCrashed)
    {
      let crashedString = thread.crashed ? " crashed" : ""
      let nameString = thread.name?.isEmpty == false ? " \(thread.name ?? "")" : ""

      writeLn("\(lineSeparator)Thread \(threadIdx)\(nameString)\(crashedString):")

      // registers
      if let registers = thread.registers,
        !registersOnlyFromCrashedThread
      {

        writeRegisters(registers)
      }

      // backtrace
      writeLn("")
      if haveSymbolicatedThreads,
        let backtrace =
          thread.symbolicatedBacktrace(
            architecture: crashLog.architecture,
            images: images,
            platform: .default)
      {

        #if !os(Windows)
          if crashLog.symbolicationPlatform == .Windows {
            backtrace.demangleMSVCSymbolNames()
          }
        #endif

        let formattedBacktrace = backtraceFormatter.format(backtrace: backtrace)
        writeLn(formattedBacktrace)
      } else {
        // fallback, show the unsymbolicated thread
        let backtrace: Backtrace = thread.backtrace(
          architecture: crashLog.architecture,
          images: images)
        let formattedBacktrace = backtraceFormatter.format(backtrace: backtrace)
        writeLn(formattedBacktrace)
      }
      writeLn("")
    }

    if registersOnlyFromCrashedThread,
      let crashedThread = crashLog.threads.first(where: { $0.crashed }),
      let registers = crashedThread.registers
    {

      writeLn("\(lineSeparator)Registers:")
      writeRegisters(registers)
      writeLn("")
    }

    // images
    if let images = crashLog.imageMap() {
      if let omittedImages = crashLog.omittedImages {
        writeLn("\(lineSeparator)Images (\(omittedImages) omitted):")
      } else {
        writeLn("\(lineSeparator)Images:")
      }

      writeLn("")
      let formattedImages = backtraceFormatter.format(images: images)
      writeLn(formattedImages)
    }

    writeLn("")
    buffer += "Backtrace took \(crashLog.backtraceTime)s"

    return buffer
  }
}
