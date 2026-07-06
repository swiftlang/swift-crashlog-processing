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

/// A ``SymbolServer`` that fetches symbols using the Microsoft symsrv protocol.
///
/// Uses the URL pattern `serverAddress/{pdbFilename}/{pdbId}/{pdbFilename}`.
/// Only PDB (debug symbol) fetches are supported.
/// Handles the Windows platform only.
///
/// > Note: Only uncompressed PDB files are supported. CAB-compressed variants
/// > (`.pd_`) and `file.ptr` pointer/redirect files are not currently handled.
public class WindowsSymbolServer: SymbolServer {
  let serverAddress: URL
  let httpDownloader: HTTPDownloader
  let debug: Bool

  /// Creates a new Windows symbol server.
  ///
  /// - Parameters:
  ///   - serverAddress: The base URL of the symbol server.
  ///   - httpDownloader: The HTTP downloader to use for fetching files.
  ///   - debug: If `true`, prints progress messages for symbol fetch operations.
  public init(
    serverAddress: URL,
    httpDownloader: HTTPDownloader,
    debug: Bool = false
  ) {
    self.serverAddress = serverAddress
    self.httpDownloader = httpDownloader
    self.debug = debug
  }

  /// Returns `true` only for the Windows platform.
  public func handles(platform: SymbolServerPlatform) -> Bool {
    platform == .Windows
  }

  /// Fetches a PDB debug symbol file from the Windows symbol server.
  ///
  /// Only debug symbols (PDB) fetches are supported. The server must provide the PDB
  /// as an uncompressed file at the standard path. CAB-compressed variants
  /// (`.pd_`) and `file.ptr` pointer/redirect files are not supported.
  ///
  /// - Parameters:
  ///   - id: The PDB id string for the image (in LLVM PDB id format).
  ///   - filename: The original executable filename (used to derive the PDB name).
  ///   - type: Must be ``SymbolServerFileType/debugSymbols`` for this class.
  ///   - cachedFilePath: The local path to write the downloaded PDB to.
  ///   - cachedFileLastModifiedDate: If non-nil, sent as `If-Modified-Since` header to skip download if not newer
  /// - Returns: `true` if the file was retrieved or there is no newer version of the PDB file.
  public func fetch(
    forId pdbId: String,
    filename: String?,
    type: SymbolServerFileType,
    toPath cachedFilePath: String,
    ifNewerThan cachedFileLastModifiedDate: Date?
  ) async -> Bool {

    guard !pdbId.isEmpty, let filename else { return false }

    // we don't support retrieving .exe or .dll files (yet?)
    // because the ID type we use in crash logs is PDB ids
    guard type == .debugSymbols else { return false }

    if debug {
      print(
        "WindowsSymbolServer: fetching PDB for image \(filename), "
          + "pdb id: \(pdbId), existing PDB file last mod date: \(String(describing: cachedFileLastModifiedDate))"
      )
    }

    let pdbFilename = pdbName(from: filename)
    let symsrvId = Self.transformToSymsrvId(from: pdbId)

    let url =
      serverAddress
      .appendingPathComponent(pdbFilename)
      .appendingPathComponent(symsrvId)
      .appendingPathComponent(pdbFilename)

    if debug {
      print("WindowsSymbolServer: requesting \(url)")
    }

    var headers: [String: String] = [
      "User-Agent": "Microsoft-Symbol-Server/10.0.0.0"
    ]

    if let cachedFileLastModifiedDate {
      let lastModDateString =
        httpDateString(from: cachedFileLastModifiedDate)

      headers["If-Modified-Since"] = lastModDateString

      if debug {
        print("WindowsSymbolServer: sending last mod date: \(lastModDateString)")
      }
    }

    do {
      let result = try await httpDownloader.download(
        from: url,
        toPath: cachedFilePath,
        headers: headers
      )

      if debug {
        print("WindowsSymbolServer: response status code: \(result)")
      }

      return result == .OK || result == .NotModified
    } catch {
      if debug {
        print("WindowsSymbolServer: error: \(error.localizedDescription)")
      }

      return false
    }
  }

  private func pdbName(from executableName: String) -> String {
    (executableName as NSString).deletingPathExtension + ".pdb"
  }

  /// Converts an LLVM style PDB ID (as stored in crash logs) to Microsoft's symsrv PDB id format.
  public static func transformToSymsrvId(from rawBuildId: String) -> String {
    guard rawBuildId.count == 40 else { return rawBuildId }

    let chars: [Character] = Array(rawBuildId)

    func parseByte(_ offset: Int) -> UInt8? {
      let s = String(chars[offset..<offset + 2])
      return UInt8(s, radix: 16)
    }

    // Parse 16 GUID bytes
    var guidBytes = [UInt8]()
    for i in stride(from: 0, to: 32, by: 2) {
      guard let b = parseByte(i) else { return rawBuildId }
      guidBytes.append(b)
    }

    // Parse 4 age bytes (LE)
    var ageBytes = [UInt8]()
    for i in stride(from: 32, to: 40, by: 2) {
      guard let b = parseByte(i) else { return rawBuildId }
      ageBytes.append(b)
    }

    // Data1: 4 bytes LE → uint32
    let data1 =
      UInt32(guidBytes[0])
      | UInt32(guidBytes[1]) << 8
      | UInt32(guidBytes[2]) << 16
      | UInt32(guidBytes[3]) << 24

    // Data2: 2 bytes LE → uint16
    let data2 =
      UInt16(guidBytes[4])
      | UInt16(guidBytes[5]) << 8

    // Data3: 2 bytes LE → uint16
    let data3 =
      UInt16(guidBytes[6])
      | UInt16(guidBytes[7]) << 8

    // Data4: 8 bytes raw
    let data4 = guidBytes[8..<16].map { String(format: "%02X", $0) }.joined()

    // Age: LE uint32
    let age =
      UInt32(ageBytes[0])
      | UInt32(ageBytes[1]) << 8
      | UInt32(ageBytes[2]) << 16
      | UInt32(ageBytes[3]) << 24

    let guidStr = String(format: "%08X%04X%04X%@", data1, data2, data3, data4)
    let ageStr = String(age, radix: 16, uppercase: false)

    return guidStr + ageStr
  }

  // func transformToSymsrvId(from id: String) -> String {
  //     let guid = id.dropLast(8)

  //     // modify the guid to match the symsrv standard

  //     return "\(guid)\(Int(id.suffix(8).prefix(2), radix: 16) ?? 0)".uppercased()
  // }
}
