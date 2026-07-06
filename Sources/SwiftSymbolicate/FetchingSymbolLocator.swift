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

@_spi(SymbolLocation) import Runtime

/// A symbol locator that can fetch symbols from remote servers.
@_spi(SymbolLocation)
public protocol FetchingSymbolLocator: SymbolLocator {
  /// Downloads and caches symbol files for the given images from configured symbol servers.
  ///
  /// - Parameter imageDetails: An array of `(buildId, executableName, platform)` tuples
  ///   identifying each image to fetch symbols for.
  func updateSymbolCache(imageDetails: [(String, String, SymbolServerPlatform)]) async
}
