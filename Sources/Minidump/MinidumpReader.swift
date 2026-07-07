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
import Foundation

public enum MinidumpError: Error {
  case invalidSignature
  case invalidVersion
  case truncatedFile
  case unsupportedArchitecture(UInt16)
  case missingStream(String)
}

/// Reads a Windows minidump (.dmp) file and extracts threads, modules, and exception info.
public struct MinidumpReader {
  private let data: Data

  public init(contentsOf url: URL) throws {
    self.data = try Data(contentsOf: url)
  }

  public init(data: Data) {
    self.data = data
  }

  public func read() throws -> MinidumpFile {
    let header = try readHeader()
    let directories = try readDirectories(
      count: Int(header.numberOfStreams),
      at: Int(header.streamDirectoryRVA))

    let systemInfo = try readSystemInfo(directories: directories)
    let architecture = try parseArchitecture(systemInfo.processorArchitecture)
    let platform = parsePlatform(systemInfo.platformId)
    let modules = try readModules(directories: directories)
    let exception = try readException(directories: directories)
    let threads = try readThreads(directories: directories, architecture: architecture)

    return MinidumpFile(
      architecture: architecture,
      platform: platform,
      threads: threads,
      modules: modules,
      exception: exception)
  }

  private func readHeader() throws -> MinidumpHeader {
    guard data.count >= MemoryLayout<MinidumpHeader>.size else {
      throw MinidumpError.truncatedFile
    }

    let header: MinidumpHeader = load(at: 0)

    guard header.signature == MinidumpHeader.expectedSignature else {
      throw MinidumpError.invalidSignature
    }

    guard (header.version & MinidumpHeader.versionMask) == MinidumpHeader.expectedVersion else {
      throw MinidumpError.invalidVersion
    }

    return header
  }

  private func readDirectories(count: Int, at offset: Int) throws -> [MinidumpDirectory] {
    let stride = MemoryLayout<MinidumpDirectory>.size
    let endOffset = offset + count * stride
    guard endOffset <= data.count else {
      throw MinidumpError.truncatedFile
    }

    return (0..<count).map { i in
      load(at: offset + i * stride)
    }
  }

  private func findStream(_ type: MinidumpStreamType, in directories: [MinidumpDirectory])
    -> MinidumpDirectory?
  {
    directories.first { $0.streamType == type.rawValue }
  }

  private func readSystemInfo(directories: [MinidumpDirectory]) throws -> MinidumpSystemInfo {
    guard let dir = findStream(.systemInfo, in: directories) else {
      throw MinidumpError.missingStream("SystemInfo")
    }
    guard Int(dir.rva) + MemoryLayout<MinidumpSystemInfo>.size <= data.count else {
      throw MinidumpError.truncatedFile
    }
    return load(at: Int(dir.rva))
  }

  private func parseArchitecture(_ raw: UInt16) throws -> MinidumpFile.Architecture {
    guard let arch = MinidumpProcessorArchitecture(rawValue: raw) else {
      throw MinidumpError.unsupportedArchitecture(raw)
    }
    switch arch {
    case .x86: return .x86
    case .amd64: return .amd64
    case .arm64: return .arm64
    case .arm: throw MinidumpError.unsupportedArchitecture(raw)
    }
  }

  private func parsePlatform(_ platformId: UInt32) -> MinidumpFile.Platform {
    switch MinidumpOSPlatform(rawValue: platformId) {
    case .linux, .android: return .linux
    case .macOSX, .iOS: return .macOS
    default: return .windows
    }
  }

  private func readModules(directories: [MinidumpDirectory]) throws -> [MinidumpFile.ModuleInfo] {
    guard let dir = findStream(.moduleList, in: directories) else {
      return []
    }

    let offset = Int(dir.rva)
    guard offset + 4 <= data.count else { throw MinidumpError.truncatedFile }

    let count: UInt32 = load(at: offset)
    let stride = MemoryLayout<MinidumpModule>.size
    let modulesOffset = offset + 4

    guard modulesOffset + Int(count) * stride <= data.count else {
      throw MinidumpError.truncatedFile
    }

    return (0..<Int(count)).compactMap { i in
      let module: MinidumpModule = load(at: modulesOffset + i * stride)
      let name = readMinidumpString(at: Int(module.moduleNameRVA)) ?? "unknown"
      let pdbId = readCvRecord(at: Int(module.cvRecord.rva), size: Int(module.cvRecord.dataSize))

      return MinidumpFile.ModuleInfo(
        name: name,
        baseAddress: module.baseOfImage,
        size: module.sizeOfImage,
        pdbId: pdbId)
    }
  }

