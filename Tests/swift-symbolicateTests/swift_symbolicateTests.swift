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

@testable import SwiftSymbolicate
@_spi(Contexts) import Runtime
@_spi(Testing) import Runtime
@_spi(Utils) import Runtime
@_spi(Formatting) import Runtime
@_spi(CrashLog) import Runtime
@_spi(Testing) import SwiftSymbolicate
@_spi(CrashLog) import SwiftSymbolicate

@testable import swift_symbolicate

typealias HostCrashLog = CrashLog<HostContext.Address>

#if os(Linux)
let platformName = "Linux"
#elseif os(macOS)
let platformName = "macOS"
#endif

#if TestGeneral

struct Utilities {
    @Test func testConverters() async throws {
        #expect(HostCrashLog.wordSize(forArchitecture: "arm") == .thirtyTwoBit)
        #expect(HostCrashLog.wordSize(forArchitecture: "arm64") == .sixtyFourBit)
        #expect(HostCrashLog.wordSize(forArchitecture: "i386") == .thirtyTwoBit)
        #expect(HostCrashLog.wordSize(forArchitecture: "x86_64") == .sixtyFourBit)

        #expect(HostCrashLog.addressFromString("0x000000010455c000") == 0x000000010455c000)
        #expect(HostCrashLog.addressFromString("0x000000019d24ff64") == 0x000000019d24ff64)
    }

    @Test func hexStringRoundTrip() async throws {
        func checkMatch(_ source: String, _ test: String) -> Bool {
            let bytes = HostCrashLog.bytesFromHexString(source)
            let recreatedString = hex(bytes)
            return recreatedString == test
        }

        #expect(checkMatch("6fdbb104c032301189bae26d5506e11a", "6fdbb104c032301189bae26d5506e11a"))
        #expect(checkMatch("6fdbb104c032301189bae26d5506e11aas", "6fdbb104c032301189bae26d5506e11a"))
        #expect(checkMatch("", ""))
    }

    @Test func checkHex() async throws {
        #expect(hex([UInt8](" 12".data(using: .utf8) ?? Data()))=="203132")
    }
}

struct Environment {
    // tests for parsing the environment variable
    @Test func testDefaults() async throws {
        let opts = SwiftSymbolicate.getJsonBacktraceFormatterOptions(
            swiftBacktraceEnvSettings: nil)
        #expect(opts == [.demangle,.images,.allThreads])
    }

    @Test func testEmptyString() async throws {
        let opts = SwiftSymbolicate.getJsonBacktraceFormatterOptions(
            swiftBacktraceEnvSettings: "")
        #expect(opts == [.demangle,.images,.allThreads])
    }

    @Test func testGarbage() async throws {
        let opts = SwiftSymbolicate.getJsonBacktraceFormatterOptions(
            swiftBacktraceEnvSettings: "garbage")
        #expect(opts == [.demangle,.images,.allThreads])
    }

    @Test func testUnkownSetting() async throws {
        let opts = SwiftSymbolicate.getJsonBacktraceFormatterOptions(
            swiftBacktraceEnvSettings: "unknown=setting")
        #expect(opts == [.demangle,.images,.allThreads])
    }

    @Test func testBadFormatting() async throws {
        let opts = SwiftSymbolicate.getJsonBacktraceFormatterOptions(
            swiftBacktraceEnvSettings: "bad== formatting, other,,Mistake=")
        #expect(opts == [.demangle,.images,.allThreads])
    }

    @Test func testNoDemangle() async throws {
        let opts = SwiftSymbolicate.getJsonBacktraceFormatterOptions(
            swiftBacktraceEnvSettings: "demangle=no")
        #expect(opts == [.images,.allThreads])
    }

    @Test func testGoodAndBadSettings() async throws {
        let opts = SwiftSymbolicate.getJsonBacktraceFormatterOptions(
            swiftBacktraceEnvSettings: "bad== formatting, other,,Mistake=,demangle=no")
        #expect(opts == [.images,.allThreads])
    }

    @Test func testSanitize() async throws {
        let opts = SwiftSymbolicate.getJsonBacktraceFormatterOptions(
            swiftBacktraceEnvSettings: "sanitize=yes")
        #expect(opts == [.demangle,.images,.allThreads,.sanitize])
    }

    @Test func testAllRegisters() async throws {
        let opts = SwiftSymbolicate.getJsonBacktraceFormatterOptions(
            swiftBacktraceEnvSettings: "registers=all")
        #expect(opts == [.demangle,.images,.allThreads,.allRegisters])
    }

    @Test func testMentionedImages() async throws {
        let opts = SwiftSymbolicate.getJsonBacktraceFormatterOptions(
            swiftBacktraceEnvSettings: "images=mentioned")
        #expect(opts == [.demangle,.images,.allThreads,.mentionedImages])
    }

    @Test func testCrashedThread() async throws {
        let opts = SwiftSymbolicate.getJsonBacktraceFormatterOptions(
            swiftBacktraceEnvSettings: "threads=crashed")
        #expect(opts == [.demangle,.images])
    }

    @Test func testNoImagesCrashedThread() async throws {
        let opts = SwiftSymbolicate.getJsonBacktraceFormatterOptions(
            swiftBacktraceEnvSettings: "threads=crashed,images=none")
        #expect(opts == [.demangle])
    }

