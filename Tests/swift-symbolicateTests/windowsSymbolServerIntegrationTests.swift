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
@_spi(SymbolLocation) import SwiftSymbolicate

#if TestIntegrations

struct WindowsSymbolServerIntegrationTests {
    static let serverPort = 19876
    static let serverURL = "http://[::1]:\(serverPort)"

    struct ServerProcess {
        let process: Process
        let symbolsDir: String

        func stop() {
            process.terminate()
            process.waitUntilExit()
        }
    }

    static func findPythonServer() -> String {
        // Walk up from the test binary to find the project root
        var dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return dir.appendingPathComponent("demo-windows-symbol-server.py").path
    }

    static func startServer(symbolsDir: String) throws -> ServerProcess {
        let scriptPath = findPythonServer()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", scriptPath, symbolsDir, "--port", "\(serverPort)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()

        // Give the server a moment to bind
        Thread.sleep(forTimeInterval: 0.5)

        return ServerProcess(process: process, symbolsDir: symbolsDir)
    }

    static func createSymbolStore() throws -> String {
        let tempDir = NSTemporaryDirectory() + "symsrv-test-\(ProcessInfo.processInfo.processIdentifier)"
        let pdbDir = "\(tempDir)/hello.pdb/TESTINDEX123"
        try FileManager.default.createDirectory(atPath: pdbDir, withIntermediateDirectories: true)
        let pdbPath = "\(pdbDir)/hello.pdb"
        try Data("FAKE-PDB-CONTENT".utf8).write(to: URL(fileURLWithPath: pdbPath))
        return tempDir
    }

    static func createCacheDir() throws -> String {
        let cacheDir = NSTemporaryDirectory() + "symsrv-cache-\(ProcessInfo.processInfo.processIdentifier)"
        try FileManager.default.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
        return cacheDir
    }

    static func cleanup(_ paths: String...) {
        for path in paths {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    @Test func fetchPDBFromServer() async throws {
        let symbolsDir = try Self.createSymbolStore()
        let cacheDir = try Self.createCacheDir()
        defer { Self.cleanup(symbolsDir, cacheDir) }

        let server = try Self.startServer(symbolsDir: symbolsDir)
        defer { server.stop() }

        let downloader = FoundationHTTPDownloader()
        let winServer = WindowsSymbolServer(
            serverAddress: URL(string: Self.serverURL)!,
            httpDownloader: downloader)

        let destPath = (cacheDir as NSString).appendingPathComponent("hello.pdb")

        let result = await winServer.fetch(
            forId: "TESTINDEX123",
            filename: "hello.exe",
            type: .debugSymbols,
            toPath: destPath,
            ifNewerThan: nil)

        #expect(result == true)
        #expect(FileManager.default.fileExists(atPath: destPath))

        let data = try Data(contentsOf: URL(fileURLWithPath: destPath))
        #expect(String(data: data, encoding: .utf8) == "FAKE-PDB-CONTENT")
    }

    @Test func returns404ForMissingPDB() async throws {
        let symbolsDir = try Self.createSymbolStore()
        let cacheDir = try Self.createCacheDir()
        defer { Self.cleanup(symbolsDir, cacheDir) }

        let server = try Self.startServer(symbolsDir: symbolsDir)
        defer { server.stop() }

        let downloader = FoundationHTTPDownloader()
        let winServer = WindowsSymbolServer(
            serverAddress: URL(string: Self.serverURL)!,
            httpDownloader: downloader)

        let destPath = (cacheDir as NSString).appendingPathComponent("missing.pdb")

        let result = await winServer.fetch(
            forId: "NONEXISTENT",
            filename: "missing.exe",
            type: .debugSymbols,
            toPath: destPath,
            ifNewerThan: nil)

        #expect(result == false)
        #expect(!FileManager.default.fileExists(atPath: destPath))
    }

    @Test func respectsIfModifiedSince() async throws {
        let symbolsDir = try Self.createSymbolStore()
        let cacheDir = try Self.createCacheDir()
        defer { Self.cleanup(symbolsDir, cacheDir) }

        let server = try Self.startServer(symbolsDir: symbolsDir)
        defer { server.stop() }

        let downloader = FoundationHTTPDownloader()
        let winServer = WindowsSymbolServer(
            serverAddress: URL(string: Self.serverURL)!,
            httpDownloader: downloader)

        let destPath = (cacheDir as NSString).appendingPathComponent("hello.pdb")

        // First fetch — should succeed with 200
        let result1 = await winServer.fetch(
            forId: "TESTINDEX123",
            filename: "hello.exe",
            type: .debugSymbols,
            toPath: destPath,
            ifNewerThan: nil)
        #expect(result1 == true)

        // Second fetch with a future date — server should return 304
        let futureDate = Date(timeIntervalSinceNow: 86400)
        let result2 = await winServer.fetch(
            forId: "TESTINDEX123",
            filename: "hello.exe",
            type: .debugSymbols,
            toPath: destPath,
            ifNewerThan: futureDate)
        #expect(result2 == true)
    }

    @Test func endToEndWithOfflineSymbolLocator() async throws {
        let symbolsDir = try Self.createSymbolStore()
        let cacheDir = try Self.createCacheDir()
        defer { Self.cleanup(symbolsDir, cacheDir) }

        let server = try Self.startServer(symbolsDir: symbolsDir)
        defer { server.stop() }

        let downloader = FoundationHTTPDownloader()
        let winServer = WindowsSymbolServer(
            serverAddress: URL(string: Self.serverURL)!,
            httpDownloader: downloader)

        let locator = OfflineSymbolLocator(
            alternativePaths: [cacheDir],
            pathSeparator: "\\",
            symbolServers: [winServer])

        await locator.updateSymbolCache(
            imageDetails: [("TESTINDEX123", "hello.exe", .Windows)])

        let cachedPdb = (cacheDir as NSString).appendingPathComponent("hello.pdb")
        #expect(FileManager.default.fileExists(atPath: cachedPdb))
    }
}

#endif
