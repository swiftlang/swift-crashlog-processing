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

extension CrashScanner {
  /// Convenience method that calls ``start()``, scans the input stream
  /// symbolicating any detected crash logs via their ``LogStreamReaderWriter``,
  /// and then calls ``stop()``.
  ///
  /// - Throws: If reading from the input stream fails.
  public func scanAndProcessStreams() async throws {
    start()

    try await scan { logScanner, data in
      await logScanner.processLog(data: data)
    }

    stop()
  }
}
