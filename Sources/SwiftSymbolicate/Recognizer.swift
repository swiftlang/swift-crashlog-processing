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

#if DEBUG_RECOGNIZER
  func print_dr(_ items: Any...) {
    print(items)
  }
#else
  func print_dr(_ items: Any...) {}
#endif

/// The recognizer is expected to work byte by byte on a buffer or stream.
/// It must be configured with a signature to scan for, consisting either of exact
/// bytes to match (e.g. a string), or a combination of matches and skip sections
/// (see below). Note that the signature must have at least two bytes to match otherwise
/// this is a programmer error, it is not intended to scan for single byte matches.
///
/// The recognizer starts in a "no match" state, in this state, scanByte() will attempt to match
/// the byte being scanned against the start of the signature. If it doesn't match,
/// it returns .noMatch and remains in an otherwise unchanged state, ready for the next
/// byte. If it finds a match to the start of the signature, it returns .recognizing.
/// It also moves an internal pointer to the next position in the signature,
/// which is why the function is mutating.
///
/// When the next byte is read, if it's still a match, it returns .recognizing again and
/// again moves the internal pointer, until it either finds a byte that doesn't match or
/// reaches the end of the signature.
///
/// If it has matched right up to (and including) the end of the signature, it returns .completed.
/// If it finds any mismatch, it returns .failure.
///
/// The above makes simple sense for signatures composed of bytes that are .exact() ...
/// there's a slightly different approach if you want to skip over a run of characters. You
/// use .skipTo(endByte:maxRun:) which will keep returning .recognizing until it either
/// reaches the endByte, or maxRun characters. This is useful for matching something like
/// the contents until a ". .skipTo(endByte:X, maxRun: 100) is probably something like a
/// regex [^X]{1,100}
public struct Recognizer {
  var recognizedPositionInSignature = 0
  var skipCount = 0
  var signature: [SignaturePart]

  /// The result of scanning a single byte against the signature.
  public enum RecognitionStatus {
    /// No bytes yet matched.
    case noMatch
    /// Byte matching is in progress.
    case recognizing
    /// A byte did not match the expected signature; recognition has been reset.
    case failed
    /// The full signature was matched.
    case complete
  }

  enum NextAction {
    case advanceInSignature
    case continueSkip
    case redigestLastByte
    case noAction
  }

  /// A single element of a recognizer signature.
  public enum SignaturePart {
    /// Match an exact byte value.
    case exact(byte: UInt8)
    /// Skip bytes until `endByte` is found, up to a maximum of `maxRun` bytes.
    case skipTo(endByte: UInt8, maxRun: Int)

    func matches(
      byte: UInt8,
      skipCount: inout Int
    ) -> (Bool, NextAction) {

      switch self {
      case .exact(let test):
        print_dr("checking exact match: \(test == byte)")
        return (test == byte, .advanceInSignature)

      case .skipTo(let endByte, let max):
        skipCount += 1
        print_dr("skipped bytes: \(skipCount)")
        if skipCount > max {
          // ran over the maximum
          skipCount = 0
          return (false, .advanceInSignature)
        } else {
          print_dr("skip, checking byte skipped was not endByte: \(endByte != byte)")
          if endByte != byte {
            return (true, .continueSkip)
          } else {
            // we found the end character
            return (true, .redigestLastByte)
          }
        }
      }
    }
  }

  /// Creates a recognizer with a flat array of signature parts.
  ///
  /// - Parameter signature: The signature parts to match against. Must contain at least two elements.
  public init(signature: [SignaturePart]) {
    guard signature.count > 1 else {
      fatalError("signature too short, must be at least two bytes match")
    }

    self.signature = signature
  }

  /// Creates a recognizer from one or more arrays of signature parts, concatenated in order.
  ///
  /// This is the primary initializer, typically used with the convenience `Array` extensions:
  /// ```swift
  /// Recognizer(.init("hello "), .init(skipTo: "!", max: 50)!, .init("!"))
  /// ```
  ///
  /// - Parameter signature: One or more arrays of ``SignaturePart`` elements.
  public init(_ signature: [SignaturePart]...) {
    self.init(signature: signature.reduce([], { $0 + $1 }))
  }

  /// Scans a single byte against the current position in the signature.
  ///
  /// Call this repeatedly for each byte in the input stream. The recognizer
  /// maintains internal state across calls:
  /// - ``RecognitionStatus/noMatch``: The byte didn't start a match. Pass it through.
  /// - ``RecognitionStatus/recognizing``: Partial match in progress. Buffer the byte.
  /// - ``RecognitionStatus/failed``: A partial match broke. Flush the buffered bytes.
  /// - ``RecognitionStatus/complete``: The full signature was matched.
  ///
  /// - Parameter byte: The next byte from the input stream.
  /// - Returns: The current recognition status after processing this byte.
  public mutating func scanByte(byte: UInt8) -> RecognitionStatus {
    print_dr(
      "scanning 0x\(String(byte, radix: 16)) against "
        + "signature position \(recognizedPositionInSignature) " + "of \(signature.count)")

    let (matches, nextAction) =
      signature[recognizedPositionInSignature].matches(byte: byte, skipCount: &skipCount)

    if matches {
      if nextAction == .redigestLastByte {
        print_dr("rescan last byte")
        recognizedPositionInSignature += 1
        print_dr("advance to signature position: \(recognizedPositionInSignature)")
        return scanByte(byte: byte)
      }

      if recognizedPositionInSignature == signature.count - 1 {
        recognizedPositionInSignature = 0
        print_dr("returning .complete")
        return .complete
      } else {
        if nextAction == .advanceInSignature {
          recognizedPositionInSignature += 1
          print_dr("advance to signature position: \(recognizedPositionInSignature)")
        }

        print_dr("returning .inProgress")
        return .recognizing
      }
    } else {
      skipCount = 0

      if recognizedPositionInSignature > 0 {
        recognizedPositionInSignature = 0
        print_dr("returning .failed")
        return .failed
      } else {
        print_dr("returning .no")
        return .noMatch
      }
    }
  }
}

/// Convenience initializers for building ``Recognizer`` signatures from
/// strings, byte arrays, and skip-to patterns.
extension Array where Element == Recognizer.SignaturePart {
  /// Creates signature parts from a raw byte array, with one ``Recognizer/SignaturePart/exact(byte:)`` per byte.
  ///
  /// - Parameter bytes: The bytes to match exactly.
  public init(bytes: [UInt8]) {
    self = bytes.map { Recognizer.SignaturePart.exact(byte: $0) }
  }

  /// Creates signature parts that match the UTF-8 encoding of a string exactly.
  ///
  /// - Parameter string: The string whose UTF-8 bytes to match.
  public init(_ string: String) {
    self.init(bytes: [UInt8](string.utf8))
  }

  /// Creates a single ``Recognizer/SignaturePart/skipTo(endByte:maxRun:)`` element.
  ///
  /// Returns `nil` if the character cannot be represented as a single UTF-8 byte.
  ///
  /// - Parameters:
  ///   - skipTo: The delimiter character that ends the skip.
  ///   - max: The maximum number of bytes to skip before failing.
  public init?(skipTo: Character, max: Int) {
    guard let skip = [UInt8](skipTo.utf8).first else { return nil }
    self = [.skipTo(endByte: skip, maxRun: max)]
  }
}
