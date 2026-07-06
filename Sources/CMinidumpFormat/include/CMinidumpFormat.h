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

#ifndef CMINIDUMP_FORMAT_H
#define CMINIDUMP_FORMAT_H

#include <stdint.h>

// On-disk binary format structures for Windows minidump files.
// All fields are little-endian.

typedef struct MinidumpHeader {
  uint32_t signature;
  uint32_t version;
  uint32_t numberOfStreams;
  uint32_t streamDirectoryRVA;
  uint32_t checksum;
  uint32_t timeDateStamp;
  uint64_t flags;
} MinidumpHeader;

typedef struct MinidumpDirectory {
  uint32_t streamType;
  uint32_t dataSize;
  uint32_t rva;
} MinidumpDirectory;

typedef struct MinidumpLocationDescriptor {
  uint32_t dataSize;
  uint32_t rva;
} MinidumpLocationDescriptor;

typedef struct MinidumpMemoryDescriptor {
  uint64_t startOfMemoryRange;
  MinidumpLocationDescriptor memory;
} MinidumpMemoryDescriptor;

typedef struct MinidumpThread {
  uint32_t threadId;
  uint32_t suspendCount;
  uint32_t priorityClass;
  uint32_t priority;
  uint64_t environmentBlock;
  MinidumpMemoryDescriptor stack;
  MinidumpLocationDescriptor context;
} MinidumpThread;

typedef struct VSFixedFileInfo {
  uint32_t signature;
  uint32_t structVersion;
  uint32_t fileVersionHigh;
  uint32_t fileVersionLow;
  uint32_t productVersionHigh;
  uint32_t productVersionLow;
  uint32_t fileFlagsMask;
  uint32_t fileFlags;
  uint32_t fileOS;
  uint32_t fileType;
  uint32_t fileSubtype;
  uint32_t fileDateHigh;
  uint32_t fileDateLow;
} VSFixedFileInfo;

typedef struct MinidumpModule {
  uint64_t baseOfImage;
  uint32_t sizeOfImage;
  uint32_t checksum;
  uint32_t timeDateStamp;
  uint32_t moduleNameRVA;
  VSFixedFileInfo versionInfo;
  MinidumpLocationDescriptor cvRecord;
  MinidumpLocationDescriptor miscRecord;
  uint64_t reserved0;
  uint64_t reserved1;
} MinidumpModule;

typedef struct MinidumpExceptionRecord {
  uint32_t exceptionCode;
  uint32_t exceptionFlags;
  uint64_t exceptionRecord;
  uint64_t exceptionAddress;
  uint32_t numberOfParameters;
  uint32_t unusedAlignment;
  uint64_t exceptionInformation[15];
} MinidumpExceptionRecord;

typedef struct MinidumpExceptionStream {
  uint32_t threadId;
  uint32_t unusedAlignment;
  MinidumpExceptionRecord exceptionRecord;
  MinidumpLocationDescriptor threadContext;
} MinidumpExceptionStream;

typedef struct MinidumpSystemInfo {
  uint16_t processorArchitecture;
  uint16_t processorLevel;
  uint16_t processorRevision;
  uint8_t numberOfProcessors;
  uint8_t productType;
  uint32_t majorVersion;
  uint32_t minorVersion;
  uint32_t buildNumber;
  uint32_t platformId;
  uint32_t csdVersionRVA;
  uint16_t suiteMask;
  uint16_t reserved;
  uint8_t cpu[24];
} MinidumpSystemInfo;

#endif  // CMINIDUMP_FORMAT_H
