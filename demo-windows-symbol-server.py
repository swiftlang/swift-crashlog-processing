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
Minimal Windows symbol server (symsrv protocol) for testing.

Serves PDB files using the standard symsrv URL pattern:
    GET /<filename>/<index>/<filename>

Only uncompressed PDB files are supported. CAB-compressed variants (.pd_)
and file.ptr pointer/redirect files are not handled.

Usage:
    python3 demo-windows-symbol-server.py [symbols_dir] [--port PORT]

The symbols directory should contain files laid out as:
    symbols_dir/<filename>/<index>/<filename>

For example:
    symbols_dir/hello.pdb/3844DBB920174967BE7AA4A2C20430FA2/hello.pdb

To quickly populate a test store, use --create-sample to generate a
dummy PDB file with a known index:
    python3 demo-windows-symbol-server.py ./my_store --create-sample

Then test with:
    curl -I http://localhost:8080/sample.pdb/AABBCCDD1/sample.pdb
"""

import argparse
import datetime
import email.utils
import os
import platform
import socket
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


class DualStackHTTPServer(HTTPServer):
    address_family = socket.AF_INET6

    def server_bind(self):
        # Allow dual-stack (IPv4+IPv6) where the OS supports it.
        # On IPv6-only networks this still works fine.
        try:
            self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        except (AttributeError, OSError):
            pass
        super().server_bind()


class SymsrvHandler(BaseHTTPRequestHandler):
    def _ts(self):
        return datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]

    def do_GET(self):
        # Strip leading slash and normalize
        rel = self.path.lstrip("/")
        local_path = os.path.join(self.server.symbols_root, rel)
        local_path = os.path.normpath(local_path)

        # Prevent path traversal
        if not local_path.startswith(os.path.normpath(self.server.symbols_root)):
            self.send_error(403)
            return

        if not os.path.isfile(local_path):
            if self.server.verbose:
                sys.stderr.write(
                    "[symsrv %s] 404 NOT FOUND: %s\n"
                    % (self._ts(), self.path))
            self.send_error(404)
            return

        stat = os.stat(local_path)
        mtime = stat.st_mtime
        file_size = stat.st_size

        # If-Modified-Since support
        ims = self.headers.get("If-Modified-Since")
        if ims:
            try:
                ims_time = email.utils.parsedate_to_datetime(ims).timestamp()
                if mtime <= ims_time:
                    if self.server.verbose:
                        sys.stderr.write(
                            "[symsrv %s] 304 CACHE HIT: %s\n"
                            % (self._ts(), self.path))
                    self.send_response(304)
                    self.end_headers()
                    return
            except (TypeError, ValueError):
                pass

        if self.server.verbose:
            sys.stderr.write(
                "[symsrv %s] 200 SERVING: %s (%d bytes)\n"
                % (self._ts(), self.path, file_size))

        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(file_size))
        self.send_header("Last-Modified", email.utils.formatdate(mtime, usegmt=True))
        self.end_headers()

        with open(local_path, "rb") as f:
            self.wfile.write(f.read())

    def log_message(self, fmt, *args):
        if self.server.verbose:
            sys.stderr.write(
                "[symsrv %s] %s - %s\n"
                % (self._ts(), self.address_string(), fmt % args))


def create_sample(root):
    """Create a dummy PDB so there's something to serve immediately."""
    filename = "sample.pdb"
    index = "AABBCCDD1"
    dest_dir = os.path.join(root, filename, index)
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, filename)
    with open(dest, "wb") as f:
        # Minimal content -- just enough to confirm a download works
        f.write(b"FAKE-PDB-FOR-TESTING\n")
    print("Created sample: %s/%s/%s/%s" % (root, filename, index, filename))


def run_indexer(script_dir):
    """Run index-pdb-files to populate the symsrv store from the build directory."""
    is_windows = platform.system() == "Windows"

    if is_windows:
        build_dir = os.path.join(script_dir, ".build", "debug")
        exe = os.path.join(build_dir, "index-pdb-files.exe")
        store_dir = os.path.join(script_dir, "symsrv")
    else:
        build_dir = os.path.join(script_dir, ".build", "debug")
        exe = os.path.join(build_dir, "index-pdb-files")
        store_dir = os.path.join(script_dir, "symsrv")

    if not os.path.isfile(exe):
        print("Error: %s not found. "
              "Build with: swift build --target index-pdb-files" % exe,
              file=sys.stderr)
        sys.exit(1)

    print("Indexing PDB files from %s into %s ..." % (build_dir, store_dir))
    result = subprocess.run([exe, build_dir, store_dir, "--verbose"], cwd=script_dir)
    if result.returncode != 0:
        print("Error: index-pdb-files exited with code %d" % result.returncode,
              file=sys.stderr)
        sys.exit(1)

    return store_dir


def main():
    parser = argparse.ArgumentParser(
        description="Minimal symsrv symbol server for testing")
    parser.add_argument("symbols_dir", nargs="?", default=None,
                        help="Root directory of the symbol store (default: cwd)")
    parser.add_argument("--port", type=int, default=8080,
                        help="Port to listen on (default: 8080)")
    parser.add_argument("--create-sample", action="store_true",
                        help="Create a dummy PDB in the store and exit")
    parser.add_argument("--index", action="store_true",
                        help="Run index-pdb-files on the build directory first")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="Log all requests with status (200/304/404)")
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))

    if args.index:
        store_dir = run_indexer(script_dir)
        root = os.path.abspath(store_dir)
    elif args.symbols_dir is not None:
        root = os.path.abspath(args.symbols_dir)
    else:
        root = os.path.abspath(".")

    if args.create_sample:
        create_sample(root)
        return

    if not os.path.isdir(root):
        print("Error: %s is not a directory" % root, file=sys.stderr)
        sys.exit(1)

    server = DualStackHTTPServer(("::", args.port), SymsrvHandler)
    server.symbols_root = root
    server.verbose = args.verbose

    print("Serving symbols from %s on port %d" % (root, args.port))
    print("Example: curl http://localhost:%d/<filename>/<index>/<filename>" % args.port)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()


if __name__ == "__main__":
    main()