    @Test func testSanitizeAndNoDemangle() async throws {
        let opts = SwiftSymbolicate.getJsonBacktraceFormatterOptions(
            swiftBacktraceEnvSettings: "sanitize=yes,demangle=no")
        #expect(opts == [.images,.allThreads,.sanitize])
    }
}

struct PlainTextCrashLog {
    @Test func simplePlainTextRoundTrip() async throws {
        let reader = PlainCrashLogReader<HostContext.Address>(
            plainCrashLog: unsymbPlain1)

        let crashLog = try #require(reader.parse(), "unable to parse plain crash log")

        let writer = PlainCrashLogWriter(
            crashLog,
            options: BacktraceFormattingOptions()
                .skipSystemFrames(false)
                .sanitizePaths(false),
            lineSeparator: "\n",
            width: .auto,
            haveSymbolicatedThreads: false)

        let output = writer.write()

        #expect(output == unsymbPlain1)
    }

    @Test func simplePlainTextRead() async throws {
        let reader = PlainCrashLogReader<HostContext.Address>(plainCrashLog: unsymbolicatedPlainCrashLog)
        let crashLog = try #require(reader.parse(), "unable to parse plain crash log")

        #expect(crashLog.description == "Bad pointer dereference at 0x000000000deadbee")
        #expect(crashLog.platform == "arm64 macOS 26.1 (25B64)")

        #expect(crashLog.architecture == "arm64")
        #expect(crashLog.backtraceTime == 0.54)
        #expect(crashLog.omittedImages == 337)

        #expect(crashLog.images?.count == 2)

        let firstImage = try #require(crashLog.images?.first)
        #expect(firstImage.baseAddress == "0x0000000104ea8000")
        #expect(firstImage.endOfText == "0x0000000104eac000")
        #expect(firstImage.name == "crashMe")
        #expect(firstImage.buildId == "6fdbb104c032301189bae26d5506e11a")
        #expect(firstImage.path == "/Users/carlpeto/Desktop/crashMe")

        let secondImage = try #require(crashLog.images?.dropFirst().first)
        #expect(secondImage.baseAddress == "0x000000019d1b1000")
        #expect(secondImage.endOfText == "0x000000019d24ff64")
        #expect(secondImage.name == "dyld")
        #expect(secondImage.buildId == "175354de24cb330199ef3ce9f1952bfd")
        #expect(secondImage.path == "/usr/lib/dyld")

        #expect(crashLog.threads.count == 1)

        let firstThread = try #require(crashLog.threads.first)

        #expect(firstThread.crashed)
        #expect(firstThread.registers?["x0"] == "0x0000000000000001")
        #expect(firstThread.registers?["x1"] == "0x0000000000000000")
        #expect(firstThread.registers?["x16"] == "0x000000019d58b030")
        #expect(firstThread.registers?["pc"] == "0x0000000104ea8a1c")

        #expect(crashLog.capturedMemory?["0x0000000104ea8a1c"] == "280100f900008052fd7b48a9ff430291")

        #expect(firstThread.frames.count == 3)

        let firstFrame = try #require(firstThread.frames.first)
        #expect(firstFrame.kind == .programCounter)
        #expect(firstFrame.address == "0x0000000104ea8a1c")
        #expect(firstFrame.symbol == nil)
        #expect(firstFrame.count == nil)
        #expect(firstFrame.offset == nil)
        #expect(firstFrame.description == nil)
        #expect(firstFrame.image == nil)
        #expect(firstFrame.sourceLocation == nil)

        let secondFrame = try #require(firstThread.frames.dropFirst().first)
        #expect(secondFrame.kind == .returnAddress)
        #expect(secondFrame.address == "0x000000019d1b9d54")
        #expect(secondFrame.symbol == nil)
        #expect(secondFrame.count == nil)
        #expect(secondFrame.offset == nil)
        #expect(secondFrame.description == nil)
        #expect(secondFrame.image == nil)
        #expect(secondFrame.sourceLocation == nil)

        let thirdFrame = try #require(firstThread.frames.dropFirst().dropFirst().first)
        #expect(thirdFrame.kind == .truncated)
        #expect(thirdFrame.address == nil)
        #expect(thirdFrame.symbol == nil)
        #expect(thirdFrame.count == nil)
        #expect(thirdFrame.offset == nil)
        #expect(thirdFrame.description == nil)
        #expect(thirdFrame.image == nil)
        #expect(thirdFrame.sourceLocation == nil)
    }

