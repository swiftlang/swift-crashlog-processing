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

#if os(Linux) || os(Windows)
  import FoundationNetworking
#endif

/// An ``HTTPDownloader`` implementation backed by Foundation's `URLSession`.
public class FoundationHTTPDownloader: HTTPDownloader {
  private var debug: Bool

  /// Creates a new Foundation-based HTTP downloader.
  public init(debug: Bool = false) {
    self.debug = debug
  }

  /// Downloads a file from a URL to a local path using `URLSession`.
  ///
  /// On a successful (200) response, the downloaded file is moved to `toPath`,
  /// creating intermediate directories as needed. Non-200 responses return
  /// the status code without writing a file.
  ///
  /// - Parameters:
  ///   - url: The remote URL to download from.
  ///   - toPath: The local file path to save the download to.
  ///   - headers: HTTP headers to include in the request.
  /// - Returns: The result containing the HTTP status code.
  /// - Throws: If the network request or file operation fails.
  public func download(
    from url: URL,
    toPath: String,
    headers: [String: String]
  ) async throws -> HTTPDownloadResult {
    var request = URLRequest(url: url)
    for (key, value) in headers {
      request.setValue(value, forHTTPHeaderField: key)
    }

    if debug {
      print(
        "FoundationHTTPDownloader: downloading: \(url.absoluteString) from \(String(describing: request.url?.host))")
    }

    let (tempURL, response) =
      try await URLSession.shared.download(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      if debug {
        print("FoundationHTTPDownloader: non HTTP response")
      }
      throw DownloadError.notHTTPResponse
    }

    if httpResponse.statusCode == 304 {
      if debug {
        print("FoundationHTTPDownloader: not modified")
      }
      return .NotModified
    }

    guard httpResponse.statusCode == 200 else {
      if debug {
        print("FoundationHTTPDownloader: error status: \(httpResponse.statusCode)")
      }
      return .Error(httpResponse.statusCode)
    }

    let destURL = URL(fileURLWithPath: toPath)
    let destDir = destURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: destDir, withIntermediateDirectories: true)

    if FileManager.default.fileExists(atPath: toPath) {
      if debug {
        print("FoundationHTTPDownloader: removing existing file")
      }
      try FileManager.default.removeItem(atPath: toPath)
    }
    try FileManager.default.moveItem(at: tempURL, to: destURL)

    if debug {
      print("FoundationHTTPDownloader: file emplaced")
    }

    return .OK
  }

  enum DownloadError: Error {
    case notHTTPResponse
  }
}
