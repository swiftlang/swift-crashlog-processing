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
@_spi(Utils) import Runtime

/// Locates symbol and executable files on the local filesystem and from remote symbol servers.
///
/// Extends `DefaultSymbolLocator` from the `Runtime` module with support for
/// additional search paths, ELF `.build-id` directory layouts, PE/COFF `.pdb` files,
/// and downloading symbols from configured ``SymbolServer`` instances.
@_spi(SymbolLocation)
public final class OfflineSymbolLocator: DefaultSymbolLocator, FetchingSymbolLocator {
  let alternativePaths: [String]
  let pathSeparator: String
  let symbolServers: [SymbolServer]
  let cacheUpdatePolicy: CacheUpdatePolicy
  let debug: Bool

  /// Creates an offline symbol locator.
  ///
  /// - Parameters:
  ///   - alternativePaths: Directories to search for images. The first path is also used
  ///     as the cache directory for symbols downloaded from remote servers.
  ///   - pathSeparator: The path separator character used in the crash log's image paths
  ///     (e.g. `"/"` for Unix, `"\\"` for Windows).
  ///   - symbolServers: Remote symbol servers to try, in order, when local lookup fails.
  ///   - cacheUpdatePolicy: Controls when cached files are refreshed from the server.
  ///   - debug: If `true`, prints progress messages for symbol fetch operations.
  @_spi(SymbolLocation)
  public init(
    alternativePaths: [String],
    pathSeparator: String,
    symbolServers: [SymbolServer],
    cacheUpdatePolicy: CacheUpdatePolicy = .never,
    debug: Bool = false
  ) {

    self.alternativePaths = alternativePaths
    self.pathSeparator = pathSeparator
    self.symbolServers = symbolServers
    self.cacheUpdatePolicy = cacheUpdatePolicy
    self.debug = debug

    super.init()
  }

  /// Finds the path to the binary for the given image.
  public override func find(image: any Image) -> String? {
    return super.find(image: image)
  }

  /// Finds a symbol source for the given image and format.
  public override func findSymbols(
    for image: any Image,
    format: ImageFormat
  ) -> (any SymbolSource)? {
    return super.findSymbols(for: image, format: format)
  }

  override public func findImagePaths(image: any Image) -> [String] {
    guard let imagePath = image.path else {
      return []
    }

    // here we take the last path component using the path separator
    // appropriate to the platform for the crash log we are reading
    guard let filename = imagePath.split(separator: pathSeparator).last else {
      return []
    }

    var images = alternativePaths.map {
      // note here we use the current *platform* path separator
      // not the one used in the crashlog
      // because it has to be used to open files on this platform
      ($0 as NSString).appendingPathComponent(String(filename))
    }

    // always attempt the original image path from the crash log first,
    // in case we are running on the same machine the crash log was on
    // we might want to override this behaviour with a flag one day
    images.insert(imagePath, at: 0)

    return images
  }

  override public func findPeCoffSymbolPaths(image: any Image) -> [String] {
    let imageFilePaths = findImagePaths(image: image)

    let pdbPaths = imageFilePaths.map {
      (($0 as NSString).deletingPathExtension as NSString)
        .appendingPathExtension("pdb")!
    }

    // symsrv-style paths: <alternativePath>/<pdbName>/<symsrvId>/<pdbName>
    var symsrvPaths: [String] = []
    if let uuid = image.uuid {
      let symsrvId = WindowsSymbolServer.transformToSymsrvId(from: hex(uuid))
      if let imagePath = image.path,
        let filename = imagePath.split(separator: pathSeparator).last
      {
        let pdbName = (String(filename) as NSString).deletingPathExtension + ".pdb"
        let subPath = (pdbName as NSString)
          .appendingPathComponent(symsrvId)
        let fullSubPath = (subPath as NSString)
          .appendingPathComponent(pdbName)

        symsrvPaths = alternativePaths.map {
          ($0 as NSString).appendingPathComponent(fullSubPath)
        }
      }
    }

    return imageFilePaths + pdbPaths + symsrvPaths
  }

  override public func findElfSymbolPaths(image: any Image) -> [String] {
    let imageFilePaths = findImagePaths(image: image)

    if alternativePaths.count == 0 {
      return imageFilePaths
    }

    // we must have at least one "alternative path"
    // usually because swift-symbolicate is being run on a different
    // machine from where the crash occurred

    guard let uuid = image.uuid else { return [] }

    let subPath = (".build-id" as NSString)
      .appendingPathComponent(elfDebugSymSubPath(for: uuid))

    let debugImagePaths = alternativePaths.map {
      // note here we use the current *platform* path separator
      // not the one used in the crashlog
      // because it has to be used to open files on this platform
      ($0 as NSString).appendingPathComponent(subPath)
    }

    // we will search for the ELF file in each alternative path
    // and then we will search the .build-id/XX sub-path of each alternative path
    // for a file called YYYYYYYYYY.debug with the symbols in it

    let symbolPaths = imageFilePaths + debugImagePaths

    #if DebuggingSymbolicator
      print("searching symbol paths: \(symbolPaths)")
    #endif

    return symbolPaths

    // note: when downloading symbols from a remote server, we will store them in the first
    // directory of alternativePaths under .build-id so they go .build-id/XX/YYYYYYYY
    //
    // note that if alternativePaths is not specified, we cannot cache remote symbols
    // because we don't know where to put them
  }
}
