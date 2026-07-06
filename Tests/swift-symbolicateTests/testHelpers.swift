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

import Testing
import Foundation
import SwiftSymbolicate
import Subprocess

#if canImport(System)
@preconcurrency import System
#else
@preconcurrency import SystemPackage
#endif

@_spi(Contexts) import Runtime
@_spi(Testing) import Runtime
@_spi(Utils) import Runtime
@_spi(Formatting) import Runtime
@_spi(CrashLog) import Runtime
@_spi(Internal) import Runtime
@_spi(SymbolLocation) import Runtime

@_spi(Testing) import SwiftSymbolicate
@_spi(CrashLog) import SwiftSymbolicate
@_spi(Formatting) import SwiftSymbolicate

protocol UsingLogStream {
}

extension UsingLogStream {
    func getCrashLog(isJson: Bool, isSymbolicated: Bool, isMultiThreaded: Bool = false) async throws -> String {
        #if os(Windows)
        guard !isMultiThreaded else {
            fatalError("crash with threads tests not implemented for Windows")
        }
        #endif

        let jsonOption = if isJson { ",format=json" } else { "" }
        let symbolicatedOption = if isSymbolicated { ",symbolicate=yes" } else { ",symbolicate=no" }
        let appName: FilePath = if isMultiThreaded { FilePath("./.build/debug/crashMeMultithreaded") } else { FilePath("./.build/debug/crashMe") }

        var environment: [Subprocess.Environment.Key: String] =
        [
            "SWIFT_BACKTRACE":"enable=yes,cache=no\(jsonOption)\(symbolicatedOption)"
        ]

        #if os(macOS)
        if let dyldPath = ProcessInfo.processInfo.environment["DYLD_LIBRARY_PATH"] {
            print("setting dylib path")
            environment["DYLD_LIBRARY_PATH"] = dyldPath
        }

        if let dyldInsert = ProcessInfo.processInfo.environment["DYLD_INSERT_LIBRARIES"] {
            print("setting dylib insert")
            environment["DYLD_INSERT_LIBRARIES"] = dyldInsert
        }
        #endif

        let crashRun = try await run(
            .path(appName),
            environment: .custom(
                environment
            ),
            output: .string(limit: 40960),
            error: .combinedWithOutput)
        if isJson, let log = crashRun.standardOutput?.split(separator: "\n").first(where: { $0.hasPrefix("{") }) {
            return String(log)
        } else {
            return crashRun.standardOutput ?? "---"
        }
    }
}

extension UsingLogStream {
    func checkRecognized(recognizer: Recognizer, text: String) -> Recognizer.RecognitionStatus {
        var recognizer = recognizer

        let jsonTraceBytes = [UInt8](text.data(using: .utf8)!)

        let recognized = jsonTraceBytes.reduce(Recognizer.RecognitionStatus.noMatch) {
            // $0 + recognizer.scanByte(byte: $1)
            let match = recognizer.scanByte(byte: $1)
            return switch ($0, match) {
                // if recognition was already complete or we complete it here, it stays complete until the end
                case (.complete, _),(_, .complete): .complete
                // if failed, rescan this byte to see if it restarts straight afterwards
                case (_, .failed): (recognizer.scanByte(byte: $1) == .recognizing ? .recognizing : .failed)
                // otherwise, if it was already failed, it stays failed until the end
                case (.failed, _): $0
                // and finally, when none of the above apply, just keep the last result
                default: match
            }
        }

        return recognized
    }

    func testScan(sampleData sampleDataString: String,
        process: (Data) throws -> Data) async throws -> String? {

        let sample = try #require(sampleDataString.data(using: .utf8))
        let inputStream = InputStream(data: sample)
        let outputStream = OutputStream.toMemory()

        let crashLogReaderWriter = JsonLogStreamReaderWriter(
            symbolAdditionalPaths: [],
            symbolicateAllThreads: true,
            symbolicationOptions: [.showSourceLocations],
            jsonFormatterOptions: [.demangle, .images, .allThreads],
            symbolServers: [])

        let btFormattingOptions: BacktraceFormattingOptions =
            .skipRuntimeFailures(false)
            .skipThunkFunctions(false)
            .skipSystemFrames(false)
            .sanitizePaths(false)

        let plainCrashLogReaderWriter = PlainTextLogStreamReaderWriter(
            symbolAdditionalPaths: [],
            symbolicateAllThreads: true,
            symbolicationOptions: [.showSourceLocations],
            plainTextFormatterOptions: btFormattingOptions,
            symbolServers: [])

        let crashScanner = CrashScanner(
            inputStream: inputStream,
            outputStream: outputStream,
            logStreamReaderWriters: [crashLogReaderWriter,plainCrashLogReaderWriter])

        crashScanner.start()

        try await crashScanner.scan { _, data in
            do {
                return try process(data)
            } catch {
                return Data()
            }
        }

        crashScanner.stop()
        let outputData = try #require(outputStream.property(forKey: .dataWrittenToMemoryStreamKey) as? Data)

        guard outputData.count > 0 else { return nil }

        return String(data: outputData, encoding: .utf8)
    }

