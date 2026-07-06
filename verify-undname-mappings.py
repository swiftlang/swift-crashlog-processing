#!/usr/bin/env python3
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift.org open source project
##
## Copyright (c) 2025 Apple Inc. and the Swift project authors
## Licensed under Apache License v2.0 with Runtime Library Exception
##
## See https://swift.org/LICENSE.txt for license information
## See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
##
##===----------------------------------------------------------------------===##

"""Verify Swift MSVC demangler unit-test expectations against undname.exe.

The Swift unit tests in Tests/swift-symbolicateTests/msvcDemanglerTests.swift
lock in the exact strings our cross-platform MSVC demangler produces.
This script feeds the same mangled inputs through Microsoft's reference
`undname.exe` (ships with Visual Studio) and verifies it produces the
same output. Any mismatch means our Swift demangler is wrong and the
unit-test expectation needs fixing.

Run from a Visual Studio Developer Command Prompt on Windows (so
undname.exe is on PATH), or pass --undname "<full path>".

Exit code: 0 if every case matches, non-zero if any case differs or the
tool can't be located.
"""

import argparse
import re
import shutil
import subprocess
import sys


# Active-demangle cases. Mirrors msvcDemanglerTests.swift exactly:
# (mangled_input, expected_demangled_output)
DEMANGLE_CASES = [
    (
        "?process@Widget@CrashTest@@QEAAXH@Z",
        "public: void __cdecl CrashTest::Widget::process(int) __ptr64",
    ),
    (
        "?run@?$Container@VWidget@CrashTest@@@CrashTest@@QEAAXXZ",
        "public: void __cdecl CrashTest::Container<class CrashTest::Widget>"
        "::run(void) __ptr64",
    ),
    (
        "?trigger_crash@Internal@CrashTest@@YAXH@Z",
        "void __cdecl CrashTest::Internal::trigger_crash(int)",
    ),
    (
        "?prepare_and_crash@CrashTest@@YAHPEBDH@Z",
        "int __cdecl CrashTest::prepare_and_crash(char const * __ptr64,int)",
    ),
    (
        "?value@Widget@CrashTest@@2HA",
        "public: static int CrashTest::Widget::value",
    ),
]

# Pass-through cases. The Swift demangler returns each of these inputs
# unchanged; we expect undname.exe to do the same. Empty-string is
# skipped because undname doesn't accept zero-length arguments.
PASS_THROUGH_CASES = [
    "cxx_crash_through_cpp_frames",
    "$s20crashMeMultithreaded0aB0yyF",
    "<unknown>",
    "",
    "?",
    "?invalid_garbage",
    "??@abc1234567890def@",
]


# undname output looks like:
#
#     Microsoft (R) C/C++ name undecorator
#     Copyright (C) Microsoft Corporation. All rights reserved.
#
#     Undecoration of :- "?process@Widget@CrashTest@@QEAAXH@Z"
#     is :- "public: void __cdecl CrashTest::Widget::process(int) __ptr64"
#
# We grab the line that starts with `is :-`. If your Visual Studio
# version formats this differently, adjust the regex below.
RESULT_RE = re.compile(r'^\s*is\s*:-\s*"(.*)"\s*$')


def find_undname(override):
    if override:
        return override
    found = shutil.which("undname") or shutil.which("undname.exe")
    if not found:
        sys.stderr.write(
            "error: undname.exe not on PATH.\n"
            "       Run this script from a Visual Studio Developer\n"
            "       Command Prompt, or pass --undname \"<full path>\".\n"
        )
        sys.exit(2)
    return found


def run_undname(undname, mangled):
    """Invoke undname.exe and return the demangled string it reports."""
    proc = subprocess.run(
        [undname, mangled],
        capture_output=True,
        text=True,
        check=False,
    )
    for line in proc.stdout.splitlines():
        m = RESULT_RE.match(line)
        if m:
            return m.group(1)
    raise RuntimeError(
        "could not parse undname output for {!r}.\n"
        "stdout was:\n{}\nstderr was:\n{}".format(
            mangled, proc.stdout, proc.stderr
        )
    )


def check(label, mangled, expected, undname):
    try:
        actual = run_undname(undname, mangled)
    except RuntimeError as e:
        print("[FAIL] {}: {!r}".format(label, mangled))
        print("       (could not parse undname output)")
        print("       " + str(e).replace("\n", "\n       "))
        return False

    if actual == expected:
        print("[ OK ] {}: {!r}".format(label, mangled))
        print("       => {!r}".format(actual))
        return True

    print("[FAIL] {}: {!r}".format(label, mangled))
    print("       expected: {!r}".format(expected))
    print("       undname:  {!r}".format(actual))
    return False


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--undname",
        help="explicit path to undname.exe (default: search PATH)",
    )
    args = parser.parse_args()

    undname = find_undname(args.undname)
    print("Using {}\n".format(undname))

    failures = 0
    total = 0

    print("=" * 72)
    print("Demangle cases (Swift demangler produces a transformed string):")
    print("=" * 72)
    for mangled, expected in DEMANGLE_CASES:
        total += 1
        if not check("demangle", mangled, expected, undname):
            failures += 1
        print()

    print("=" * 72)
    print("Pass-through cases (Swift demangler returns input unchanged;")
    print("undname.exe is expected to do the same):")
    print("=" * 72)
    for mangled in PASS_THROUGH_CASES:
        if mangled == "":
            print("[SKIP] pass-through: '' (undname.exe rejects empty input)")
            print()
            continue
        total += 1
        if not check("pass-through", mangled, mangled, undname):
            failures += 1
        print()

    print("=" * 72)
    if failures:
        print("{}/{} case(s) disagreed with undname.exe.".format(failures, total))
        print("Each FAIL above shows the Swift expectation vs. undname's output.")
        return 1
    print("All {} cases match undname.exe.".format(total))
    return 0


if __name__ == "__main__":
    sys.exit(main())
