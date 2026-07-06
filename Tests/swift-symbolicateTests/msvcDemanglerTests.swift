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
import MSVCNameDemangler

#if TestGeneral

struct MSVCDemangling {
    // MARK: - Symbols taken verbatim from samples/windows/symbolicated-*.txt

    @Test func demanglesMemberFunction() async throws {
        #expect(
            demangleMSVC("?process@Widget@CrashTest@@QEAAXH@Z")
                == "public: void __cdecl CrashTest::Widget::process(int) __ptr64")
    }

    @Test func demanglesTemplatedMemberFunction() async throws {
        #expect(
            demangleMSVC("?run@?$Container@VWidget@CrashTest@@@CrashTest@@QEAAXXZ")
                == "public: void __cdecl CrashTest::Container<class CrashTest::Widget>::run(void) __ptr64")
    }

    @Test func demanglesNestedNamespaceFreeFunction() async throws {
        #expect(
            demangleMSVC("?trigger_crash@Internal@CrashTest@@YAXH@Z")
                == "void __cdecl CrashTest::Internal::trigger_crash(int)")
    }

    @Test func demanglesFreeFunctionWithPointerParam() async throws {
        #expect(
            demangleMSVC("?prepare_and_crash@CrashTest@@YAHPEBDH@Z")
                == "int __cdecl CrashTest::prepare_and_crash(char const * __ptr64,int)")
    }

    @Test func demanglesStaticMemberVariable() async throws {
        #expect(
            demangleMSVC("?value@Widget@CrashTest@@2HA")
                == "public: static int CrashTest::Widget::value")
    }

    // MARK: - Pass-through cases (input returned unchanged)

    @Test func passesThroughUnmangledCSymbol() async throws {
        #expect(demangleMSVC("cxx_crash_through_cpp_frames") == "cxx_crash_through_cpp_frames")
    }

    @Test func passesThroughSwiftMangledName() async throws {
        #expect(demangleMSVC("$s20crashMeMultithreaded0aB0yyF") == "$s20crashMeMultithreaded0aB0yyF")
    }

    @Test func passesThroughUnknownPlaceholder() async throws {
        #expect(demangleMSVC("<unknown>") == "<unknown>")
    }

    @Test func passesThroughEmptyString() async throws {
        #expect(demangleMSVC("") == "")
    }

    @Test func passesThroughBareQuestionMark() async throws {
        #expect(demangleMSVC("?") == "?")
    }

    @Test func passesThroughMalformedQuestionPrefix() async throws {
        #expect(demangleMSVC("?invalid_garbage") == "?invalid_garbage")
    }

    @Test func passesThroughMD5HashedName() async throws {
        #expect(demangleMSVC("??@abc1234567890def@") == "??@abc1234567890def@")
    }
}

#endif
