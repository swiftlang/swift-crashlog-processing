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
@_spi(Formatting) import Runtime
@_spi(CrashLog) import Runtime
// this should be removed, just added it
// here temporarily as the compiler is having
// a bad hair day
@_spi(Testing) import Runtime

/// A state-machine parser that reads plain text crash logs and populates a `CrashLog` model.
///
/// Parses the sections of a plain text crash log (description, threads, registers,
/// images, timing) line by line, handling platform differences such as Windows line endings.
public struct PlainCrashLogReader<Address: FixedWidthInteger> {
  enum State {
    case started
    case foundDescription
    case searchingForThreadOrRegisters
    case startingThread
    case inThread
    case inThreadRegisters  // this is for registers per thread
    case startingRegisters  // this is for registers at the end (crashing thread only)
    case inRegisters  // this is for registers at the end (crashing thread only)
    case startingImages
    case inImages
    case complete
  }

  private var plainCrashLogLines: [Substring]

  /// Creates a reader for the given plain text crash log.
  ///
  /// - Parameter plainCrashLog: The full text of the crash log.
  public init(plainCrashLog: String) {
    // use the Foundation method to support newline separators from other
    // platforms (e.g. Windows)
    self.plainCrashLogLines =
      plainCrashLog
      .replacingOccurrences(of: "\r\n", with: "\n")
      .split(separator: "\n", omittingEmptySubsequences: false)
  }

  struct RawThread {
    var index: Int
    var threadDescription: String
    var crashed: Bool
    var rawBacktrace: String
    var rawRegisters: String

    init(index: Int, threadDescription description: Substring?) {
      self.index = index

      if let description {
        let crashedString = " crashed"
        if description.hasSuffix(crashedString) {
          self.threadDescription =
            String(description.dropLast(crashedString.count))
          self.crashed = true
        } else {
          self.threadDescription = String(description)
          self.crashed = false
        }
      } else {
        self.threadDescription = ""
        self.crashed = false
      }

      self.rawBacktrace = ""
      self.rawRegisters = ""
    }
  }

