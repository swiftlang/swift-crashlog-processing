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

/// A parsed Windows minidump file.
public struct MinidumpFile {
  public struct ThreadInfo {
    public var threadId: UInt32
    public var frames: [UInt64]
    public var registers: RegisterContext

    public init(threadId: UInt32, frames: [UInt64], registers: RegisterContext) {
      self.threadId = threadId
      self.frames = frames
      self.registers = registers
    }
  }

  public struct ModuleInfo {
    public var name: String
    public var baseAddress: UInt64
    public var size: UInt32
    public var pdbId: String?

    public init(name: String, baseAddress: UInt64, size: UInt32, pdbId: String?) {
      self.name = name
      self.baseAddress = baseAddress
      self.size = size
      self.pdbId = pdbId
    }
  }

  public struct ExceptionInfo {
    public var threadId: UInt32
    public var code: UInt32
    public var address: UInt64

    public init(threadId: UInt32, code: UInt32, address: UInt64) {
      self.threadId = threadId
      self.code = code
      self.address = address
    }
  }

  public enum Architecture {
    case x86
    case amd64
    case arm64

    public var name: String {
      switch self {
      case .x86: "i386"
      case .amd64: "x86_64"
      case .arm64: "arm64"
      }
    }
  }

  public enum Platform {
    case windows
    case linux
    case macOS

    public var name: String {
      switch self {
      case .windows: "Windows"
      case .linux: "Linux"
      case .macOS: "macOS"
      }
    }
  }

  public struct RegisterContext {
    public var named: [String: UInt64]
    public var instructionPointer: UInt64
    public var stackPointer: UInt64

    public init(named: [String: UInt64], instructionPointer: UInt64, stackPointer: UInt64) {
      self.named = named
      self.instructionPointer = instructionPointer
      self.stackPointer = stackPointer
    }
  }

  public var architecture: Architecture
  public var platform: Platform
  public var threads: [ThreadInfo]
  public var modules: [ModuleInfo]
  public var exception: ExceptionInfo?

  public init(
    architecture: Architecture, platform: Platform, threads: [ThreadInfo], modules: [ModuleInfo],
    exception: ExceptionInfo?
  ) {
    self.architecture = architecture
    self.platform = platform
    self.threads = threads
    self.modules = modules
    self.exception = exception
  }
}