    @Test func simplePlainTextMultiThreadWithRegistersRead() async throws {
        let reader = PlainCrashLogReader<HostContext.Address>(plainCrashLog: plainCrashLogSymbolicatedAllRegistersMultithreaded)
        let crashLog = try #require(reader.parse(), "unable to parse plain crash log")

        #expect(crashLog.description == "Bad pointer dereference at 0x0000000000000008")
        #expect(crashLog.platform == "arm64 macOS 26.4 (25E230)")

        #expect(crashLog.architecture == "arm64")
        #expect(crashLog.backtraceTime == 0.12)
        #expect(crashLog.omittedImages == 45)

        #expect(crashLog.images?.count == 5)

        let firstImage = try #require(crashLog.images?.first)
        #expect(firstImage.baseAddress == "0x0000000100b68000")
        #expect(firstImage.endOfText == "0x0000000100b6c000")
        #expect(firstImage.name == "crashMeMultithreaded")
        #expect(firstImage.buildId == "5c59de45bb123fb7b1ec3e4ca4920a0d")
        #expect(firstImage.path == "/Users/carlpeto/Code/swift-symbolicate/.build/arm64-apple-macosx/debug/crashMeMultithreaded")

        #expect(crashLog.threads.count == 10)

        let firstThread = try #require(crashLog.threads.first)

        #expect(firstThread.crashed == false)
        #expect(firstThread.registers?["x0"] == "0x0000000000000a03")
        #expect(firstThread.registers?["x8"] == "0x00000001f9a1c898")
        #expect(firstThread.registers?["x6"] == "0x0000000000000034")
        #expect(firstThread.registers?["x28"] == "0x0000000000000000")

        #expect(crashLog.capturedMemory?["0x000000016f297108"] == "389906fb0100000048c075f901000000")

        #expect(firstThread.frames.count == 6)

        let firstFrame = try #require(firstThread.frames.first)
        #expect(firstFrame.kind == .programCounter)
        #expect(firstFrame.address == "0x000000018db5f308")
        #expect(firstFrame.symbol == nil)
        #expect(firstFrame.count == nil)
        #expect(firstFrame.offset == nil)

        let crashingThread = crashLog.threads[6]

        #expect(crashingThread.crashed)
        #expect(crashingThread.registers?["x0"] == "0x0000000000000001")
        #expect(crashingThread.registers?["x8"] == "0x000000000000002a")
        #expect(crashingThread.registers?["x6"] == "0x000000000000000a")
        #expect(crashingThread.registers?["x28"] == "0x0000000000000000")

    }

    @Test func simplePlainTextWintelRead() async throws {
        let reader = PlainCrashLogReader<HostContext.Address>(plainCrashLog: wintelCrashLog)

        let crashLog = try #require(reader.parse(), "unable to parse plain crash log")

        #expect(crashLog.description == "Access violation at 0x0000000000000006")
        #expect(crashLog.platform == "x86_64 Windows 11.0 build 26200")

        #expect(crashLog.architecture == "x86_64")
        #expect(crashLog.backtraceTime == 0.03)
        #expect(crashLog.omittedImages == 23)

        #expect(crashLog.images?.count == 3)

        let firstImage = try #require(crashLog.images?.first)
        #expect(firstImage.baseAddress == "0x00007ff715ac0000")
        #expect(firstImage.endOfText == "0x00007ff715ac2600")
        #expect(firstImage.name == "crashMe.exe")
        #expect(firstImage.buildId == "8a15f8d333aeebaa4c4c44205044422e01000000")
        #expect(firstImage.path == #"S:\swift-symbolicate\.build\debug\crashMe.exe"#)

        #expect(crashLog.threads.count == 1)

        let firstThread = try #require(crashLog.threads.first)

        #expect(firstThread.crashed)
        #expect(firstThread.registers?["rax"] == "0x0000000000000006")
        #expect(firstThread.registers?["rbx"] == "0x000001b7f2e32f10")
        #expect(firstThread.registers?["rsp"] == "0x000000a6267df740")
        #expect(firstThread.registers?["rbp"] == "0x0000000000000000")

        // extra intel registers
        #expect(firstThread.registers?["rflags"] == "0x0000000000010206")
        #expect(firstThread.registers?["cs"] == "0x0033")
        #expect(firstThread.registers?["fs"] == "0x0053")
        #expect(firstThread.registers?["gs"] == "0x002b")

        #expect(crashLog.capturedMemory?["0x000001b7f2e39bd0"] == "6033e3f2b7010000402fe3f2b7010000")

        #expect(firstThread.frames.count == 10)

        let firstFrame = try #require(firstThread.frames.first)
        #expect(firstFrame.kind == .programCounter)
        #expect(firstFrame.address == "0x00007ff715ac1464")
        #expect(firstFrame.symbol == nil)
        #expect(firstFrame.count == nil)
        #expect(firstFrame.offset == nil)

        let secondFrame = try #require(firstThread.frames.dropFirst().first)
        #expect(secondFrame.kind == .returnAddress)
        #expect(secondFrame.address == "0x00007ff715ac12d9")
        #expect(secondFrame.symbol == nil)
        #expect(secondFrame.count == nil)
        #expect(secondFrame.offset == nil)
    }
}

