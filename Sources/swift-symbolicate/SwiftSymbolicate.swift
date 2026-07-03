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

/// This will run as a command line tool that can pipe input using Foundation.
///
/// It can read a stream and spot the start of a backtrace, either in native or json format, it will buffer that trace,
/// symbolicate it on-the-fly, output the symbolicated version to the output stream and continue streaming output from there onward.
/// In theory it can symbolicate any number of crash logs.
///
/// To spot the crash logs, it will read line by line, checking each line for...
/// Program crashed:
///  (which indicates the simple format)
///  "faultAddress":
///  (which might indicated the json version)
///
/// For json, we make the simplifying assumption that it will all be in one line.
/// For the simple format, we read until we reach a line containing...
/// Backtrace took
///
/// (or until some pre-set maximum number of lines has been reached)
///
/// If we are not matching a crash log line/lines, then just output the line unchanged.
///
/// In both cases we then take the buffered line or lines and feed them into the approapriate reader for CrashLog.
/// Then we ask CrashLog to symbolicate either just the crashed thread or all threads.
///
/// Finally, continue to output lines as above, again scanning for any new crash logs and outputting lines unchanged if they don't match.
///
/// Some suggested command line options...
/// - scan for only one type
/// - output as json always (even if the input was simple)
/// - fast - only do symbol lookup (default is source locations and inline frames too)
///

import ArgumentParser
import Foundation
@_spi(Contexts) import Runtime
@_spi(Formatting) import Runtime
@_spi(CrashLog) import Runtime
@_spi(Internal) import Runtime
@_spi(SymbolLocation) import Runtime
import SwiftSymbolicate
@_spi(Testing) import SwiftSymbolicate
@_spi(CrashLog) import SwiftSymbolicate
@_spi(SymbolLocation) import SwiftSymbolicate
@_spi(Formatting) import SwiftSymbolicate

#if os(macOS)
  internal import Darwin
#elseif os(Windows)
  internal import ucrt
#elseif canImport(Glibc)
  internal import Glibc
#elseif canImport(Musl)
  internal import Musl
#else
  #error("You need to add code for your platform")
#endif

#if os(Windows)
  import CRT
  import WinSDK
#endif

enum SymbolicationIssues: Error {
  case UnableToOpenInput
  case UnableToOpenOutput
  case UnsupportedVersion
}