  private func readException(directories: [MinidumpDirectory]) throws -> MinidumpFile.ExceptionInfo?
  {
    guard let dir = findStream(.exception, in: directories) else {
      return nil
    }

    let offset = Int(dir.rva)
    guard offset + MemoryLayout<MinidumpExceptionStream>.size <= data.count else {
      throw MinidumpError.truncatedFile
    }

    let stream: MinidumpExceptionStream = load(at: offset)

    return MinidumpFile.ExceptionInfo(
      threadId: stream.threadId,
      code: stream.exceptionRecord.exceptionCode,
      address: stream.exceptionRecord.exceptionAddress)
  }

  private func readThreads(
    directories: [MinidumpDirectory], architecture: MinidumpFile.Architecture
  ) throws -> [MinidumpFile.ThreadInfo] {
    guard let dir = findStream(.threadList, in: directories) else {
      return []
    }

    let offset = Int(dir.rva)
    guard offset + 4 <= data.count else { throw MinidumpError.truncatedFile }

    let count: UInt32 = load(at: offset)
    let stride = MemoryLayout<MinidumpThread>.size
    let threadsOffset = offset + 4

    guard threadsOffset + Int(count) * stride <= data.count else {
      throw MinidumpError.truncatedFile
    }

    return (0..<Int(count)).compactMap { i in
      let thread: MinidumpThread = load(at: threadsOffset + i * stride)
      let registers = readRegisterContext(
        at: Int(thread.context.rva),
        size: Int(thread.context.dataSize),
        architecture: architecture)
      let frames = readStackFrames(thread: thread, registers: registers, architecture: architecture)

      return MinidumpFile.ThreadInfo(
        threadId: thread.threadId,
        frames: frames,
        registers: registers)
    }
  }

  private func readRegisterContext(
    at offset: Int, size: Int, architecture: MinidumpFile.Architecture
  ) -> MinidumpFile.RegisterContext {
    guard offset + size <= data.count else {
      return MinidumpFile.RegisterContext(named: [:], instructionPointer: 0, stackPointer: 0)
    }

    switch architecture {
    case .amd64:
      return readAMD64Context(at: offset, size: size)
    case .arm64:
      return readARM64Context(at: offset, size: size)
    case .x86:
      return readX86Context(at: offset, size: size)
    }
  }

  private func readAMD64Context(at offset: Int, size: Int) -> MinidumpFile.RegisterContext {
    // Offsets from MinidumpContext_x86_64 layout
    guard size >= 0x100 else {
      return MinidumpFile.RegisterContext(named: [:], instructionPointer: 0, stackPointer: 0)
    }

    let rax: UInt64 = load(at: offset + 0x78)
    let rcx: UInt64 = load(at: offset + 0x80)
    let rdx: UInt64 = load(at: offset + 0x88)
    let rbx: UInt64 = load(at: offset + 0x90)
    let rsp: UInt64 = load(at: offset + 0x98)
    let rbp: UInt64 = load(at: offset + 0xA0)
    let rsi: UInt64 = load(at: offset + 0xA8)
    let rdi: UInt64 = load(at: offset + 0xB0)
    let r8: UInt64 = load(at: offset + 0xB8)
    let r9: UInt64 = load(at: offset + 0xC0)
    let r10: UInt64 = load(at: offset + 0xC8)
    let r11: UInt64 = load(at: offset + 0xD0)
    let r12: UInt64 = load(at: offset + 0xD8)
    let r13: UInt64 = load(at: offset + 0xE0)
    let r14: UInt64 = load(at: offset + 0xE8)
    let r15: UInt64 = load(at: offset + 0xF0)
    let rip: UInt64 = load(at: offset + 0xF8)

    var named: [String: UInt64] = [
      "rax": rax, "rcx": rcx, "rdx": rdx, "rbx": rbx,
      "rsp": rsp, "rbp": rbp, "rsi": rsi, "rdi": rdi,
      "r8": r8, "r9": r9, "r10": r10, "r11": r11,
      "r12": r12, "r13": r13, "r14": r14, "r15": r15,
      "rip": rip,
    ]

    let eflags: UInt32 = load(at: offset + 0x44)
    named["rflags"] = UInt64(eflags)

    return MinidumpFile.RegisterContext(named: named, instructionPointer: rip, stackPointer: rsp)
  }