struct JsonCrashLog {
    @Test func simpleJsonRead() async throws {
        let jsonData = try #require(sampleJsonTrace.data(using: .utf8))
        let crashLog = try HostCrashLog.loadFromJSON(jsonData)

        #expect(crashLog.kind == "crashReport")
        #expect(crashLog.description == "Bad pointer dereference")
        #expect(crashLog.faultAddress == "0x000000000deadbee")
        #expect(crashLog.platform == "macOS 26.0.1 (25A362)")
        #expect(crashLog.architecture == "arm64")

        let firstThread = try #require(crashLog.threads.first)

        #expect(firstThread.crashed == true)
        
        let registers = try #require(firstThread.registers)

        #expect(registers["x0"] == "0x0000000000000001")

        let firstFrame = try #require(firstThread.frames.first)

        #expect(firstFrame.kind == .programCounter)
        #expect(firstFrame.address == "0x0000000102578a1c")
        #expect(firstFrame.symbol == "_main")

        let secondFrame = try #require(firstThread.frames.dropFirst().first)

        #expect(secondFrame.kind == .returnAddress)
        #expect(secondFrame.address == "0x0000000185e65d54")
        #expect(secondFrame.symbol == "start")
    }

    @Test func simpleJsonRoundtrip() async throws {
        let jsonData = try #require(exampleReconstructableJSON.data(using: .utf8))
        let crashLog = try HostCrashLog.loadFromJSON(jsonData)
        let options: BacktraceJSONFormatterOptions = [.images, .mentionedImages]
            
        let recreatedCrashLog = try #require(exportAsJson(crashLog: crashLog, options: options))

        #expect(String(data: recreatedCrashLog, encoding: .utf8) == exampleReconstructableJSON)
    }

    @Test func symbolicateJsonBacktrace() async throws {
        let jsonData = try #require(unsymbolicatedCrashLog.data(using: .utf8))
        let crashLog = try HostCrashLog.loadFromJSON(jsonData)

        let firstThread: CrashLog<HostContext.Address>.Thread = try #require(crashLog.threads.first)

        #expect(firstThread.crashed == true)

        let registers = try #require(firstThread.registers)

        #expect(registers["x0"] == "0x0000000000000001")

        #expect(firstThread.frames.count == 3)

        let firstFrame = try #require(firstThread.frames.first)

        #expect(firstFrame.kind == .programCounter)
        #expect(firstFrame.address == "0x000000010455ca1c")
        #expect(firstFrame.symbol == nil) // we have an unsymbolicated thread for now
        #expect(firstFrame.offset == nil)
        #expect(firstFrame.description == nil)
        #expect(firstFrame.image == nil)
        #expect(firstFrame.sourceLocation == nil)

        let secondFrame = try #require(firstThread.frames.dropFirst().first)

        #expect(secondFrame.kind == .returnAddress)
        #expect(secondFrame.address == "0x000000019d1b9d54")
        #expect(secondFrame.symbol == nil) // we have an unsymbolicated thread for now
        #expect(secondFrame.offset == nil)
        #expect(secondFrame.description == nil)
        #expect(secondFrame.image == nil)
        #expect(secondFrame.sourceLocation == nil)

        let thirdFrame = try #require(firstThread.frames.dropFirst(2).first)

        #expect(thirdFrame.kind == .truncated)
        #expect(thirdFrame.address == nil)
        #expect(thirdFrame.symbol == nil) // we have an unsymbolicated thread for now
        #expect(thirdFrame.offset == nil)
        #expect(thirdFrame.description == nil)
        #expect(thirdFrame.image == nil)
        #expect(thirdFrame.sourceLocation == nil)
    }
}

struct StreamScanning: UsingLogStream {
    @Test func recognizerTests() async throws {
        // a signature less than two characters/pieces should not be allowed
        await #expect(processExitsWith: .failure) {
            let _ = Recognizer(.init("."))
        }

        let jsonRecognizer = Recognizer(.init("{ \"timestamp\": \""), .init(skipTo: "\"", max: 100)!, .init("\", \"kind\": \"crashReport\""))
        #expect(checkRecognized(recognizer: jsonRecognizer, text: recognizerJsonTest) == .complete) // basic check
        #expect(checkRecognized(recognizer: jsonRecognizer, text: recognizerJsonTest) == .complete) // check it's reusable
        #expect(checkRecognized(recognizer: jsonRecognizer, text: unprettifiedUnsymbolicatedJsonTraceForRecognizer) == .complete) // more realistic check
        #expect(checkRecognized(recognizer: jsonRecognizer, text: recognizerJsonTest2) == .failed) // failure check
        #expect(checkRecognized(recognizer: jsonRecognizer, text: recognizerJsonTest3) == .noMatch) // passthrough check

        // edge cases...
        #expect(checkRecognized(recognizer: jsonRecognizer, text: recognizerEdgeCase1) == .complete)
        #expect(checkRecognized(recognizer: jsonRecognizer, text: recognizerEdgeCase2) == .complete)

        let jsonRecognizerTooShortSkip = Recognizer(.init("{ \"timestamp\": \""), .init(skipTo: "\"", max: 3)!, .init("\", \"kind\": \"crashReport\""))
        #expect(checkRecognized(recognizer: jsonRecognizerTooShortSkip, text: recognizerJsonTest) == .failed) // basic check

        let jsonEndRecognizer = Recognizer(.init("\"backtraceTime\":"), .init(skipTo: "}", max: 100)!, .init("}"))
        #expect(checkRecognized(recognizer: jsonEndRecognizer, text: recognizerJsonEndTest) == .complete) // basic check

        let plainRecognizer = Recognizer(.init(" Program crashed: "))
        #expect(checkRecognized(recognizer: plainRecognizer, text: plainTextCrashLog) == .complete) // basic check

