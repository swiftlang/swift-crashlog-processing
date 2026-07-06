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

/// Scans a directory for PDB files, extracts their GUID+Age index,
/// and copies them into a symsrv-compatible directory layout suitable
/// for serving with demo-windows-symbol-server.py.
///
/// Note: use of this tool is not recommended for production. This tool is
/// only for basic system testing or similar. In production use standard
/// Microsoft tooling/scripts to create and serve hierarchies for symbol server.

import ArgumentParser
import Foundation
@_spi(PDB) import Runtime
@_spi(Utils) import Runtime
import SwiftSymbolicate
import WinSDK

func findPdbFiles(in directory: String) -> [String] {
  var results: [String] = []
  var stack: [String] = [directory]

  while let dir = stack.popLast() {
    let pattern = dir + "\\*"
    var findData = WIN32_FIND_DATAW()

    let hFind = pattern.withCString(encodedAs: UTF16.self) { patternW in
      FindFirstFileW(patternW, &findData)
    }

    guard hFind != INVALID_HANDLE_VALUE else { continue }
    defer { FindClose(hFind) }

    repeat {
      let name = withUnsafePointer(to: findData.cFileName) { ptr in
        ptr.withMemoryRebound(to: UInt16.self, capacity: Int(MAX_PATH)) { buf in
          String(decodingCString: buf, as: UTF16.self)
        }
      }

      if name == "." || name == ".." { continue }

      let fullPath = dir + "\\" + name

      if findData.dwFileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) != 0 {
        stack.append(fullPath)
      } else if name.lowercased().hasSuffix(".pdb") {
        results.append(fullPath)
      }
    } while FindNextFileW(hFind, &findData)
  }

  return results
}

func createDirectoryTree(_ path: String) {
  path.withCString(encodedAs: UTF16.self) { pathW in
    var current = ""
    for ch in path {
      current.append(ch)
      if ch == "\\" && current.count > 3 {
        current.withCString(encodedAs: UTF16.self) { dirW in
          _ = CreateDirectoryW(dirW, nil)
        }
      }
    }
    current.withCString(encodedAs: UTF16.self) { dirW in
      _ = CreateDirectoryW(dirW, nil)
    }
  }
}

func copyFileWin(_ source: String, _ dest: String) -> Bool {
  source.withCString(encodedAs: UTF16.self) { srcW in
    dest.withCString(encodedAs: UTF16.self) { dstW in
      CopyFileW(srcW, dstW, /*failIfExists:*/ false)
    }
  }
}

@main
struct IndexPdbFiles: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Index PDB files into a symsrv-compatible directory layout.",
    discussion: """
      Scans source_dir recursively for .pdb files, reads their GUID+Age,
      and copies them into a symsrv-compatible layout:
          <output_store>\\<filename>\\<GUID+Age>\\<filename>
      """)

  @Argument(help: "Directory to scan recursively for .pdb files.")
  var sourceDir: String

  @Argument(help: "Output directory for the symbol store.")
  var outputStore: String

  @Flag(name: .long, help: "Show what would be done without copying files.")
  var dryRun = false

  @Flag(name: [.short, .long], help: "Print each file processed.")
  var verbose = false

  mutating func run() throws {
    let attrs = sourceDir.withCString(encodedAs: UTF16.self) { GetFileAttributesW($0) }
    guard attrs != INVALID_FILE_ATTRIBUTES,
      attrs & DWORD(FILE_ATTRIBUTE_DIRECTORY) != 0
    else {
      throw ValidationError("\(sourceDir) is not a directory")
    }

    if dryRun {
      print("Dry run - no files will be copied.")
    } else {
      createDirectoryTree(outputStore)
    }

    print("Scanning \(sourceDir) and subdirectories for PDB files...")

    let pdbFiles = findPdbFiles(in: sourceDir)

    var found = 0
    var indexed = 0
    var skipped = 0

    for fullPath in pdbFiles {
      found += 1
      let filename = String(fullPath.split(separator: "\\").last ?? "")

      guard let pdb = PDBFile(path: fullPath) else {
        if verbose {
          print("  SKIP (not PDB 7.0 or parse error): \(fullPath)")
        }
        skipped += 1
        continue
      }

      let guidStr = hex(pdb.signature)
      let ageStr = String(
        format: "%02x%02x%02x%02x",
        pdb.age & 0xFF,
        (pdb.age >> 8) & 0xFF,
        (pdb.age >> 16) & 0xFF,
        (pdb.age >> 24) & 0xFF)
      let pdbId = guidStr + ageStr
      let symSrvPdbId = WindowsSymbolServer.transformToSymsrvId(from: pdbId)

      let destDir = outputStore + "\\" + filename + "\\" + symSrvPdbId
      let destPath = destDir + "\\" + filename

      if verbose || dryRun {
        print("  \(fullPath) -> \(destPath)")
      }

      if !dryRun {
        createDirectoryTree(destDir)
        if !copyFileWin(fullPath, destPath) {
          print("  ERROR: failed to copy \(fullPath)")
        }
      }

      indexed += 1
    }

    print("")
    print("Done. Found: \(found), Indexed: \(indexed), Skipped: \(skipped)")
    if !dryRun && indexed > 0 {
      print("Symbol store: \(outputStore)")
      print("Serve with: python3 demo-windows-symbol-server.py \(outputStore)")
    }
  }
}
