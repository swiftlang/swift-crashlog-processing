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
@_spi(CrashLog) import Runtime
@_spi(Formatting) import Runtime

#if os(Windows)
  import WinSDK
#endif

/// A ``LogStreamReaderWriter`` that detects and symbolicates plain text crash logs.
///
/// Recognizes plain text crash logs starting with `Program crashed:` and ending
/// with `Backtrace took ...s`.
@_spi(Formatting)
public struct PlainTextLogStreamReaderWriter: LogStreamReaderWriter {
  let symbolAdditionalPaths: [String]
  let symbolicateAllThreads: Bool
  let symbolicationOptions: Backtrace.SymbolicationOptions
  let plainTextFormatterOptions: BacktraceFormattingOptions
  let symbolServers: [SymbolServer]
  let cacheUpdatePolicy: CacheUpdatePolicy
  let serversDebug: Bool

  /// Creates a plain text crash log reader/writer.
  ///
  /// - Parameters:
  ///   - symbolAdditionalPaths: Additional directories to search for symbol files.
  ///   - symbolicateAllThreads: Whether to symbolicate all threads or only the crashed thread.
  ///   - symbolicationOptions: Options controlling symbolication behavior.
  ///   - plainTextFormatterOptions: Options controlling plain text output formatting.
  ///   - symbolServers: Remote symbol servers to fetch symbols from.
  ///   - cacheUpdatePolicy: Controls when cached files are refreshed from the server.
  ///   - serversDebug: If `true`, prints progress messages for symbol server operations.
  public init(
    symbolAdditionalPaths: [String],
    symbolicateAllThreads: Bool,
    symbolicationOptions: Backtrace.SymbolicationOptions,
    plainTextFormatterOptions: BacktraceFormattingOptions,
    symbolServers: [SymbolServer],
    cacheUpdatePolicy: CacheUpdatePolicy = .never,
    serversDebug: Bool = false
  ) {
    self.symbolAdditionalPaths = symbolAdditionalPaths
    self.symbolicateAllThreads = symbolicateAllThreads
    self.symbolicationOptions = symbolicationOptions
    self.plainTextFormatterOptions = plainTextFormatterOptions
    self.symbolServers = symbolServers
    self.cacheUpdatePolicy = cacheUpdatePolicy
    self.serversDebug = serversDebug
  }

  /// Recognizer for the start of a plain text crash log: ` Program crashed: `.
  public var matchStartRecognizer: Recognizer = {
    Recognizer(.init(" Program crashed: "))
  }()

  /// Recognizer for the end of a plain text crash log: `Backtrace took ...s`.
  public var matchEndRecognizer: Recognizer = {
    Recognizer(.init("Backtrace took "), .init(skipTo: "s", max: 100)!, .init("s"))
  }()

  /// Parses the captured plain text data into a `CrashLog`, symbolicates it,
  /// and serializes back to plain text.
  public func processLog(data: Data) async -> Data {
    #if DebuggingSymbolicator
      print(">> PLAIN LOG <<")
    #endif

    guard let plainCrashLog = String(data: data, encoding: .utf8)
    else {
      #if DebuggingSymbolicator
        print("crash log is not utf8")
      #endif
      return data
    }

    let reader = PlainCrashLogReader<HostContext.Address>(
      plainCrashLog: plainCrashLog)

    guard #available(macOS 13.0, *) else { return data }

    #if DebuggingSymbolicator
      print("about to parse crash log")
    #endif

    guard var crashLog = reader.parse() else { return data }

    #if DebuggingSymbolicator
      print("read plain crash log successfully, platform: (\(crashLog.symbolicationPlatform))")
    #endif

    await symbolicate(
      crashLog: &crashLog,
      symbolAdditionalPaths: symbolAdditionalPaths,
      symbolicateAllThreads: symbolicateAllThreads,
      symbolicationOptions: symbolicationOptions,
      symbolServers: symbolServers,
      cacheUpdatePolicy: cacheUpdatePolicy,
      serversDebug: serversDebug)

    var width = LogWidth.auto

    #if os(Windows)
      var consoleInfo = CONSOLE_SCREEN_BUFFER_INFO()
      let stdOutHandle = HANDLE(bitPattern: _get_osfhandle(_fileno(stdout)))!
      if GetConsoleScreenBufferInfo(
        stdOutHandle,
        &consoleInfo)
      {
        width = .fixed(Int(consoleInfo.dwSize.X))
      }
    #endif

    let writer = PlainCrashLogWriter(
      crashLog,
      options: plainTextFormatterOptions,
      lineSeparator: newline.first ?? "\n",
      width: width,
      haveSymbolicatedThreads: true)

    let output = writer.write()

    return output.data(using: .utf8) ?? data
  }
}