        let plainEndRecognizer = Recognizer(.init("Backtrace took "), .init(skipTo: "s", max: 100)!, .init("s"))
        #expect(checkRecognized(recognizer: plainEndRecognizer, text: plainTextCrashLogEnd) == .complete) // basic check
        #expect(checkRecognized(recognizer: plainEndRecognizer, text: plainTextCrashLogEnd) == .complete) // basic check
        #expect(checkRecognized(recognizer: plainEndRecognizer, text: plainTextCrashLog) == .complete) // basic check

    }

    @Test func testJsonCrashDumpCorrupted() async throws {
        // pass through unchanged
        let result = try await testScan(sampleData: jsonCrashLogCorruptedWithStartFinish) { crashDump in
            try symbolicateJsonCrashLog(data: crashDump)
        }

        #expect(jsonCrashLogCorruptedWithStartFinish == result)
    }

    @Test func testJsonCrashDumpCorruptedWithFalseStart() async throws {
        // pass through unchanged
        let result = try await testScan(sampleData: jsonCrashLogCorruptedWithFalseStart) { crashDump in
            #expect(true == false, "this path should not be run")
            return Data()
        }

        #expect(jsonCrashLogCorruptedWithFalseStart == result)
    }

    @Test func testJsonCrashDumpWithoutSymbolication() async throws {
        // pass through unchanged
        let result = try await testScan(sampleData: unprettifiedUnsymbolicatedJsonTraceForRecognizer) { crashDump in
            return crashDump
        }

        #expect(unprettifiedUnsymbolicatedJsonTraceForRecognizer == result)
    }
}

#endif

#if TestSymbolicating

@Suite
struct Symbolication: UsingLogStream {
    @Test func symbolicateJsonBacktrace() async throws {
        let unsymbolicatedJsonCrashLogText = try await getCrashLog(isJson: true, isSymbolicated: false)

        let jsonData = try #require(unsymbolicatedJsonCrashLogText.data(using: .utf8))
        let crashLog = try HostCrashLog.loadFromJSON(jsonData)

        let firstThread: CrashLog<HostContext.Address>.Thread = try #require(crashLog.threads.first)

        #expect(firstThread.crashed == true)

        let registers = try #require(firstThread.registers)

        #expect(registers["x0"] == "0x0000000000000001")

        #expect(firstThread.frames.count > 5)

        let firstFrame = try #require(firstThread.frames.first)

        #expect(firstFrame.kind == .programCounter)
        #expect(firstFrame.symbol == nil) // we have an unsymbolicated thread for now
        #expect(firstFrame.offset == nil)
        #expect(firstFrame.description == nil)
        #expect(firstFrame.image == nil)
        #expect(firstFrame.sourceLocation == nil)

        let secondFrame = try #require(firstThread.frames.dropFirst().first)

        #expect(secondFrame.kind == .returnAddress)
        #expect(secondFrame.symbol == nil) // we have an unsymbolicated thread for now
        #expect(secondFrame.offset == nil)
        #expect(secondFrame.description == nil)
        #expect(secondFrame.image == nil)
        #expect(secondFrame.sourceLocation == nil)

        let lastFrame = try #require(firstThread.frames.last)

        #expect(lastFrame.kind == .returnAddress)
        #expect(lastFrame.symbol == nil) // we have an unsymbolicated thread for now
        #expect(lastFrame.offset == nil)
        #expect(lastFrame.description == nil)
        #expect(lastFrame.image == nil)
        #expect(lastFrame.sourceLocation == nil)

        // now symbolicate...
        var crashedThread = firstThread
        let images = crashLog.imageMap()

        #if os(Linux)
        #expect(images?.platform.hasPrefix("Linux") == true)
        #elseif os(macOS)
        #expect(images?.platform.hasPrefix("macOS") == true)
        #endif
        #expect(images?.wordSize == .sixtyFourBit)

        let firstImg = try #require(images?.images.first)
        #expect(firstImg.name == "crashMe")
        #expect(firstImg.path?.hasSuffix("crashMe") == true)
        #expect(hex(firstImg.uniqueID ?? []) != "")
        let imageBaseAddress = firstImg.baseAddress
        let imageEndAddress = firstImg.endOfText
        #expect(imageBaseAddress != 0)
        #expect(imageEndAddress != 0)

        let crashedThreadBacktrace = crashedThread.backtrace(architecture: crashLog.architecture, images: images)

        let crashedThreadSymbolicatedBacktrace = try #require(
            crashedThreadBacktrace.symbolicated(with: images, options: [.showInlineFrames,.showSourceLocations])
        )

        #expect(crashedThreadSymbolicatedBacktrace.images.first?.name == "crashMe")
        #expect(crashedThreadSymbolicatedBacktrace.images.first?.baseAddress.description.hasPrefix("0x") == true)

        // TODO: could probably change this to a map on the original threads
        // and thus update all threads, possibly add a mutating method to CrashLog
        // to do it for all threads simply
        crashedThread.updateWithBacktrace(symbolicatedBacktrace: crashedThreadSymbolicatedBacktrace)

        #expect(crashedThread.frames.count > 5)