  @available(macOS 13.0, *)
  /// Parses the plain text crash log into a ``CrashLog`` model.
  ///
  /// - Returns: The parsed crash log, or `nil` if parsing fails.
  @_spi(CrashLog) public func parse() -> CrashLog<Address>? {
    var state: State = .started
    let timestamp = ""
    let kind = "crashReport"
    var description: Substring?
    var faultAddress: Substring?
    var platform: Substring?
    var arch: Substring?
    var backtraceTime: Double?

    var threads: [RawThread] = []
    var threadBeingFound: RawThread?
    var crashingThreadRawRegisters = ""

    var rawImages: [String] = []
    var omittedImages: Int?

    let descriptionRegex = /Program crashed: (.+) [*]*/
    let faultAddressFromDescriptionRegex = /(.+) at (0x.+)/
    let platformRegex = /Platform: (.+)/
    let threadRegex = /Thread ([0-9]+)( .+)?:/
    let registersRegex = /Registers:/
    let imagesRegex = /Images (\([0-9]+ omitted\))?:/
    let backtraceRegex = /Backtrace took ([0-9.]+)s/
    let inThreadRegisterRegex = /[ ]*[^ ]+ 0x[0-9a-f]+  [0-9a-fA-Z]+/

    func find(_ regex: Regex<(Substring, Substring)>, _ line: Substring) -> Substring? {
      let match = line.firstMatch(of: regex)
      return match?.output.1
    }

    for line in plainCrashLogLines {
      switch state {
      case .started:
        if let match = find(descriptionRegex, line) {
          description = match
          faultAddress = match.firstMatch(of: faultAddressFromDescriptionRegex)?.output.2
          state = .foundDescription
        }

      case .foundDescription:
        if let match = find(platformRegex, line) {
          platform = match
          state = .searchingForThreadOrRegisters
        }

      case .searchingForThreadOrRegisters:
        if let match = line.firstMatch(of: threadRegex) {
          if let threadFound = threadBeingFound {
            // if we found a new thread, append any previous thread
            // that was being constructed to our list
            threads.append(threadFound)
            threadBeingFound = nil
          }

          let idx = Int(match.1) ?? -1

          threadBeingFound =
            RawThread(index: idx, threadDescription: match.2)

          state = .startingThread
        } else if line.contains(registersRegex) {
          state = .startingRegisters
        } else if line.contains(inThreadRegisterRegex) {
          crashingThreadRawRegisters += "\(line)\n"
        } else if let match = line.firstMatch(of: imagesRegex) {
          if let ommittedCount = match.output.1?.split(separator: " ").first,
            let ommitted = Int(ommittedCount.trimmingPrefix("("))
          {
            omittedImages = ommitted
          }

          if let threadFound = threadBeingFound {
            // if we found images, append any previous thread
            // that was being constructed to our list
            threads.append(threadFound)
            threadBeingFound = nil
          }
          state = .startingImages
        } else if let match = find(backtraceRegex, line) {
          backtraceTime = Double(match)
          state = .complete
        }

      case .startingThread:
        if line.isEmpty {
          state = .inThread
        }

      case .startingRegisters:
        if line.isEmpty {
          state = .inRegisters
        }

      case .startingImages:
        if line.isEmpty {
          state = .inImages
        }

      case .inRegisters:
        if line.isEmpty {
          state = .searchingForThreadOrRegisters
        } else {
          crashingThreadRawRegisters += "\(line)\n"
        }

      case .inThread:
        if line.isEmpty {
          // end of backtrace... note, this may not be compatible with source dumps
          // but this tool is meant for symbolicating
          // unsymbolicated backtraces, so that's hopefully not an issue
          state = .searchingForThreadOrRegisters
        } else if threadBeingFound != nil {
          // check if the line is registers or backtrace
          // for this thread, if it's registers, switch to
          // state .inThreadRegisters, which is similar, but
          // will allow for the blank line between registers
          // and the backtrace

          // it's quite hard to distinguish register lines from backtraces,
          // especially if unsymbolicated, a register line is like...
          // x1 0x0000000000000000  0
          // and an unsymbolicated backtrace line might look like...
          // 0      0x0000000198ade2f4
          // symbolicated looks like...
          // 0                0x0000000180ef62f4 ___semwait_signal...
          // so we are going to look for (.*) <hex>  [0-9] and assume that indicates registers
          if line.matches(of: inThreadRegisterRegex).first != nil {
            state = .inThreadRegisters
            threadBeingFound!.rawRegisters += "\(line)\n"
          } else {
            threadBeingFound!.rawBacktrace += "\(line)\n"
          }
        }
      case .inThreadRegisters:
        if line.isEmpty {
          state = .inThread  // look for backtrace now
        } else if threadBeingFound != nil {
          threadBeingFound!.rawRegisters += "\(line)\n"
        }

      case .inImages:
        if let match = find(backtraceRegex, line) {
          backtraceTime = Double(match)
          state = .complete
        } else if !line.isEmpty {
          rawImages.append(String(line))
        }

      case .complete:
        break
      }
    }

    if let threadFound = threadBeingFound {
      // append any previous thread
      // that was being constructed to our list
      threads.append(threadFound)
      threadBeingFound = nil
    }

    guard state == .complete else {
      #if DebuggingSymbolicator
        print("Parse failed. Ended in state: \(state)")
      #endif
      return nil
    }

    if let platform {
      arch = String(platform).split(separator: " ").first
    }

    var capturedMemory: [String: String] = [:]

    let crashThreads =
      threads
      .sorted(by: { $0.index < $1.index })
      .map {
        if $0.crashed, $0.rawRegisters.isEmpty {
          var t = $0
          t.rawRegisters = crashingThreadRawRegisters
          return t
        } else {
          return $0
        }
      }
      .compactMap {
        CrashLog<Address>.Thread.read(
          fromRawThread: $0,
          capturedMemory: &capturedMemory)
      }

    let images = rawImages.compactMap {
      CrashLog<Address>.Image(fromRawLine: $0)
    }

    return CrashLog(
      timestamp: timestamp,
      kind: kind,
      description: String(description ?? ""),
      faultAddress: String(faultAddress ?? ""),
      platform: String(platform ?? ""),
      architecture: String(arch ?? ""),
      threads: crashThreads,
      capturedMemory: capturedMemory.isEmpty ? nil : capturedMemory,
      omittedImages: omittedImages,
      images: images,
      backtraceTime: backtraceTime ?? 0.0)
  }
}

