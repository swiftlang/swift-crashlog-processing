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

public enum HTTPDownloadResult {
  case OK
  case NotModified
  case Error(Int)

  static func == (lhs: HTTPDownloadResult, rhs: HTTPDownloadResult) -> Bool {
    switch (lhs, rhs) {
    case (.OK, .OK): true
    case (.NotModified, .NotModified): true
    case (.Error(let e1), .Error(let e2)): e1 == e2
    default: false
    }
  }
}

public protocol HTTPDownloader {
  /// Downloads a file from a URL to a local path.
  ///
  /// - Parameters:
  ///   - url: The remote URL to download from.
  ///   - toPath: The local file path to save the download to.
  ///   - headers: HTTP headers to include in the request.
  /// - Returns: The result based on HTTP status code.
  /// - Throws: If the download fails due to a network or I/O error.
  func download(
    from url: URL,
    toPath: String,
    headers: [String: String]
  ) async throws -> HTTPDownloadResult
}

func httpDateString(from date: Date) -> String {
  let formatter = DateFormatter()
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.timeZone = TimeZone(identifier: "GMT")
  formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
  return formatter.string(from: date)
}
