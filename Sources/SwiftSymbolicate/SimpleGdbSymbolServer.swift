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

/// A ``SymbolServer`` that fetches symbols using the debuginfod protocol.
///
/// Uses a simple URL scheme: `serverAddress/buildid/{uuid}/{debuginfo|executable}`.
/// Handles Darwin and Linux platforms.
public class SimpleGdbSymbolServer: SymbolServer {
  let serverAddress: URL
  let httpDownloader: HTTPDownloader
  let debug: Bool

  /// Creates a new debuginfod symbol server.
  ///
  /// - Parameters:
  ///   - serverAddress: The base URL of the debuginfod server.
  ///   - httpDownloader: The HTTP downloader to use for fetching files.
  ///   - debug: If `true`, prints progress messages for symbol fetch operations.
  public init(
    serverAddress: URL,
    httpDownloader: HTTPDownloader,
    debug: Bool = false
  ) {
    self.serverAddress = serverAddress
    self.httpDownloader = httpDownloader
    self.debug = debug
    if debug {
      print("SimpleGdbSymbolServer: setup with server URL: \(serverAddress)")
    }
  }

  /// Returns `true` for Darwin and Linux platforms.
  public func handles(platform: SymbolServerPlatform) -> Bool {
    platform == .Darwin || platform == .Linux
  }

  /// Fetches a debug symbol or executable file from the debuginfod server.
  ///
  /// - Parameters:
  ///   - uuid: The build ID of the image.
  ///   - filename: Unused for debuginfod lookups.
  ///   - type: Whether to fetch debug symbols or the executable.
  ///   - cachedFilePath: The local path to write the downloaded file to.
  ///   - cachedFileLastModifiedDate: If non-nil, sends an `If-Modified-Since` header.
  /// - Returns: `true` if the fetch succeeded (HTTP 200) or the cache is current (HTTP 304).
  public func fetch(
    forId uuid: String,
    filename: String?,
    type: SymbolServerFileType,
    toPath cachedFilePath: String,
    ifNewerThan cachedFileLastModifiedDate: Date?
  ) async -> Bool {

    if debug {
      print(
        "SimpleGdbSymbolServer: fetching image: \(uuid), "
          + "current file last modification date: \(String(describing: cachedFileLastModifiedDate))"
      )
    }

    guard !uuid.isEmpty else { return false }

    let url =
      serverAddress
      .appendingPathComponent("buildid")
      .appendingPathComponent(uuid)
      .appendingPathComponent(
        type == .debugSymbols ? "debuginfo" : "executable"
      )

    var headers: [String: String] = [:]

    if let cachedFileLastModifiedDate {
      let lastModifiedDateFormatted = httpDateString(from: cachedFileLastModifiedDate)
      headers["If-Modified-Since"] = lastModifiedDateFormatted

      if debug {
        print(
          "SimpleGdbSymbolServer sending previous cached file last mod date: \(lastModifiedDateFormatted)"
        )
      }
    }

    if debug {
      print("SimpleGdbSymbolServer: requesting \(url)")
    }

    do {
      let result = try await httpDownloader.download(
        from: url,
        toPath: cachedFilePath,
        headers: headers
      )

      if debug {
        print("SimpleGdbSymbolServer: response status code: \(result)")
      }

      return result == .OK || result == .NotModified
    } catch let error {
      if debug {
        print(
          "SimpleGdbSymbolServer: error: \(error.localizedDescription), \(error as NSError) : \((error as NSError).userInfo)"
        )
      }

      return false
    }
  }
}
