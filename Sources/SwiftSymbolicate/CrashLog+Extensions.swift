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
@_spi(CrashLog) import Runtime
@_spi(Internal) import Runtime
@_spi(SymbolLocation) import Runtime
@_spi(Formatting) import Runtime

private let decoder = JSONDecoder()

extension CrashLog {
  /// Decodes a ``CrashLog`` from JSON data.
  ///
  /// - Parameter json: The JSON-encoded crash log data.
  /// - Returns: The decoded crash log.
  /// - Throws: If decoding fails.
  public static func loadFromJSON(_ json: Data) throws -> CrashLog {
    try decoder.decode(CrashLog.self, from: json)
  }

  /// The symbolication platform inferred from the crash log's `platform` string.
  public var symbolicationPlatform: Backtrace.SymbolicationPlatform {
    if platform.contains("macOS") {
      return .Darwin
    } else if platform.contains("Linux") {
      return .Linux
    } else if platform.contains("Windows") {
      return .Windows
    } else {
      print("unable to parse platform")
      return .default
    }
  }

  /// The ``SymbolServerPlatform`` for this crash log, for use with symbol server lookups.
  public var symbolServerPlatform: SymbolServerPlatform {
    if platform.contains("macOS") {
      return .Darwin
    } else if platform.contains("Linux") {
      return .Linux
    } else if platform.contains("Windows") {
      return .Windows
    } else {
      print("unable to parse platform for symbol server")
      return .Linux
    }
  }

  /// The build ID, executable name, and platform for each image in the crash log.
  @_spi(Formatting)
  public var imageDetails: [(String, String, SymbolServerPlatform)] {
    guard let images else { return [] }

    let platform = symbolServerPlatform

    return images.compactMap { (image) -> (String, String, SymbolServerPlatform)? in
      guard let buildId = image.buildId, let name = image.name else {
        return nil
      }

      return (buildId, name, platform)
    }
  }
}
