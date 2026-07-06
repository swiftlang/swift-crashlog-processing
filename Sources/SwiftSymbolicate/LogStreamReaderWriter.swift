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
@_spi(SymbolLocation) import Runtime
@_spi(Formatting) import Runtime
@_spi(Internal) import Runtime

/// A protocol for detecting and processing crash logs within a byte stream.
///
/// Conforming types provide ``Recognizer`` instances that detect the start
/// and end boundaries of a specific crash log format, plus a method to
/// symbolicate the captured data.
public protocol LogStreamReaderWriter {
  /// A recognizer that detects the start of a crash log in this format.
  var matchStartRecognizer: Recognizer { get set }
  /// A recognizer that detects the end of a crash log in this format.
  var matchEndRecognizer: Recognizer { get set }

  /// Processes captured crash log data and returns the symbolicated result.
  ///
  /// - Parameter data: The raw bytes of the captured crash log.
  /// - Returns: The symbolicated crash log data, or the original data if processing fails.
  func processLog(data: Data) async -> Data
}

extension LogStreamReaderWriter {
  func symbolicate(
    crashLog: inout CrashLog<HostContext.Address>,
    symbolAdditionalPaths: [String],
    symbolicateAllThreads: Bool,
    symbolicationOptions: Backtrace.SymbolicationOptions,
    symbolServers: [SymbolServer],
    cacheUpdatePolicy: CacheUpdatePolicy,
    serversDebug: Bool
  ) async {
    let platform = crashLog.symbolicationPlatform

    let offlineSymbolicator = OfflineSymbolLocator(
      alternativePaths: symbolAdditionalPaths,
      pathSeparator: platform.pathSeparator,
      symbolServers: symbolServers,
      cacheUpdatePolicy: cacheUpdatePolicy,
      debug: serversDebug)

    await offlineSymbolicator.updateSymbolCache(imageDetails: crashLog.imageDetails)

    crashLog.symbolicate(
      allThreads: symbolicateAllThreads,
      platform: platform,
      options: symbolicationOptions,
      symbolLocator: offlineSymbolicator)

    #if !os(Windows)
      if platform == .Windows {
        crashLog.demangleMSVCSymbolNames()
      }
    #endif
  }
}