extension CrashLog.Frame {
  init(type: Substring?, address: Substring) {
    // TODO: we can't distinguish ommitted vs truncated
    let kind: Kind =
      switch (type, address) {
      case ("[ra]", _): .returnAddress
      case ("[async]", _): .asyncResumePoint
      case (nil, "..."): .truncated
      default: .programCounter
      }

    let addressString = (address.isEmpty || address == "...") ? nil : String(address)

    self.init(kind: kind, address: addressString)
  }
}

extension CrashLog.Thread {
  static func read(
    fromRawThread rawThread: PlainCrashLogReader<Address>.RawThread,
    capturedMemory: inout [String: String],
  ) -> CrashLog.Thread? {

    let registerRegex = /[ ]*([^ ]+) (0x[0-9a-f]+)  (.*)/
    let compactRegisterRegex = /([^ ]+) (0x[0-9a-f]+)/
    var registers: [String: String] = [:]

    for rawLine in rawThread
      .rawRegisters
      .replacingOccurrences(of: "\r\n", with: "\n")
      .split(separator: "\n")
    where !rawLine.isEmpty {
      if let matchOutput = rawLine.firstMatch(of: registerRegex)?.output {
        registers[matchOutput.1.trimmingCharacters(in: CharacterSet.whitespaces)] = String(
          matchOutput.2)
        let remainder = matchOutput.3
        if remainder.count > 32, let memory = remainder.split(separator: "  ").first {
          capturedMemory[String(matchOutput.2)] = memory.filter { $0 != " " }
        } else {
          // check for additional registers on the same line
          // e.g. "cs 0x0033  fs 0x0053  gs 0x002b"
          for match in remainder.matches(of: compactRegisterRegex) {
            registers[String(match.1)] = String(match.2)
          }
        }
      }
    }

    let frameRegex = /[ ]*([0-9]+) (\[[a-z]+\])? +(.*)/
    var frames: [CrashLog<Address>.Frame] = []

    for rawLine in rawThread
      .rawBacktrace
      .replacingOccurrences(of: "\r\n", with: "\n")
      .split(separator: "\n")
    where !rawLine.isEmpty {
      if let matchOutput = rawLine.firstMatch(of: frameRegex)?.output {
        let addressPlusSymbolication = matchOutput.3
        // for now, if we have a symbolicated frame, just discard the current symbolication
        // handling cumulative symbolication is complicated, when do we override, etc.?
        let address = addressPlusSymbolication.split(separator: " ").first
        frames.append(.init(type: matchOutput.2, address: address ?? addressPlusSymbolication))
      }
    }

    return CrashLog.Thread(
      name: rawThread.threadDescription,
      crashed: rawThread.crashed,
      registers: registers.isEmpty ? nil : registers,
      frames: frames
    )
  }
}

extension CrashLog.Image {
  init?(fromRawLine rawLine: String) {
    let imageRegex =
      /(0x[0-9a-f]+)[-−‐–](0x[0-9a-f]+) ([0-9a-f]+(?::[0-9a-f]+)?|<no build ID>) +([^ ]+) +([^ ]+)/

    guard let matchOutput = rawLine.firstMatch(of: imageRegex)?.output else { return nil }
    let name = String(matchOutput.4)
    let rawBuildId = String(matchOutput.3)
    let buildId: String? = rawBuildId == "<no build ID>" ? nil : rawBuildId
    let path = String(matchOutput.5)
    let baseAddress = String(matchOutput.1)
    let endOfText = String(matchOutput.2)

    self.init(
      name: name,
      buildId: buildId,
      path: path,
      baseAddress: baseAddress,
      endOfText: endOfText
    )
  }
}