        let firstSymbolicatedFrame = try #require(crashedThread.frames.first)

        #expect(firstSymbolicatedFrame.kind == .programCounter)
        #expect(firstSymbolicatedFrame.address != "")
        #if os(macOS)
        #expect(firstSymbolicatedFrame.symbol == "_$s7crashMe6level4yyF")
        #elseif os(Linux)
        #expect(firstSymbolicatedFrame.symbol == "$s7crashMe6level4yyF")
        #endif
        #expect((firstSymbolicatedFrame.offset ?? 0) > 0)
        #expect(firstSymbolicatedFrame.image == "crashMe")
        #expect(firstSymbolicatedFrame.sourceLocation?.file.hasSuffix("crashMe.swift") == true)
        #expect(firstSymbolicatedFrame.sourceLocation?.line == 16)
        #expect(firstSymbolicatedFrame.sourceLocation?.column == 15)


        let secondSymbolicatedFrame = try #require(crashedThread.frames.dropFirst().first)

        #expect(secondSymbolicatedFrame.kind == .returnAddress)
        #expect(secondSymbolicatedFrame.address != "")
        #if os(macOS)
        #expect(firstSymbolicatedFrame.symbol == "_$s7crashMe6level4yyF")
        #elseif os(Linux)
        #expect(firstSymbolicatedFrame.symbol == "$s7crashMe6level4yyF")
        #endif
        #expect(secondSymbolicatedFrame.offset ?? 0 > 0)
        #expect(secondSymbolicatedFrame.image == "crashMe")
        #expect(secondSymbolicatedFrame.sourceLocation?.file.hasSuffix("crashMe.swift") == true)
        #expect(secondSymbolicatedFrame.sourceLocation?.line == 10)
        #expect(secondSymbolicatedFrame.sourceLocation?.column == 3)

        let lastSymbolicatedFrame = try #require(crashedThread.frames.last)

        #expect(lastSymbolicatedFrame.kind == .returnAddress)
        #if os(macOS)
        #expect(lastSymbolicatedFrame.symbol == "start")
        #expect(lastSymbolicatedFrame.image == "dyld")
        #elseif os(Linux)
        #expect(lastSymbolicatedFrame.symbol == "<unknown>")
        #expect(lastSymbolicatedFrame.offset == 0)
        #expect(lastSymbolicatedFrame.description == "[1] libc.so.6 <unknown>")
        #expect(lastSymbolicatedFrame.image == "libc.so.6")
        #endif
        #expect(lastSymbolicatedFrame.sourceLocation == nil)
    }

    @available(macOS 15.0, *)
    @Test func symbolicatePlainTextBacktrace() async throws {
        let unsymbolicatedPlainCrashLog = try await getCrashLog(isJson: false, isSymbolicated: false)

        unsymbolicatedPlainCrashLog.expect {
            "Program crashed: Bad pointer dereference at 0x0000000000000006"
            /Platform: .*/
            /Thread 0 +"?[^ ]*"? ?crashed:/
            /0 +0x[0-9a-f]+/
            /1 +\[ra\] +0x[0-9a-f]+/
            "Registers:"
            /x0 0x[0-9a-f]+/
            /Images \([0-9]+ omitted\):/
            /[0-9a-f]+ +crashMe +.*\/crashMe/
            #if os(macOS)
            /[0-9a-f]+ +dyld +.*\/dyld/
            #endif
            /Backtrace took [0-9.]+s/
        }

        let reader = PlainCrashLogReader<HostContext.Address>(plainCrashLog: unsymbolicatedPlainCrashLog)
        var crashLog = try #require(reader.parse(), "unable to parse plain crash log")
        let images = crashLog.imageMap()
        var crashedThread: CrashLog<HostContext.Address>.Thread = try #require(crashLog.threads.first)
        let crashedThreadBacktrace = crashedThread.backtrace(architecture: crashLog.architecture, images: images)
        let crashedThreadSymbolicatedBacktrace = try #require(crashedThreadBacktrace.symbolicated(with: images))
        crashedThread.updateWithBacktrace(symbolicatedBacktrace: crashedThreadSymbolicatedBacktrace)
        crashLog.threads = [crashedThread]
        let plainCrashLogWriter = PlainCrashLogWriter<HostContext.Address>(
            crashLog,
            options: BacktraceFormattingOptions()
                .skipSystemFrames(false)
                .sanitizePaths(false),
            lineSeparator: "\n",
            width: .auto,
            haveSymbolicatedThreads: true)
        let symbolicatedPlainTextLog = plainCrashLogWriter.write()

        symbolicatedPlainTextLog.expect {
            "Program crashed: Bad pointer dereference at 0x0000000000000006"
            /Platform: .*/
            /Thread 0 +"?[^ ]*"? ?crashed:/
            /0 +0x[0-9a-f]+ level4.*crashMe.swift:16:15/
            /1 +\[ra\] +0x[0-9a-f]+ level3.*crashMe.swift:10:3/
            /2 +\[ra\] +0x[0-9a-f]+ level2.*crashMe.swift:6:3/
            /3 +\[ra\] +0x[0-9a-f]+ level1.*crashMe.swift:2:3/
            /4 +\[ra\] +0x[0-9a-f]+ static Crash.main.*crashMe.swift:22:5/
            /5 +\[ra\] \[system\] +0x[0-9a-f]+ static Crash..main.*compiler-generated/
            /6 +\[ra\] \[system\] +0x[0-9a-f]+ .*crashMe_main.*crashMe.*crashMe.swift/
            "Registers:"
            /x0 0x[0-9a-f]+/
            /Images \([0-9]+ omitted\):/
            /[0-9a-f]+ +crashMe +.*\/crashMe/
            #if os(macOS)
            /[0-9a-f]+ +dyld +.*\/dyld/
            #endif
            /Backtrace took [0-9.]+s/
        }
    }
}

