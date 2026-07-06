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

#if TestGeneral

struct WindowsSymbolServerUnitTests {
    class MockHTTPDownloader: HTTPDownloader {
        var lastURL: URL?
        var lastHeaders: [String: String] = [:]
        var lastToPath: String?
        var downloadResult: HTTPDownloadResult = .OK

        func download(
            from url: URL,
            toPath: String,
            headers: [String: String]
        ) async throws -> HTTPDownloadResult {
            lastURL = url
            lastHeaders = headers
            lastToPath = toPath
            return downloadResult
        }
    }

    @Test func handlesOnlyWindows() {
        let server = WindowsSymbolServer(
            serverAddress: URL(string: "http://localhost:8080")!,
            httpDownloader: MockHTTPDownloader())

        #expect(server.handles(platform: .Windows) == true)
        #expect(server.handles(platform: .Linux) == false)
        #expect(server.handles(platform: .Darwin) == false)
    }

    @Test func constructsCorrectURL() async {
        let mock = MockHTTPDownloader()
        let server = WindowsSymbolServer(
            serverAddress: URL(string: "http://symbols.example.com")!,
            httpDownloader: mock)

        let result = await server.fetch(
            forId: "AABBCCDD1",
            filename: "hello.exe",
            type: .debugSymbols,
            toPath: "/tmp/hello.pdb",
            ifNewerThan: nil)

        #expect(result == true)
        #expect(mock.lastURL?.absoluteString == "http://symbols.example.com/hello.pdb/AABBCCDD1/hello.pdb")
        #expect(mock.lastToPath == "/tmp/hello.pdb")
    }

    @Test func sendsSymbolServerUserAgent() async {
        let mock = MockHTTPDownloader()
        let server = WindowsSymbolServer(
            serverAddress: URL(string: "http://localhost:8080")!,
            httpDownloader: mock)

        _ = await server.fetch(
            forId: "INDEX1",
            filename: "test.dll",
            type: .debugSymbols,
            toPath: "/tmp/test.pdb",
            ifNewerThan: nil)

        #expect(mock.lastHeaders["User-Agent"] == "Microsoft-Symbol-Server/10.0.0.0")
    }

    @Test func sendsIfModifiedSinceHeader() async {
        let mock = MockHTTPDownloader()
        let server = WindowsSymbolServer(
            serverAddress: URL(string: "http://localhost:8080")!,
            httpDownloader: mock)

        let date = Date(timeIntervalSince1970: 1_700_000_000)

        _ = await server.fetch(
            forId: "INDEX1",
            filename: "test.dll",
            type: .debugSymbols,
            toPath: "/tmp/test.pdb",
            ifNewerThan: date)

        #expect(mock.lastHeaders["If-Modified-Since"] != nil)
    }

    @Test func rejectsExecutableType() async {
        let mock = MockHTTPDownloader()
        let server = WindowsSymbolServer(
            serverAddress: URL(string: "http://localhost:8080")!,
            httpDownloader: mock)

        let result = await server.fetch(
            forId: "INDEX1",
            filename: "test.dll",
            type: .executable,
            toPath: "/tmp/test.dll",
            ifNewerThan: nil)

        #expect(result == false)
        #expect(mock.lastURL == nil)
    }

    @Test func rejectsNilFilename() async {
        let mock = MockHTTPDownloader()
        let server = WindowsSymbolServer(
            serverAddress: URL(string: "http://localhost:8080")!,
            httpDownloader: mock)

        let result = await server.fetch(
            forId: "INDEX1",
            filename: nil,
            type: .debugSymbols,
            toPath: "/tmp/test.pdb",
            ifNewerThan: nil)

        #expect(result == false)
        #expect(mock.lastURL == nil)
    }

    @Test func rejectsEmptyIndex() async {
        let mock = MockHTTPDownloader()
        let server = WindowsSymbolServer(
            serverAddress: URL(string: "http://localhost:8080")!,
            httpDownloader: mock)

        let result = await server.fetch(
            forId: "",
            filename: "test.dll",
            type: .debugSymbols,
            toPath: "/tmp/test.pdb",
            ifNewerThan: nil)

        #expect(result == false)
        #expect(mock.lastURL == nil)
    }

    @Test func returns304AsSuccess() async {
        let mock = MockHTTPDownloader()
        mock.downloadResult = .NotModified
        let server = WindowsSymbolServer(
            serverAddress: URL(string: "http://localhost:8080")!,
            httpDownloader: mock)

        let result = await server.fetch(
            forId: "INDEX1",
            filename: "test.dll",
            type: .debugSymbols,
            toPath: "/tmp/test.pdb",
            ifNewerThan: nil)

        #expect(result == true)
    }

    @Test func returns404AsFailure() async {
        let mock = MockHTTPDownloader()
        mock.downloadResult = .Error(404)
        let server = WindowsSymbolServer(
            serverAddress: URL(string: "http://localhost:8080")!,
            httpDownloader: mock)

        let result = await server.fetch(
            forId: "INDEX1",
            filename: "test.dll",
            type: .debugSymbols,
            toPath: "/tmp/test.pdb",
            ifNewerThan: nil)

        #expect(result == false)
    }

    @Test func reformatsRawBuildIdToSymsrvFormat() async {
        let mock = MockHTTPDownloader()
        let server = WindowsSymbolServer(
            serverAddress: URL(string: "http://symbols.example.com")!,
            httpDownloader: mock)

        // Raw crash log format: 16 GUID bytes + 4 age bytes (LE), all hex
        // GUID raw: de45b7f7 697a 1bef 7c8be0c4fded10a1
        // Expected: Data1=F7B745DE Data2=7A69 Data3=EF1B Data4=7C8BE0C4FDED10A1 Age=1
        let rawIndex = "de45b7f7697a1bef7c8be0c4fded10a101000000"

        let result = await server.fetch(
            forId: rawIndex,
            filename: "KERNEL32.DLL",
            type: .debugSymbols,
            toPath: "/tmp/KERNEL32.pdb",
            ifNewerThan: nil)

        #expect(result == true)
        #expect(mock.lastURL?.absoluteString == "http://symbols.example.com/KERNEL32.pdb/F7B745DE7A69EF1B7C8BE0C4FDED10A11/KERNEL32.pdb")
    }

    @Test func platformFilteringInUpdateLocalCache() async {
        let mock = MockHTTPDownloader()
        let winServer = WindowsSymbolServer(
            serverAddress: URL(string: "http://localhost:8080")!,
            httpDownloader: mock)
        let gdbServer = SimpleGdbSymbolServer(
            serverAddress: URL(string: "http://localhost:9090")!,
            httpDownloader: mock)

        let locator = OfflineSymbolLocator(
            alternativePaths: [NSTemporaryDirectory()],
            pathSeparator: "\\",
            symbolServers: [gdbServer, winServer])

        // Linux platform should skip WindowsSymbolServer, use SimpleGdbSymbolServer
        _ = await locator.updateLocalCacheFromServers(
            imageId: "abc123",
            executableName: "myapp",
            platform: .Linux)

        #expect(mock.lastURL?.absoluteString.contains("buildid") == true)

        // Reset and try Windows platform — should skip SimpleGdbSymbolServer
        mock.lastURL = nil
        _ = await locator.updateLocalCacheFromServers(
            imageId: "AABB1",
            executableName: "myapp.exe",
            platform: .Windows)

        #expect(mock.lastURL?.absoluteString.contains("myapp.pdb") == true)
    }
}

#endif
