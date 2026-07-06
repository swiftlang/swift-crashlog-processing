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

#if DEBUG_SCANNER
  func print_ds(_ items: Any...) {
    print(items)
  }
  func print_ds_inline(_ items: Any...) {
    print(items, terminator: "")
  }
#else
  func print_ds(_ items: Any...) {}
  func print_ds_inline(_ items: Any...) {}
#endif

private let readWriteBufferSize = 4096
private let matchBufferSize = 40960

@available(macOS 10.15, *)
/// Scans an input stream byte-by-byte, detects crash log boundaries using
/// ``Recognizer`` state machines, and dispatches matched regions to
/// ``LogStreamReaderWriter`` instances for symbolication.
///
/// Bytes that don't match any crash log pattern are passed through to the
/// output stream unchanged. Multiple crash logs in a single stream are supported.
public class CrashScanner {
  private var inputStream: InputStream
  private var outputStream: OutputStream
  private var logStreamReaderWriters: [any LogStreamReaderWriter]

  private var readBuffer: [UInt8]?
  private var writeBuffer: [UInt8]?
  private var matchBuffer: [UInt8]?

  private var matchBufferPosition = 0
  private var writeBufferPosition = 0
  private var started = false

  deinit {
    if started {
      print_ds(
        "WARNING... deinited CrashScanner without closing it, some buffer data may be lost and memory will be leaked!"
      )
    }
  }

  /// Creates a new crash scanner.
  ///
  /// - Parameters:
  ///   - inputStream: The stream to read raw input from.
  ///   - outputStream: The stream to write output (symbolicated or pass-through) to.
  ///   - logStreamReaderWriters: The format handlers to try, in order, when detecting crash logs.
  public init(
    inputStream: InputStream, outputStream: OutputStream,
    logStreamReaderWriters: [any LogStreamReaderWriter]
  ) {
    self.inputStream = inputStream
    self.outputStream = outputStream
    self.logStreamReaderWriters = logStreamReaderWriters
  }

  /// Opens the input and output streams and allocates internal buffers.
  ///
  /// Must be called before ``scan(process:)``. Calling `start()` on an
  /// already-started scanner has no effect.
  public func start() {
    guard !started else { return }

    outputStream.open()
    inputStream.open()

    matchBufferPosition = 0
    writeBufferPosition = 0

    readBuffer = [UInt8](repeating: 0, count: readWriteBufferSize)
    writeBuffer = [UInt8](repeating: 0, count: readWriteBufferSize)
    matchBuffer = [UInt8](repeating: 0, count: matchBufferSize)

    started = true
  }

  /// Flushes any remaining buffered output, closes both streams, and releases buffers.
  public func stop() {
    guard started else { return }

    if let writeBuffer {
      flushOutputBuffer(writeBuffer: writeBuffer.span, writeBufferPosition: &writeBufferPosition)
    }

    inputStream.close()
    outputStream.close()

    readBuffer = nil
    writeBuffer = nil
    matchBuffer = nil

    started = false
  }

  /// Writes any pending bytes in the output buffer to the output stream.
  ///
  /// - Parameters:
  ///   - writeBuffer: A span over the output buffer.
  ///   - writeBufferPosition: The number of valid bytes in the buffer; reset to 0 after flushing.
  public func flushOutputBuffer(writeBuffer: borrowing Span<UInt8>, writeBufferPosition: inout Int)
  {
    guard started else { return }

    guard writeBufferPosition > 0 else { return }

    defer { writeBufferPosition = 0 }

    writeBuffer.withUnsafeBufferPointer {
      guard let outputBuffer = $0.baseAddress else { return }

      var outputBufferPosition = 0
      while outputBufferPosition < writeBufferPosition {
        let wroteBytes = outputStream.write(
          outputBuffer + outputBufferPosition, maxLength: writeBufferPosition - outputBufferPosition
        )
        print_ds("wroteBytes: \(wroteBytes)")
        if wroteBytes <= 0 { return }
        outputBufferPosition += wroteBytes
        print_ds("outputBufferPosition: \(outputBufferPosition)")
      }
    }
  }