    func symbolicateJsonCrashLog(
        data: Data,
        platform: Backtrace.SymbolicationPlatform = .default,
        options: BacktraceJSONFormatterOptions? = nil) throws -> Data {

        do {
            var crashLog = try HostCrashLog.loadFromJSON(data)
            var btoptions = Backtrace.SymbolicationOptions.default
            let defaultSymbolLocator = DefaultSymbolLocator()
            btoptions.remove(.useSymbolCache)
            crashLog.symbolicate(
                allThreads: true,
                platform: platform,
                options: btoptions,
                symbolLocator: defaultSymbolLocator
            )

            let exportoptions = options ?? BacktraceJSONFormatterOptions(rawValue: 0)
            return exportAsJson(crashLog: crashLog, options: exportoptions) ?? data
        } catch {
            return data
        }
    }

    func symbolicatePlainTextCrashLog(
        data: Data,
        platform: Backtrace.SymbolicationPlatform = .default) throws -> Data {

        guard let plainCrashLog = String(data:data, encoding: .utf8)
        else { return data }

        let reader = PlainCrashLogReader<HostContext.Address>(
            plainCrashLog: plainCrashLog)

        guard var crashLog = reader.parse() else { return data }

        let defaultSymbolLocator = DefaultSymbolLocator()

        crashLog.symbolicate(
            allThreads: true,
            platform: platform,
            symbolLocator: defaultSymbolLocator)

        let writer = PlainCrashLogWriter<HostContext.Address>(
            crashLog,
            options:
                BacktraceFormattingOptions()
                    .skipSystemFrames(false)
                    .sanitizePaths(false),
            lineSeparator: "\n",
            width: .auto,
            haveSymbolicatedThreads: true)

        let output = writer.write()

        return output.data(using: .utf8) ?? data
    }
}

@resultBuilder
struct MatchBuilder {
    static func buildBlock() -> [any Matchable] { [] }
    static func buildBlock(_ regexes: any Matchable...) -> [any Matchable] { regexes }
}

extension SourceLocation {
    func adjustedBy(addToLine: Int) -> SourceLocation {
        SourceLocation(fileID: fileID, filePath: filePath, line: line+addToLine, column: column)
    }
}

protocol Matchable {
    func matches(_ string: Substring) -> Bool
    func debugDescription() -> String
}


extension String: Matchable {
    func matches(_ string: Substring) -> Bool {
        string.contains(self)
    }

    func debugDescription() -> String {
        self
    }
}

extension Regex<Substring>: Matchable {
    func matches(_ string: Substring) -> Bool {
        string.firstMatch(of: self) != nil
    }

    func debugDescription() -> String {
        String(describing: self)
    }
}
extension String {
    /// This checks the string against a sequence of regexes/strings, one per line.
    /// Lines that don't match will be skipped, but all regexes/strings must be found,
    /// in the order they are passed. If all regexes/strings found, returns nil. If
    /// you run out of lines before all are found, this returns the index of the first regex/string
    /// that was not found.
    @available(macOS 15.0, *)
    func compareToMatches(_ matches: [any Matchable], separator: Character = "\n") -> Int? {
        var lines = split(separator: separator).makeIterator()
        var matchIterator = matches.makeIterator()

        var match = matchIterator.next()
        var failedMatch = 0

        while let line = lines.next(), let currentMatch = match {
            if currentMatch.matches(line) {
                match = matchIterator.next()
                failedMatch += 1
            }
        }
        
        return match == nil ? nil : failedMatch
    }
    
    @available(macOS 15.0, *)
    func compareTo(separator: Character = "\n", @MatchBuilder _ content: () -> [any Matchable]) -> Bool {
        compareToMatches(content(), separator: separator) == nil
    }

    @available(macOS 15.0, *)
    func expect(
        separator: Character = "\n",
        sourceLocation: SourceLocation = #_sourceLocation,
        @MatchBuilder _ content: () -> [any Matchable]) {
            let matches = content()
            let failedMatch = compareToMatches(matches, separator: separator)
            let failureLocation = if let failedMatch {
                // this isn't perfect but should get us close in most cases
                sourceLocation.adjustedBy(addToLine: failedMatch+1)
            } else {
                sourceLocation
            }

            #expect(failedMatch == nil,
             "pattern was not found, could not find \(matches[safe: failedMatch]) in \(self)",
              sourceLocation: failureLocation)
    }
}

extension Array {
    subscript(safe index: Int?) -> Element? {
        guard let index, index >= 0, index < count else { return nil }
        return self[index]
    }
}