@available(macOS 10.15, *)
@main
struct SwiftSymbolicate: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      abstract:
        "Symbolicate input files containing crash logs and write to output files. Works on streams/pipes as well except on Windows.",
      discussion: """
        This will read the entire file, attempt to symbolicate any plain or json crash logs
        inline and output the results.

        Respects a few of the SWIFT_BACKTRACE options (see backtracer documentation)...
        threads, sanitize, demangle - all formats (see docs)
        preset - plain format (see docs)
        registers, images - json format logs (see docs)
        symbolicate=fast - use fast symbolication (otherwise uses full symbolication)
        cache=no - (macOS only) tell Core Symbolication not to use prior cache

        The program will either use locally copied/cached symbols or will attempt to retrieve from servers using the appropriate
        protocols if servers are specified. Previously downloaded symbol files are cached and reused on later attempts. By default
        if a suitable cached symbol file is found that symbol file is used without contacting the server.

        Advanced:
        Use environment variable SWIFT_SYMBOLICATE_SERVERS_DEBUG=1 for debugging server retrieval.
        Use environment variable SWIFT_SYMBOLICATE_CACHE_UPDATE=newer|always to either check for cache
        staleness or ignore cache of downloaded symbols, respectively.
        """)
  }

  #if os(macOS)
    @Option(
      name: [
        .short,
        .long,
        .customLong("symbols"),
      ],
      help:
        "Additional path(s) to search for/cache symbol files (no effect on machO crash log symbolication).\n(can use environment variable SWIFT_SYMBOLICATE_SYMBOL_PATHS instead)"
    )
    var symbolAdditionalPaths: [String] = []
  #else
    @Option(
      name: [
        .short,
        .long,
        .customLong("symbols"),
      ],
      help:
        "Additional path(s) to search for/cache symbol files.\n(can use environment variable SWIFT_SYMBOLICATE_SYMBOL_PATHS instead)"
    )
    var symbolAdditionalPaths: [String] = []
  #endif

  #if os(Windows)
    @Option(name: [.short, .long], help: "Where to send the symbolicated output")
    var outputFile: String
  #else
    @Option(
      name: [.short, .long], help: "Where to send the symbolicated output (defaults to stdout)")
    var outputFile: String?
  #endif

  #if os(Windows)
    @Argument
    var inputFile: String
  #else
    @Argument
    var inputFile: String?
  #endif

  @Option(
    name: [.long],
    help:
      "Debuginfod symbol server(s) (baseURL), tried in order\n(or use environment variable SWIFT_SYMBOLICATE_GDB_SERVERS instead)"
  )
  var gdbSymbolServers: [String] = []

  @Option(
    name: [.long],
    help:
      "Windows symbol server(s) (baseURL), tried in order. Only uncompressed PDB files are supported; CAB-compressed (.pd_) and file.ptr redirect files are not handled.\n(or use environment variable SWIFT_SYMBOLICATE_WINDOWS_SERVERS instead)"
  )
  var windowsSymbolServers: [String] = []

  func validate() throws {
    let env = ProcessInfo.processInfo.environment
    let hasGdbServers =
      !gdbSymbolServers.isEmpty
      || env["SWIFT_SYMBOLICATE_GDB_SERVERS"] != nil
    let hasWindowsServers =
      !windowsSymbolServers.isEmpty
      || env["SWIFT_SYMBOLICATE_WINDOWS_SERVERS"] != nil
    let hasSymbolPaths =
      !symbolAdditionalPaths.isEmpty
      || env["SWIFT_SYMBOLICATE_SYMBOL_PATHS"] != nil

    if (hasGdbServers || hasWindowsServers)
      && !hasSymbolPaths
    {
      throw ValidationError(
        "To use a symbol server, you must also specify "
          + "at least one path for "
          + "symbol-additional-paths (or set "
          + "SWIFT_SYMBOLICATE_SYMBOL_PATHS). This first "
          + "value will be the location downloaded symbols "
          + "are cached to.")
    }
  }

  var newline = "\n"

  var inputFileInterpreted: String {
    #if os(Windows)
      inputFile
    #else
      switch inputFile {
      case "-", nil: "/dev/stdin"
      case let f?: f
      }
    #endif
  }

  var outputFileInterpreted: String {
    #if os(Windows)
      outputFile
    #else
      switch outputFile {
      case "-", nil: "/dev/stdout"
      case let f?: f
      }
    #endif
  }

  static func backtraceOpts(swiftBacktraceEnvSettings: String?) -> [Substring: Substring] {

    guard let swiftBacktraceEnvSettings
    else { return [:] }

    return
      swiftBacktraceEnvSettings
      .split(separator: ",")
      .reduce([:]) { (n, kv) -> [Substring: Substring] in
        let kvPair = kv.split(separator: "=")
        if kvPair.count < 2 {
          return n
        } else {
          var o = n
          o[kvPair[0]] = kvPair[1]
          return o
          // return (kvPair[0],kvPair[1])
        }
      }
  }

  static func getJsonBacktraceFormatterOptions(
    swiftBacktraceEnvSettings: String?
  ) -> BacktraceJSONFormatterOptions {
    let sb_opts = backtraceOpts(swiftBacktraceEnvSettings: swiftBacktraceEnvSettings)
    return jsonBacktraceFormatterOptions(opts: sb_opts)
  }

  static func truthy(_ string: (any StringProtocol)?) -> Bool? {
    guard let string else { return nil }

    return switch string.lowercased() {
    case "on", "true", "yes", "y", "t", "1": true
    default: false
    }
  }

  static func plainCrashLogFormattingOptions(opts sb_opts: [Substring: Substring])
    -> BacktraceFormattingOptions
  {

    let sanitize = truthy(sb_opts["sanitize"])

    var options: BacktraceFormattingOptions =
      switch sb_opts["preset"] {
      case "full":
        .skipRuntimeFailures(false)
          .skipThunkFunctions(false)
          .skipSystemFrames(false)
          .sanitizePaths(sanitize ?? true)
      case "medium":
        .skipRuntimeFailures(true)
          .showSourceCode(true)
          .showFrameAttributes(true)
          .sanitizePaths(sanitize ?? true)
      default:  // "friendly", nil
        .skipRuntimeFailures(true)
          .showAddresses(false)
          .showSourceCode(false)
          .showFrameAttributes(false)
          .sanitizePaths(sanitize ?? false)
      }

    options = options.demangle(truthy(sb_opts["demangle"]) ?? true)
    return options
  }

  static func jsonBacktraceFormatterOptions(opts sb_opts: [Substring: Substring])
    -> BacktraceJSONFormatterOptions
  {

    // default should be...
    // registers=crashed, demangle=true, sanitize=false, showImages=all, threads=all
    var options: BacktraceJSONFormatterOptions =
      [.demangle, .images, .allThreads]

    for (key, value) in sb_opts {
      switch key {
      case "demangle":
        if value == "no" { options.remove(.demangle) }
      case "registers":
        if value == "all" { options.insert(.allRegisters) }
      case "sanitize":
        if value == "yes" { options.insert(.sanitize) }
      case "images":
        if value == "none" {
          options.remove(.images)
        } else if value == "mentioned" {
          options.insert(.mentionedImages)
        }
      case "threads":
        if value == "crashed" {
          options.remove(.allThreads)
        }
      default:
        break
      }
    }

    return options
  }

  mutating func run() async throws {
    guard let inputStream = InputStream(fileAtPath: inputFileInterpreted) else {
      throw SymbolicationIssues.UnableToOpenInput
    }

    guard let outputStream = OutputStream(toFileAtPath: outputFileInterpreted, append: false) else {
      throw SymbolicationIssues.UnableToOpenOutput
    }

    let btOptions = Self.backtraceOpts(
      swiftBacktraceEnvSettings:
        ProcessInfo.processInfo.environment["SWIFT_BACKTRACE"])

    let env = ProcessInfo.processInfo.environment

    let serversDebug = env["SWIFT_SYMBOLICATE_SERVERS_DEBUG"] == "1"

    let cacheUpdatePolicy: CacheUpdatePolicy =
      switch env["SWIFT_SYMBOLICATE_CACHE_UPDATE"]?.lowercased() {
      case "always": .always
      case "newer": .newer
      default: .never
      }

    let allSymbolPaths =
      symbolAdditionalPaths
      + (env["SWIFT_SYMBOLICATE_SYMBOL_PATHS"]?
        .split(separator: ";")
        .map(String.init) ?? [])

    let gdbServerURLs =
      gdbSymbolServers
      + (env["SWIFT_SYMBOLICATE_GDB_SERVERS"]?
        .split(separator: ";")
        .map(String.init) ?? [])

    let windowsServerURLs =
      windowsSymbolServers
      + (env["SWIFT_SYMBOLICATE_WINDOWS_SERVERS"]?
        .split(separator: ";")
        .map(String.init) ?? [])

    let httpDownloader = FoundationHTTPDownloader(debug: serversDebug)

    let remoteSymbolServers: [SymbolServer] =
      gdbServerURLs.compactMap { urlString in
        guard let url = URL(string: urlString) else {
          if serversDebug {
            print("cannot parse gdb server URL: \(urlString)")
          }
          return nil
        }
        return SimpleGdbSymbolServer(
          serverAddress: url,
          httpDownloader: httpDownloader,
          debug: serversDebug
        )
      }
      + windowsServerURLs.compactMap { urlString in
        guard let url = URL(string: urlString) else {
          if serversDebug {
            print("cannot parse windows server URL: \(urlString)")
          }
          return nil
        }
        return WindowsSymbolServer(
          serverAddress: url,
          httpDownloader: httpDownloader,
          debug: serversDebug
        )
      }

    let symbolicateAllThreads = btOptions["threads"] != "crashed"
    let disableCache = btOptions["cache"] == "no"
    let fastSymbolication = btOptions["symbolicate"] == "fast"

    let symbolicationOptions: Backtrace.SymbolicationOptions =
      switch (fastSymbolication, disableCache) {
      case (true, true):
        [.showSourceLocations]
      case (true, false):
        [.showSourceLocations, .useSymbolCache]
      case (false, true):
        [.showInlineFrames, .showSourceLocations]
      case (false, false):
        [.showInlineFrames, .showSourceLocations, .useSymbolCache]
      }

    let jsonFormatterOptions =
      Self.jsonBacktraceFormatterOptions(opts: btOptions)

    let plainTextFormatterOptions =
      Self.plainCrashLogFormattingOptions(opts: btOptions)

    let jsonCrashLogReaderWriter = JsonLogStreamReaderWriter(
      symbolAdditionalPaths: allSymbolPaths,
      symbolicateAllThreads: symbolicateAllThreads,
      symbolicationOptions: symbolicationOptions,
      jsonFormatterOptions: jsonFormatterOptions,
      symbolServers: remoteSymbolServers,
      cacheUpdatePolicy: cacheUpdatePolicy,
      serversDebug: serversDebug)

    let plainTextCrashLogReaderWriter = PlainTextLogStreamReaderWriter(
      symbolAdditionalPaths: allSymbolPaths,
      symbolicateAllThreads: symbolicateAllThreads,
      symbolicationOptions: symbolicationOptions,
      plainTextFormatterOptions: plainTextFormatterOptions,
      symbolServers: remoteSymbolServers,
      cacheUpdatePolicy: cacheUpdatePolicy,
      serversDebug: serversDebug)

    let crashScanner = CrashScanner(
      inputStream: inputStream,
      outputStream: outputStream,
      logStreamReaderWriters: [
        jsonCrashLogReaderWriter,
        plainTextCrashLogReaderWriter,
      ])

    try await crashScanner.scanAndProcessStreams()
  }
}
