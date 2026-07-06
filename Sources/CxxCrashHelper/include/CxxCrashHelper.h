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

#ifndef CXX_CRASH_HELPER_H
#define CXX_CRASH_HELPER_H

#ifdef __cplusplus
extern "C" {
#endif

/// Calls through several C++ functions then crashes.
/// The backtrace will contain mangled C++ symbol names.
void cxx_crash_through_cpp_frames(void);

#ifdef __cplusplus
}
#endif

#endif