  private func readARM64Context(at offset: Int, size: Int) -> MinidumpFile.RegisterContext {
    // ARM64 context: flags(8) + x0-x31(256) + pc(8) + cpsr(4)
    guard size >= 0x110 else {
      return MinidumpFile.RegisterContext(named: [:], instructionPointer: 0, stackPointer: 0)
    }

    var named: [String: UInt64] = [:]

    for i in 0..<32 {
      let reg: UInt64 = load(at: offset + 0x08 + i * 8)
      named["x\(i)"] = reg
    }

    let pc: UInt64 = load(at: offset + 0x108)
    let cpsr: UInt32 = load(at: offset + 0x110)
    named["pc"] = pc
    named["cpsr"] = UInt64(cpsr)

    // x29 = fp, x30 = lr, x31 = sp (in the context)
    let sp = named["x31"] ?? 0
    named["sp"] = sp
    named["fp"] = named["x29"]
    named["lr"] = named["x30"]

    return MinidumpFile.RegisterContext(named: named, instructionPointer: pc, stackPointer: sp)
  }

  private func readX86Context(at offset: Int, size: Int) -> MinidumpFile.RegisterContext {
    // see https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-wow64_context
    // for example... this is the i386 (32 bit Intel) context area as defined by Windows (win32)

    guard size >= 0xC8 else {
      return MinidumpFile.RegisterContext(named: [:], instructionPointer: 0, stackPointer: 0)
    }

    let edi: UInt32 = load(at: offset + 0x9C)
    let esi: UInt32 = load(at: offset + 0xA0)
    let ebx: UInt32 = load(at: offset + 0xA4)
    let edx: UInt32 = load(at: offset + 0xA8)
    let ecx: UInt32 = load(at: offset + 0xAC)
    let eax: UInt32 = load(at: offset + 0xB0)
    let ebp: UInt32 = load(at: offset + 0xB4)
    let eip: UInt32 = load(at: offset + 0xB8)
    let esp: UInt32 = load(at: offset + 0xC4)
    let eflags: UInt32 = load(at: offset + 0xC0)

    let named: [String: UInt64] = [
      "eax": UInt64(eax), "ecx": UInt64(ecx), "edx": UInt64(edx), "ebx": UInt64(ebx),
      "esp": UInt64(esp), "ebp": UInt64(ebp), "esi": UInt64(esi), "edi": UInt64(edi),
      "eip": UInt64(eip), "eflags": UInt64(eflags),
    ]

    return MinidumpFile.RegisterContext(
      named: named, instructionPointer: UInt64(eip), stackPointer: UInt64(esp))
  }

  private func readStackFrames(
    thread: MinidumpThread, registers: MinidumpFile.RegisterContext,
    architecture: MinidumpFile.Architecture
  ) -> [UInt64] {
    // This simplified version only contains the top stack frame.
    // Can be changed to a full stack walk later if needed.
    guard registers.instructionPointer != 0 else { return [] }
    return [registers.instructionPointer]
  }

  private func readMinidumpString(at offset: Int) -> String? {
    guard offset + 4 <= data.count else { return nil }

    let length: UInt32 = load(at: offset)
    let stringOffset = offset + 4
    let byteCount = Int(length)

    guard stringOffset + byteCount <= data.count else { return nil }

    let stringData = data[stringOffset..<stringOffset + byteCount]
    return String(data: stringData, encoding: .utf16LittleEndian)
  }

  // read codeview record
  private func readCvRecord(at offset: Int, size: Int) -> String? {
    guard size >= 24, offset + size <= data.count else { return nil }

    let signature: UInt32 = load(at: offset)

    // RSDS = PDB 7.0 format
    guard signature == 0x5344_5352 else { return nil }

    // 16-byte GUID + 4-byte age
    let guidBytes = data[offset + 4..<offset + 20]
    let age: UInt32 = load(at: offset + 20)

    // Format as hex string: GUID bytes + age (little-endian as stored)
    let guidHex = guidBytes.map { String(format: "%02x", $0) }.joined()
    let ageHex = String(format: "%08x", age)

    return guidHex + ageHex
  }

  private func load<T>(at offset: Int) -> T {
    return data.withUnsafeBytes { buffer in
      buffer.loadUnaligned(fromByteOffset: offset, as: T.self)
    }
  }
}
