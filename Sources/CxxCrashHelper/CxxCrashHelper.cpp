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

#include "CxxCrashHelper.h"
#include <cstdio>
#include <cstdlib>

namespace CrashTest {

class Widget {
public:
    int value;

    Widget(int v) : value(v) {}

    __attribute__((noinline))
    void process(int x) {
        // Crash: null pointer dereference
        volatile int *p = nullptr;
        *p = x + value;
    }
};

template<typename T>
class Container {
    T item;
public:
    Container(T val) : item(val) {}

    __attribute__((noinline))
    void run() {
        item.process(42);
    }
};

namespace Internal {

__attribute__((noinline))
void trigger_crash(int seed) {
    Widget w(seed);
    Container<Widget> c(w);
    c.run();
}

} // namespace Internal

__attribute__((noinline))
int prepare_and_crash(const char *label, int count) {
    Internal::trigger_crash(count * 7);
    return 0;
}

} // namespace CrashTest

extern "C" void cxx_crash_through_cpp_frames(void) {
    CrashTest::prepare_and_crash("test-crash", 3);
}
