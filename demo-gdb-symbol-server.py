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
Minimal debuginfod symbol server for testing.

Serves debug symbols and executables using the debuginfod URL scheme:
    GET /buildid/<BUILDID>/debuginfo
    GET /buildid/<BUILDID>/executable

Usage:
    python3 demo-gdb-symbol-server.py [symbols_dir] [--port PORT]

The symbols directory should contain files laid out as:
    symbols_dir/<BUILDID>.debug    (debug symbol files)
    symbols_dir/<BUILDID>          (executable files)

For example:
    symbols_dir/ab123cd456ef789012345678abcdef0123456789.debug
    symbols_dir/ab123cd456ef789012345678abcdef0123456789

Alternatively, files can use the .build-id directory layout:
    symbols_dir/.build-id/<XX>/<YYYYYY...>.debug
    symbols_dir/.build-id/<XX>/<YYYYYY...>

To quickly populate a test store, use --create-sample to generate a
dummy file with a known build-id:
    python3 demo-gdb-symbol-server.py ./my_store --create-sample

Then test with:
    curl -I \
      http://localhost:8080/buildid/aabbccdd00112233aabbccdd00112233aabbccdd/debuginfo
"""

import argparse
import datetime
import email.utils
import os
import socket
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


class DualStackHTTPServer(HTTPServer):
    address_family = socket.AF_INET6

    def server_bind(self):
        try:
            self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        except (AttributeError, OSError):
            pass
        super().server_bind()


class DebuginfodHandler(BaseHTTPRequestHandler):
    def _ts(self):
        return datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]

    def do_GET(self):
        parts = self.path.strip("/").split("/")

        # Expected: buildid/<BUILDID>/debuginfo or buildid/<BUILDID>/executable
        if len(parts) != 3 or parts[0] != "buildid":
            self.send_error(404)
            return

        buildid = parts[1]
        artifact = parts[2]

        if artifact not in ("debuginfo", "executable"):
            self.send_error(404)
            return

        local_path = self._find_file(buildid, artifact)

        if local_path is None:
            if self.server.verbose:
                sys.stderr.write(
                    "[debuginfod %s] 404 NOT FOUND: %s\n"
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
                            "[debuginfod %s] 304 CACHE HIT: %s\n"
                            % (self._ts(), self.path))
                    self.send_response(304)
                    self.end_headers()
                    return
            except (TypeError, ValueError):
                pass

        if self.server.verbose:
            sys.stderr.write(
                "[debuginfod %s] 200 SERVING: %s (%d bytes)\n"
                % (self._ts(), self.path, file_size))

        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(file_size))
        self.send_header("Last-Modified", email.utils.formatdate(mtime, usegmt=True))
        self.end_headers()

        with open(local_path, "rb") as f:
            self.wfile.write(f.read())

    def _find_file(self, buildid, artifact):
        root = self.server.symbols_root

        suffix = ".debug" if artifact == "debuginfo" else ""

        # Try flat layout: <root>/<BUILDID>.debug or <root>/<BUILDID>
        flat_path = os.path.join(root, buildid + suffix)
        if os.path.isfile(flat_path):
            return flat_path

        # Try .build-id layout: <root>/.build-id/<XX>/<YYYYYY...>.debug
        if len(buildid) >= 2:
            prefix = buildid[:2]
            rest = buildid[2:]
            buildid_path = os.path.join(root, ".build-id", prefix, rest + suffix)
            if os.path.isfile(buildid_path):
                return buildid_path

        return None

    def log_message(self, fmt, *args):
        if self.server.verbose:
            sys.stderr.write(
                "[debuginfod %s] %s - %s\n"
                % (self._ts(), self.address_string(), fmt % args))


def main():
    parser = argparse.ArgumentParser(
        description="Minimal debuginfod symbol server for testing")
    parser.add_argument("symbols_dir", nargs="?", default=None,
                        help="Root directory of the symbol store (default: cwd)")
    parser.add_argument("--port", type=int, default=8080,
                        help="Port to listen on (default: 8080)")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="Log all requests with status (200/304/404)")
    args = parser.parse_args()

    if args.symbols_dir is not None:
        root = os.path.abspath(args.symbols_dir)
    else:
        root = os.path.abspath(".")

    if not os.path.isdir(root):
        print("Error: %s is not a directory" % root, file=sys.stderr)
        sys.exit(1)

    server = DualStackHTTPServer(("::", args.port), DebuginfodHandler)
    server.symbols_root = root
    server.verbose = args.verbose

    print("Serving symbols from %s on port %d%s"
          % (root, args.port, " (verbose)" if args.verbose else ""))
    print("Example: curl http://localhost:%d/buildid/<BUILDID>/debuginfo" % args.port)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()


if __name__ == "__main__":
    main()
