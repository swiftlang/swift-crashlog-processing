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
@_spi(Contexts) import Runtime
@_spi(CrashLog) import Runtime
@_spi(Formatting) import Runtime
@_spi(Internal) import Runtime

/// A ``LogStreamReaderWriter`` that detects and symbolicates JSON-format crash logs.
///
/// Recognizes JSON crash logs delimited by `{ "timestamp": "...", "kind": "crashReport"`
/// at the start and `"backtraceTime": ...}` at the end.
@_spi(Formatting)
public struct JsonLogStreamReaderWriter: LogStreamReaderWriter {
  let symbolAdditionalPaths: [String]
  let symbolicateAllThreads: Bool
  let symbolicationOptions: Backtrace.SymbolicationOptions
  let jsonFormatterOptions: BacktraceJSONFormatterOptions
  let symbolServers: [SymbolServer]
  let cacheUpdatePolicy: CacheUpdatePolicy
  let serversDebug: Bool

  /// Creates a JSON crash log reader/writer.
  ///
  /// - Parameters:
  ///   - symbolAdditionalPaths: Additional directories to search for symbol files.
  ///   - symbolicateAllThreads: Whether to symbolicate all threads or only the crashed thread.
  ///   - symbolicationOptions: Options controlling symbolication behavior.
  ///   - jsonFormatterOptions: Options controlling JSON output formatting.
  ///   - symbolServers: Remote symbol servers to fetch symbols from.
  ///   - cacheUpdatePolicy: Controls when cached files are refreshed from the server.
  ///   - serversDebug: If `true`, prints progress messages for symbol server operations.
  public init(
    symbolAdditionalPaths: [String],
    symbolicateAllThreads: Bool,
    symbolicationOptions: Backtrace.SymbolicationOptions,
    jsonFormatterOptions: BacktraceJSONFormatterOptions,
    symbolServers: [SymbolServer],
    cacheUpdatePolicy: CacheUpdatePolicy = .never,
    serversDebug: Bool = false
  ) {
    self.symbolAdditionalPaths = symbolAdditionalPaths
    self.symbolicateAllThreads = symbolicateAllThreads
    self.symbolicationOptions = symbolicationOptions
    self.jsonFormatterOptions = jsonFormatterOptions
    self.symbolServers = symbolServers
    self.cacheUpdatePolicy = cacheUpdatePolicy
    self.serversDebug = serversDebug
  }

  /// Recognizer for the start of a JSON crash log: `{ "timestamp": "...", "kind": "crashReport"`.
  public var matchStartRecognizer: Recognizer = {
    Recognizer(
      .init("{ \"timestamp\": \""), .init(skipTo: "\"", max: 100)!,
      .init("\", \"kind\": \"crashReport\""))
  }()

  /// Recognizer for the end of a JSON crash log: `"backtraceTime": ...}`.
  public var matchEndRecognizer: Recognizer = {
    Recognizer(.init("\"backtraceTime\":"), .init(skipTo: "}", max: 100)!, .init("}"))
  }()

  /// Decodes the captured JSON data into a `CrashLog`, symbolicates it, and re-encodes as JSON.
  public func processLog(data: Data) async -> Data {
    // TODO: for now we are interpreting the crash log with
    // registers matching the host architecture
    // in the long run, we should probably allow differing architectures
    // but in reality the only difference in the crash log is the address sizes
    // which are likely to be 64 bit on most platforms, so will work between
    // AMD64 and ARM64 anyway, which is the most likely cross platform situation
    var crashLog: CrashLog<HostContext.Address>?

    do {
      crashLog = try CrashLog<HostContext.Address>.loadFromJSON(data)
    } catch let error {
      print("unable to read crash log: \(error.localizedDescription)")
      return data
    }

    guard var crashLog else { return data }

    await symbolicate(
      crashLog: &crashLog,
      symbolAdditionalPaths: symbolAdditionalPaths,
      symbolicateAllThreads: symbolicateAllThreads,
      symbolicationOptions: symbolicationOptions,
      symbolServers: symbolServers,
      cacheUpdatePolicy: cacheUpdatePolicy,
      serversDebug: serversDebug)

    return exportAsJson(
      crashLog: crashLog,
      options: jsonFormatterOptions) ?? data
  }
}