struct StreamSymbolication: UsingLogStream {
    @available(macOS 15.0, *)
    @Test func testJsonCrashDumpWithSymbolication() async throws {
        let unprettifiedUnsymbolicatedJsonTrace = try await getCrashLog(isJson: true, isSymbolicated: false)

        #expect(!unprettifiedUnsymbolicatedJsonTrace.contains("s7crashMe6level4yyF"))

        let result = try #require(try await testScan(sampleData: unprettifiedUnsymbolicatedJsonTrace) { crashDump in
            try symbolicateJsonCrashLog(data: crashDump, options: [.mentionedImages, .images])
        })

        result.expect(separator: "{") {
            /"address".*symbol.*s7crashMe6level4yyF/
        }
    }

    @available(macOS 15.0, *)
    @Test func testJsonCrashDumpWithSymbolicationIncludingExtraText() async throws {
        let unprettifiedUnsymbolicatedJsonTrace = try await getCrashLog(isJson: true, isSymbolicated: false)

        let unprettifiedUnsymbolicatedJsonTraceWithBeforeAndAfter = """
        Some Text before that should be unchanged...
        \(unprettifiedUnsymbolicatedJsonTrace)
        Some text after the crash dump that should also be untouched.
        """

        unprettifiedUnsymbolicatedJsonTraceWithBeforeAndAfter.expect(separator: "{") {
            "Some Text before that should be unchanged..."
            /"address": "0x[0-9a-f]+"/
            "Some text after the crash dump that should also be untouched."
        }

        // make sure the crash log is not yet symbolicated
        #expect(!unprettifiedUnsymbolicatedJsonTraceWithBeforeAndAfter.contains("main"))

        let result = try #require(try await testScan(sampleData: unprettifiedUnsymbolicatedJsonTraceWithBeforeAndAfter) { crashDump in
            try symbolicateJsonCrashLog(data: crashDump)
        })

        // check there are some symbols
        result.expect(separator: "{") {
            "Some Text before that should be unchanged..."
            /"kind": "programCounter".*"address": "0x[0-9a-f]+".*symbol.*s7crashMe6level4yyF/
            "Some text after the crash dump that should also be untouched."
        }
    }

    @available(macOS 15.0, *)
    @Test func testJsonCrashDumpWithSymbolicationMultiThread() async throws {
        let jsonCrashLog = try await getCrashLog(isJson: true, isSymbolicated: false, isMultiThreaded: true)

        let jsonMultiThread = """
Text before log...
\(jsonCrashLog)
...text after log.
"""

        jsonMultiThread.expect(separator: "{") {
            "Text before log..."
            /"address".*0x[0-9a-f]+/
            "...text after log."
        }

        // make sure the crash log is not yet symbolicated
        #expect(!jsonMultiThread.contains("main"))
        #expect(!jsonMultiThread.contains("backtraces will be missing information"), "The backtrace seems incomplete")

        let result = try #require(try await testScan(sampleData: jsonMultiThread) { crashDump in
            try symbolicateJsonCrashLog(
                data: crashDump,
                options: [.demangle, .images, .allThreads])
        })

        #if os(Linux)
        // due to rdar://165040681 we can only check for symbols on one thread
        result.expect(separator: "{") {
            "Text before log..."
            "\"crashed\": true"
            /"address".*0x[0-9a-f].*symbol.*reallyCrash/
            "...text after log."
        }

        result.expect(separator: "{") {
            "Text before log..."
            /"address".*0x[0-9a-f].*symbol.*main/
            "\"crashed\": true"
            /"address".*0x[0-9a-f].*symbol.*reallyCrash/
            "...text after log."
        }

        #elseif os(macOS)
        // check there are some symbols for more than one thread
        result.expect(separator: "{") {
            "Text before log..."
            /"address".*0x[0-9a-f].*symbol.*main/
            "\"crashed\": true"
            /"address".*0x[0-9a-f].*symbol.*reallyCrash/
            "...text after log."
        }
        #endif
    }

    @available(macOS 15.0, *)
    @Test func testPlainTextCrashDumpWithSymbolication() async throws {
        let plainCrashLog = try await getCrashLog(isJson: false, isSymbolicated: false)

        // this is a more realistic test of streaming with some output before a crash
        // and possible shell output afterwards
        let result = try #require(
            try await testScan(sampleData:
"""
Hello, World!

\(plainCrashLog)

zsh: segmentation fault  ./crashMe
"""
            )
            { crashDump in
                try symbolicatePlainTextCrashLog(data: crashDump)
            }
        )

        result.expect {
            "Hello, World!"
            "Signal 11: Backtracing from 0x"
            /[0-9a-f]+ .*main.*crashMe.*crashMe.swift/
            "zsh: segmentation fault  ./crashMe"
        }
    }

    @available(macOS 15.0, *)
    @Test func testPlainTextCrashDumpWithSymbolicationMulitpleThreads() async throws {
        let plainCrashLogMultithreaded = try await getCrashLog(isJson: false,
                                                                isSymbolicated: false,
                                                                isMultiThreaded: true)

        #expect(!plainCrashLogMultithreaded.contains("main"))
        #expect(!plainCrashLogMultithreaded.contains("_crashMeMultithreaded_main"))
        #expect(!plainCrashLogMultithreaded.contains("backtraces will be missing information"), "The backtrace seems incomplete")

        let result = try #require(
            try await testScan(sampleData:
                plainCrashLogMultithreaded
            )
            { crashDump in
                try symbolicatePlainTextCrashLog(data: crashDump)
            }
        )

        #if os(Linux)
        result.expect {
            "Signal 11: Backtracing from 0x"
            /Thread [0-9]+ crashed:/
            /0x[0-9a-f]+ .* static MultithreadedCrash.spawnThread.*crashMeMultithreaded.*crashMeMultithreaded.swift/
        }

        result.expect {
            "Signal 11: Backtracing from 0x"
            /Thread 0.*:/
            /0x[0-9a-f]+ static MultithreadedCrash.main.*crashMeMultithreaded.*crashMeMultithreaded.swift/
            /Thread [0-9]+:/
            /0x[0-9a-f]+ .* static MultithreadedCrash.spawnThread.*crashMeMultithreaded.*crashMeMultithreaded.swift/
            /Thread [0-9]+:/
            /0x[0-9a-f]+ .* static MultithreadedCrash.spawnThread.*crashMeMultithreaded.*crashMeMultithreaded.swift/
        }
        #elseif os(macOS)
        result.expect {
            "Signal 11: Backtracing from 0x"
            /Thread 0:/
            /0x[0-9a-f]+ static MultithreadedCrash.main.*crashMeMultithreaded.*crashMeMultithreaded.swift/
            /Thread [0-9]+:/
            /0x[0-9a-f]+ .* static MultithreadedCrash.spawnThread.*crashMeMultithreaded.*crashMeMultithreaded.swift/
            /0x[0-9a-f]+ .*pthread_start/
            /Thread [0-9]+:/
            /0x[0-9a-f]+ .* static MultithreadedCrash.spawnThread.*crashMeMultithreaded.*crashMeMultithreaded.swift/
            /0x[0-9a-f]+ .*pthread_start/
        }
        #endif
    }
}

