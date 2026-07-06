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
@_spi(SymbolLocation) import Runtime
@_spi(Formatting) import Runtime

extension OfflineSymbolLocator {
  /// Downloads and caches symbol files for the given images from all configured symbol servers.
  ///
  /// Each server is only consulted if it ``SymbolServer/handles(platform:)`` the image's platform.
  ///
  /// - Parameter imageDetails: An array of `(buildId, executableName, platform)` tuples.
  public func updateSymbolCache(imageDetails: [(String, String, SymbolServerPlatform)]) async {
    for (imageId, imageName, platform) in imageDetails {
      let _ = await updateLocalCacheFromServers(
        imageId: imageId, executableName: imageName, platform: platform)
    }
  }

  /// Tries each configured symbol server in order for a single image, stopping at the first success.
  ///
  /// Servers that don't handle the given platform are skipped.
  ///
  /// - Parameters:
  ///   - imageId: The build ID of the image.
  ///   - executableName: The filename of the executable.
  ///   - platform: The platform the crash log originated from.
  /// - Returns: `true` if any server successfully provided symbols.
  public func updateLocalCacheFromServers(
    imageId: String, executableName: String, platform: SymbolServerPlatform
  ) async -> Bool {
    for symbolServer in symbolServers {
      guard symbolServer.handles(platform: platform) else { continue }
      if await updateLocalCacheFromServer(
        symbolServer, imageId: imageId, executableName: executableName)
      {
        return true
      }
    }
    return false
  }

  func updateLocalCacheFromServer(
    _ symbolServer: SymbolServer, imageId: String, executableName: String
  ) async -> Bool {
    guard !imageId.isEmpty else {
      return false
    }

    guard let cachedFileDirectory = alternativePaths.first else {
      return false
    }

    func getFile(toPath path: String, type: SymbolServerFileType) async -> Bool {
      if debug {
        print("SymbolServer checking cache: \(path), type: \(type), policy: \(cacheUpdatePolicy)")
      }

      switch cacheUpdatePolicy {
      case .never:
        if FileManager.default.fileExists(atPath: path) {
          if debug {
            print("SymbolServer: cached file exists, skipping server (policy: never)")
          }
          return true
        }
        return await symbolServer.fetch(
          forId: imageId, filename: executableName, type: type, toPath: path, ifNewerThan: nil)

      case .newer:
        let lastModified =
          (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        return await symbolServer.fetch(
          forId: imageId, filename: executableName, type: type, toPath: path,
          ifNewerThan: lastModified)

      case .always:
        return await symbolServer.fetch(
          forId: imageId, filename: executableName, type: type, toPath: path, ifNewerThan: nil)
      }
    }

    if symbolServer is WindowsSymbolServer {
      let pdbName = (executableName as NSString).deletingPathExtension + ".pdb"
      let symsrvId = WindowsSymbolServer.transformToSymsrvId(from: imageId)
      let subPath = (pdbName as NSString)
        .appendingPathComponent(symsrvId)
      let fullSubPath = (subPath as NSString)
        .appendingPathComponent(pdbName)
      let cachedPdbFilePath = (cachedFileDirectory as NSString).appendingPathComponent(fullSubPath)
      let debugSymbolFileSuccess = await getFile(toPath: cachedPdbFilePath, type: .debugSymbols)
      return debugSymbolFileSuccess
    } else {
      let subPath = (".build-id" as NSString)
        .appendingPathComponent(elfDebugSymSubPath(for: imageId))

      let cachedDebugSymbolsFilePath = (cachedFileDirectory as NSString).appendingPathComponent(
        subPath)
      let cachedExecutableFilePath = (cachedFileDirectory as NSString).appendingPathComponent(
        executableName)

      let debugSymbolFileSuccess = await getFile(
        toPath: cachedDebugSymbolsFilePath, type: .debugSymbols)
      let executableFileSuccess = await getFile(toPath: cachedExecutableFilePath, type: .executable)

      return debugSymbolFileSuccess || executableFileSuccess
    }
  }
}
