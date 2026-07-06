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

/// The platform a crash log originated from, used to determine which
/// ``SymbolServer`` implementations to consult.
public enum SymbolServerPlatform {
  /// Apple Darwin platforms (macOS, iOS, etc.).
  case Darwin
  /// Linux.
  case Linux
  /// Microsoft Windows.
  case Windows
}

/// Controls when cached symbol files are updated from remote servers.
public enum CacheUpdatePolicy {
  /// Never contact the server if a cached file already exists locally.
  case never
  /// Contact the server with an If-Modified-Since header; only download if newer.
  case newer
  /// Always download from the server, ignoring any local cache.
  case always
}

/// The type of file to fetch from a symbol server.
public enum SymbolServerFileType {
  /// Debug symbol files (e.g. `.debug`, `.pdb`).
  case debugSymbols
  /// Executable binary files.
  case executable
}

/// A protocol for fetching symbol files from a remote server.
///
/// Conforming types implement platform-specific symbol server protocols
/// such as debuginfod (Linux/Darwin) or symsrv (Windows).
public protocol SymbolServer {
  /// Returns whether this server handles symbols for the given platform.
  ///
  /// - Parameter platform: The platform to check.
  /// - Returns: `true` if this server can provide symbols for `platform`.
  func handles(platform: SymbolServerPlatform) -> Bool

  /// Fetches a symbol or executable file from the server.
  ///
  /// - Parameters:
  ///   - forId: The build identifier (e.g. build ID or PDB id) for the image.
  ///   - filename: The original filename of the executable, if known.
  ///   - type: Whether to fetch debug symbols or the executable binary.
  ///   - toPath: The local file path to write the downloaded file to.
  ///   - ifNewerThan: If non-nil, only fetch if the server's copy is newer than this date.
  /// - Returns: `true` if the fetch succeeded or the cached copy is up to date.
  func fetch(
    forId: String,
    filename: String?,
    type: SymbolServerFileType,
    toPath: String,
    ifNewerThan: Date?
  ) async -> Bool
}
