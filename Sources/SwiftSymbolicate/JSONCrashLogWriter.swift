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
@_spi(Formatting) import Runtime
@_spi(CrashLog) import Runtime

let newline = "\n"

/// An in-memory `BacktraceJSONWriter` that accumulates JSON output into a string.
@_spi(Testing)
public class InlineBacktraceWriter: BacktraceJSONWriter {
  let newline: String
  var jsonString = ""

  init(newline: String) {
    self.newline = newline
  }

  /// Writes a string to the JSON output buffer.
  public func write(_ string: String, flush: Bool) {
    jsonString += string
  }

  /// Writes a string followed by a newline to the JSON output buffer.
  public func writeln(_ string: String, flush: Bool) {
    jsonString += string + newline
  }
}

/// Serializes a crash log to JSON data using `BacktraceJSONFormatter`.
///
/// - Parameters:
///   - crashLog: The crash log to serialize.
///   - options: JSON formatting options.
/// - Returns: The JSON-encoded data, or `nil` if the crash log is `nil`.
@_spi(Testing)
public func exportAsJson<Address: FixedWidthInteger>(
  crashLog: CrashLog<Address>?,
  options: BacktraceJSONFormatterOptions
) -> Data? {

  guard let crashLog else { return nil }

  let writer = InlineBacktraceWriter(newline: newline)

  var backtraceFormatter = BacktraceJSONFormatter(
    crashLog: crashLog,
    writer: writer,
    options: options)

  backtraceFormatter.writeCrashLog(now: crashLog.timestamp)

  return writer.jsonString.data(using: .utf8)
}
