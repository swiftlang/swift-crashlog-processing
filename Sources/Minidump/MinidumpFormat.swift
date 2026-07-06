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

import CMinidumpFormat

// The on-disk binary format structures live in the CMinidumpFormat C header.
// This file holds the non-layout format constants and enums.

extension MinidumpHeader {
  static let expectedSignature: UInt32 = 0x504D_444D  // "PMDM"
  static let versionMask: UInt32 = 0xFFFF
  static let expectedVersion: UInt32 = 0xa793
}

enum MinidumpStreamType: UInt32 {
  case threadList = 0x0003
  case moduleList = 0x0004
  case memoryList = 0x0005
  case exception = 0x0006
  case systemInfo = 0x0007
  case memory64List = 0x0009
  case miscInfo = 0x000F
  case memoryInfoList = 0x0010
}

enum MinidumpProcessorArchitecture: UInt16 {
  case x86 = 0x0000
  case arm = 0x0005
  case amd64 = 0x0009
  case arm64 = 0x000C
}

enum MinidumpOSPlatform: UInt32 {
  case win32NT = 0x0002
  case unix = 0x8000
  case macOSX = 0x8101
  case iOS = 0x8102
  case linux = 0x8201
  case android = 0x8203
}
