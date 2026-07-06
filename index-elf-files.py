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

"""
Index ELF files into the flat layout that demo-gdb-symbol-server.py expects.

The demo debuginfod server serves files laid out as:
    <store>/<BUILDID>          (executable)
    <store>/<BUILDID>.debug    (debug symbols)

This helper scans a directory (default: linux-syms) for ELF files that are
NOT already named like a build id (i.e. not "<hex>" or "<hex>.debug"). For
each one it reads the GNU build id from the file, renames the file to
"<BUILDID>", and makes a copy called "<BUILDID>.debug".

Files that are directories, are not ELF files, or are already named like a
build id are left untouched.

Usage:
    python3 index-elf-files.py [folder] [--dry-run] [--verbose]
"""

import argparse
import os
import re
import shutil
import struct
import sys

# A file is already in server format if its name is all lowercase hex,
# optionally with a ".debug" suffix.
BUILDID_NAME = re.compile(r"^[0-9a-f]+(\.debug)?$")

NT_GNU_BUILD_ID = 3
PT_NOTE = 4


def read_build_id(path):
    """Return the GNU build id (lowercase hex string) of an ELF file, or None
    if the file is not an ELF or has no build-id note."""
    with open(path, "rb") as f:
        data = f.read()

    if len(data) < 64 or data[:4] != b"\x7fELF":
        return None

    ei_class = data[4]   # 1 = 32-bit, 2 = 64-bit
    ei_data = data[5]    # 1 = little-endian, 2 = big-endian
    endian = "<" if ei_data == 1 else ">"

    if ei_class == 2:  # 64-bit
        e_phoff = struct.unpack_from(endian + "Q", data, 0x20)[0]
        e_phentsize = struct.unpack_from(endian + "H", data, 0x36)[0]
        e_phnum = struct.unpack_from(endian + "H", data, 0x38)[0]
        p_offset_at, p_filesz_at = 8, 32
    elif ei_class == 1:  # 32-bit
        e_phoff = struct.unpack_from(endian + "I", data, 0x1C)[0]
        e_phentsize = struct.unpack_from(endian + "H", data, 0x2A)[0]
        e_phnum = struct.unpack_from(endian + "H", data, 0x2C)[0]
        p_offset_at, p_filesz_at = 4, 16
    else:
        return None

    for i in range(e_phnum):
        ph = e_phoff + i * e_phentsize
        if ph + e_phentsize > len(data):
            break
        p_type = struct.unpack_from(endian + "I", data, ph)[0]
        if p_type != PT_NOTE:
            continue
        if ei_class == 2:
            p_offset = struct.unpack_from(endian + "Q", data, ph + p_offset_at)[0]
            p_filesz = struct.unpack_from(endian + "Q", data, ph + p_filesz_at)[0]
        else:
            p_offset = struct.unpack_from(endian + "I", data, ph + p_offset_at)[0]
            p_filesz = struct.unpack_from(endian + "I", data, ph + p_filesz_at)[0]

        build_id = _scan_notes(data, p_offset, p_filesz, endian)
        if build_id is not None:
            return build_id

    return None


def _scan_notes(data, offset, size, endian):
    """Walk a PT_NOTE segment looking for the NT_GNU_BUILD_ID note."""
    end = offset + size
    pos = offset
    while pos + 12 <= end and pos + 12 <= len(data):
        namesz, descsz, ntype = struct.unpack_from(endian + "III", data, pos)
        name_start = pos + 12
        desc_start = name_start + ((namesz + 3) & ~3)
        next_pos = desc_start + ((descsz + 3) & ~3)
        if desc_start + descsz > len(data):
            break
        name = data[name_start:name_start + namesz].rstrip(b"\x00")
        if ntype == NT_GNU_BUILD_ID and name == b"GNU":
            return data[desc_start:desc_start + descsz].hex()
        pos = next_pos
    return None


def main():
    parser = argparse.ArgumentParser(
        description="Index ELF files into the flat <BUILDID>/<BUILDID>.debug "
                    "layout used by demo-gdb-symbol-server.py.")
    parser.add_argument("folder", nargs="?", default="linux-syms",
                        help="Folder to scan (default: linux-syms)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show what would be done without changing files.")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="Print every file considered, including skips.")
    args = parser.parse_args()

    if not os.path.isdir(args.folder):
        print("Error: %s is not a directory" % args.folder, file=sys.stderr)
        sys.exit(1)

    indexed = 0
    skipped = 0

    for name in sorted(os.listdir(args.folder)):
        path = os.path.join(args.folder, name)

        if not os.path.isfile(path) or os.path.islink(path):
            continue

        if BUILDID_NAME.match(name):
            if args.verbose:
                print("  skip (already indexed): %s" % name)
            skipped += 1
            continue

        build_id = read_build_id(path)
        if build_id is None:
            if args.verbose:
                print("  skip (not an ELF / no build id): %s" % name)
            skipped += 1
            continue

        dest = os.path.join(args.folder, build_id)
        debug_dest = dest + ".debug"

        print("  %s -> %s (+ %s.debug)" % (name, build_id, build_id))

        if not args.dry_run:
            os.rename(path, dest)
            shutil.copyfile(dest, debug_dest)

        indexed += 1

    print("")
    print("Done. Indexed: %d, Skipped: %d%s"
          % (indexed, skipped, " (dry run)" if args.dry_run else ""))


if __name__ == "__main__":
    main()