struct EdgeCasesAndFuzzing: UsingLogStream {
    @Test func testLoremIpsum() async throws {
        // pass through unchanged
        let result = try await testScan(sampleData: loremIpsum) { crashDump in
            #expect(true == false, "this path should not be run")
            return Data()
        }

        #expect(result == loremIpsum)
    }

    @available(macOS 15.0, *)
    @Test func testJsonCrashDumpWithSymbolicationLargeBuffer() async throws {
        let sampleJsonCrash = try await getCrashLog(isJson: true, isSymbolicated: false)

        #expect(!sampleJsonCrash.contains("s7crashMe6level4yyF"))

        let unsymbolicatedJsonLargeBuffer = """
Some Text before that should be unchanged...
\(sampleJsonCrash)
Some text after the crash dump that should also be untouched.

Some Text before that should be unchanged...
\(sampleJsonCrash)
Some text after the crash dump that should also be untouched.

Some Text before that should be unchanged...
\(sampleJsonCrash)
Some text after the crash dump that should also be untouched.

Some Text before that should be unchanged...
\(sampleJsonCrash)
Some text after the crash dump that should also be untouched.

Some Text before that should be unchanged...
\(sampleJsonCrash)
Some text after the crash dump that should also be untouched.
"""

        // pass through unchanged
        let result = try #require(try await testScan(sampleData: unsymbolicatedJsonLargeBuffer) { crashDump in
            try symbolicateJsonCrashLog(data: crashDump, options: [.images, .mentionedImages])
        })

        result.expect {
            "Some Text before that should be unchanged..."
            /0x[0-9a-f]+.*symbol.*s7crashMe6level4yyF/
            "Some text after the crash dump that should also be untouched."
            "Some Text before that should be unchanged..."
            /0x[0-9a-f]+.*symbol.*s7crashMe6level4yyF/
            "Some text after the crash dump that should also be untouched."
            "Some Text before that should be unchanged..."
            /0x[0-9a-f]+.*symbol.*s7crashMe6level4yyF/
            "Some text after the crash dump that should also be untouched."
            "Some Text before that should be unchanged..."
            /0x[0-9a-f]+.*symbol.*s7crashMe6level4yyF/
            "Some text after the crash dump that should also be untouched."
            "Some Text before that should be unchanged..."
            /0x[0-9a-f]+.*symbol.*s7crashMe6level4yyF/
            "Some text after the crash dump that should also be untouched."
        }
    }
}

#endif