  private func bufferOutputByte(
    byte: UInt8, writeBuffer: inout MutableSpan<UInt8>, writeBufferPosition: inout Int
  ) {
    guard writeBufferPosition < writeBuffer.count else {
      print_ds("WOULD OVERFLOW WRITE BUFFER")
      return
    }

    writeBuffer[writeBufferPosition] = byte
    writeBufferPosition += 1

    if writeBufferPosition >= writeBuffer.count {
      flushOutputBuffer(writeBuffer: writeBuffer.span, writeBufferPosition: &writeBufferPosition)
    }
  }

  private func bufferOutputData(
    data: Data, writeBuffer: inout MutableSpan<UInt8>, writeBufferPosition: inout Int
  ) {
    data.withUnsafeBytes {
      for byte in $0 {
        bufferOutputByte(
          byte: byte, writeBuffer: &writeBuffer, writeBufferPosition: &writeBufferPosition)
      }
    }
  }

  private func storeMatchedByte(byte: UInt8) -> Bool {
    guard let currentMatchBufferSize = matchBuffer?.count else {
      return false
    }

    if matchBufferPosition < currentMatchBufferSize - 1 {
      matchBuffer?[matchBufferPosition] = byte
    } else {
      // extend the buffer as needed
      matchBuffer?.append(byte)
    }

    matchBufferPosition += 1

    return true
  }

  private func flushMatchedBuffer(
    writeBuffer: inout MutableSpan<UInt8>, writeBufferPosition: inout Int
  ) {
    for i in 0..<matchBufferPosition {
      if let byte = matchBuffer?[i] {
        bufferOutputByte(
          byte: byte, writeBuffer: &writeBuffer, writeBufferPosition: &writeBufferPosition)
      }
    }

    matchBufferPosition = 0
  }

  /// Reads the input stream byte-by-byte, detects crash logs, and invokes `process` for each match.
  ///
  /// Non-matching bytes are passed through to the output stream. This method blocks
  /// until the input stream is exhausted. The scanner must be started via ``start()`` first.
  ///
  /// - Parameter process: A closure that receives the matched ``LogStreamReaderWriter`` and the
  ///   captured crash log data, and returns the processed (symbolicated) data.
  /// - Throws: If reading from the input stream fails.
  public func scan(process: (LogStreamReaderWriter, Data) async -> Data) async throws {
    // note: this is a blocking implementation, it's intended to be used on the primary thread of a command line tool
    // so it's appropriate to block the thread until complete or signalled. We can change to async if we want to avoid
    // that one day, but for now it's best to avoid the needless complications.

    guard started else {
      print_ds(
        "WARNING... attempted to use scan() on a CrashScanner that has not been started. Aborting.")
      return
    }

    // the rough approach to the state machine is..
    // - all recognizers start with no match yet
    // - scan the stream character by character
    // - each recognizer gets a turn, if one of them returns .recognizing, or .complete, don't check others
    // - if all return .noMatch, then output the character to the output stream
    // - once a recognizer starts, recognition, feed the characters into matchBuffer one by one
    // - until the recognizer either returns .failed or .complete
    // - if it returns .failed, output the matchBuffer to the output stream and reset it, plus output the last character
    // - if it returns .completed, feed the matchBuffer to the appropriate processor, which outputs to the output stream
    // - finally either way, go back into the loop as before

    var inLogStreamReaderWriter: (any LogStreamReaderWriter)?
    var matchStartFound = false

    var writeBufferSpan = writeBuffer!.mutableSpan

    var readOK = true
    while readOK {

      print_ds("about to read...")
      readOK = try await inputStream.readBytes(into: &readBuffer!) { bytes in
        print_ds("read block into buffer, \(bytes.count)")
        for index in bytes.indices.startIndex..<bytes.indices.endIndex {
          let byte = bytes[index]
          // we use this check-null + force unwrapping pattern to make sure we are mutating the
          // correct instance of CrashLogReaderWriter, and not a local copy
          if inLogStreamReaderWriter != nil {
            print_ds("inCrashLogReaderWriter")
            // continue attempting to recognise start or end
            if matchStartFound {
              let match = inLogStreamReaderWriter!.matchEndRecognizer.scanByte(byte: byte)
              print_ds("0x\(String(byte, radix: 16)) \(match)")

              switch match {
              case .noMatch, .recognizing, .failed:
                if !storeMatchedByte(byte: byte) {
                  print_ds("match buffer full while filling crash log into match buffer")
                  inLogStreamReaderWriter = nil
                  matchStartFound = false
                  flushMatchedBuffer(
                    writeBuffer: &writeBufferSpan, writeBufferPosition: &writeBufferPosition)
                }

              case .complete:
                _ = storeMatchedByte(byte: byte)
                // we have a full start and end match, attempt to process it
                if let matchBuffer {
                  let symbolicatedCrashLog = await process(
                    inLogStreamReaderWriter!, Data(matchBuffer[0..<matchBufferPosition]))
                  bufferOutputData(
                    data: symbolicatedCrashLog, writeBuffer: &writeBufferSpan,
                    writeBufferPosition: &writeBufferPosition)
                  matchBufferPosition = 0
                }

                inLogStreamReaderWriter = nil
                matchStartFound = false
              }

              continue

            } else {
              let match = inLogStreamReaderWriter!.matchStartRecognizer.scanByte(byte: byte)
              print_ds("\(match) for 0x\(String(byte, radix: 16))")

              switch match {
              case .noMatch:
                assertionFailure("inconsistent logic in CrashScanner")
                continue

              case .recognizing:
                if !storeMatchedByte(byte: byte) {
                  // match buffer full while trying to recognize start
                  // this should not happen, but drop out gracefully if it does
                  print_ds("match buffer full while trying to recognize start")
                  flushMatchedBuffer(
                    writeBuffer: &writeBufferSpan, writeBufferPosition: &writeBufferPosition)
                  inLogStreamReaderWriter = nil
                }
                continue

              case .failed:
                // _ = storeMatchedByte(byte: byte)
                flushMatchedBuffer(
                  writeBuffer: &writeBufferSpan, writeBufferPosition: &writeBufferPosition)
                inLogStreamReaderWriter = nil

              case .complete:
                _ = storeMatchedByte(byte: byte)
                matchStartFound = true
                continue
              }
            }
          }

          if inLogStreamReaderWriter == nil {
            for logStreamReaderWriter in logStreamReaderWriters {
              var logStreamReaderWriter = logStreamReaderWriter
              let match = logStreamReaderWriter.matchStartRecognizer.scanByte(byte: byte)
              if match == .recognizing {
                inLogStreamReaderWriter = logStreamReaderWriter
                if !storeMatchedByte(byte: byte) {
                  assertionFailure("match buffer is full before matching")
                  return
                }

                break  // we can stop checking recognizers, we found a match
              } else {
                // reset match buffer
                matchBufferPosition = 0
              }
            }

            if inLogStreamReaderWriter == nil {
              // none of the recognizers recognized the byte as part of their start sequence, so output it
              bufferOutputByte(
                byte: byte, writeBuffer: &writeBufferSpan, writeBufferPosition: &writeBufferPosition
              )
            }
          }
        }
      }
    }
  }
}

@available(macOS 10.14.4, *)
extension InputStream {
  func readBytes(into buffer: inout [UInt8], using: (Span<UInt8>) async -> Void) async throws
    -> Bool
  {
    let readCount = try buffer.withUnsafeMutableBufferPointer {
      guard let inputBuffer = $0.baseAddress else { return 0 }

      let readCount = read(inputBuffer, maxLength: $0.count)

      if readCount < 0, let streamError {
        throw streamError
      }

      return readCount
    }

    guard readCount > 0 else { return false }

    await using(buffer.span.extracting(first: readCount))

    return true
  }
}
