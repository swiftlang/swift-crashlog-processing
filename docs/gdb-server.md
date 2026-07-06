# debuginfod / GDB Symbol Server Protocol

## Overview

**debuginfod** is an HTTP-based service (part of the **elfutils** project, since elfutils 0.178, 2019) that serves ELF debugging information, executables, and source code to clients over HTTP/HTTPS. Created by Frank Ch. Eigler at Red Hat, it is the standard mechanism used by GDB, valgrind, systemtap, and other tools to fetch debug symbols on demand.

The protocol is deliberately simple — a few HTTP GET endpoints keyed by **ELF build-id**.

## The ELF Build-ID

The cornerstone of the system is the **ELF build-id** (`NT_GNU_BUILD_ID` ELF note), a unique identifier embedded in every ELF binary at link time. Typically a 20-byte (160-bit) SHA-1 hash represented as 40 hex characters, though other lengths are possible.

Example build-id: `ab123cd456ef789012345678abcdef0123456789`

Inspect a binary's build-id with:
```bash
readelf -n /path/to/binary | grep "Build ID"
```

## HTTP API / URL Structure

Three endpoints, all using **GET**:

### Fetch debug info (DWARF / .debug file)

```
GET /buildid/<BUILDID>/debuginfo
```

Returns the ELF file containing DWARF debug information (the separate `.debug` file stripped via `objcopy --only-keep-debug` or `eu-strip`).

### Fetch executable

```
GET /buildid/<BUILDID>/executable
```

Returns the original executable or shared library ELF file. Useful when you have a core dump but not the original binary.

### Fetch source file

```
GET /buildid/<BUILDID>/source/<PATH>
```

Returns a specific source file compiled into the binary. `<PATH>` is the absolute path as recorded in DWARF `DW_AT_comp_dir` / `DW_AT_name` attributes (leading `/` omitted in URL).

### Summary

| Endpoint | Returns | Content-Type |
|---|---|---|
| `/buildid/<HEX>/debuginfo` | Separate debug info ELF | `application/octet-stream` |
| `/buildid/<HEX>/executable` | Executable/shared-library ELF | `application/octet-stream` |
| `/buildid/<HEX>/source/<PATH>` | Source code text file | varies |

Some servers also support `GET /metrics` (Prometheus) and `GET /` (status page).

## HTTP Methods and Headers

### Request

- **Method**: Always `GET`
- **Headers**:
  - `Accept-Encoding: gzip` — servers may compress responses
  - `If-Modified-Since` — for cache validation
  - `If-None-Match` — for ETag-based cache validation

### Response

- **Status Codes**:
  - `200 OK` — file found and returned
  - `304 Not Modified` — cache is still valid (conditional request)
  - `404 Not Found` — no match for the build-id / artifact type
  - `503 Service Unavailable` — server overloaded, client should retry

- **Response Headers**:
  - `Content-Type: application/octet-stream` (for binaries)
  - `Content-Length`
  - `X-DEBUGINFOD-FILE` — filename on the server's filesystem (informational)
  - `X-DEBUGINFOD-ARCHIVE` — archive path if extracted from RPM/DEB
  - `Cache-Control`, `Last-Modified`, `ETag` — caching directives

## Caching

### Client-side Caching (libdebuginfod)

Cache location:
```
$DEBUGINFOD_CACHE_PATH    (defaults to $HOME/.cache/debuginfod_client/)
```

Cache directory structure mirrors the URL paths:
```
~/.cache/debuginfod_client/<BUILDID>/debuginfo
~/.cache/debuginfod_client/<BUILDID>/executable
~/.cache/debuginfod_client/<BUILDID>/source/<PATH>
```

Cache freshness controlled by:
- **`DEBUGINFOD_CACHE_CLEAN_INTERVAL_S`** — scan interval for stale entries (default: 86400 = 1 day)
- **`DEBUGINFOD_CACHE_MAX_UNUSED_AGE_S`** — unused entry TTL (default: 604800 = 7 days)
- **Negative-hit caching**: 404 responses are cached to avoid re-querying

### HTTP-level Caching

- Client sends `If-Modified-Since` with cached file timestamp
- Server responds `304 Not Modified` if unchanged, or `200` with new content
- ETag-based validation also supported

## The `.build-id` Directory Structure Convention

This predates debuginfod and is the original GDB convention for finding separate debug info on a local filesystem:

```
<debug-dir>/.build-id/<XX>/<YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY>.debug
```

Where:
- `<debug-dir>` is a debug info search directory (default: `/usr/lib/debug`)
- `<XX>` is the **first two hex characters** of the build-id
- `<YYYYYY...>` is the **remaining hex characters** of the build-id
- `.debug` is the suffix

### Example

For build-id `ab123cd456ef789012345678abcdef0123456789`:

```
/usr/lib/debug/.build-id/ab/123cd456ef789012345678abcdef0123456789.debug
```

The two-character prefix directory is a standard bucketing technique to prevent any single directory from containing too many entries.

### For executables (symlinks)

Some distributions also create symlinks without `.debug` pointing to the original executable:

```
/usr/lib/debug/.build-id/ab/123cd456ef789012345678abcdef0123456789
```

### GDB Search Order for Debug Info

1. Same directory as the executable
2. `.debug/` subdirectory of the executable's directory
3. Global debug directory: `/usr/lib/debug/<path-to-executable>.debug`
4. `.build-id` directory: `/usr/lib/debug/.build-id/<XX>/<YY...>.debug`
5. debuginfod (if `DEBUGINFOD_URLS` is set)

The `debug-file-directory` GDB setting controls the base path (default `/usr/lib/debug`).

## Environment Variables

| Variable | Purpose |
|---|---|
| `DEBUGINFOD_URLS` | Space-separated list of server URLs to query |
| `DEBUGINFOD_CACHE_PATH` | Override cache location (default `~/.cache/debuginfod_client/`) |
| `DEBUGINFOD_TIMEOUT` | Connection timeout in seconds (default: 90) |
| `DEBUGINFOD_PROGRESS` | Set to `1` for progress output to stderr |
| `DEBUGINFOD_VERBOSE` | Verbosity level |
| `DEBUGINFOD_RETRY` | Number of retry attempts |
| `DEBUGINFOD_MAXTIME` | Max transfer time in seconds |
| `DEBUGINFOD_MAXSIZE` | Max download size in bytes |
| `DEBUGINFOD_HEADERS_FILE` | Path to file with extra HTTP headers (`Header: Value` per line) |

## Public Servers

| Distribution | URL |
|---|---|
| elfutils (reference) | `https://debuginfod.elfutils.org/` |
| Fedora | `https://debuginfod.fedoraproject.org/` |
| Ubuntu | `https://debuginfod.ubuntu.com/` |
| Debian | `https://debuginfod.debian.net/` |
| Arch Linux | `https://debuginfod.archlinux.org/` |
| openSUSE | `https://debuginfod.opensuse.org/` |

## Specifications and References

There is **no formal RFC**. The specification is defined by the elfutils implementation and its man pages:

- **Canonical spec**: `debuginfod(8)` and `debuginfod-find(1)` man pages in elfutils (`https://sourceware.org/elfutils/`)
- **Source code**: `https://sourceware.org/git/?p=elfutils.git` (the `debuginfod/` directory)
- **Build-ID spec**: `.note.gnu.build-id` ELF note, documented in GNU ld (`ld --build-id`)
- **Fedora Build ID feature**: Originally specified in Fedora 8 (2007), defining the `.build-id` directory layout
- **GDB documentation**: "Separate Debug Files" section documents the `.build-id` directory search convention

## Design Philosophy

- **Stateless**: Pure HTTP GET, no sessions, no authentication required (HTTPS and auth headers supported via `DEBUGINFOD_HEADERS_FILE`)
- **Content-addressed**: Build-ID is a content hash — content-addressable storage
- **Federation**: Clients query multiple servers; first successful response wins. Servers can also federate upstream
- **Simple**: Only 3 endpoints, GET-only, standard HTTP caching semantics

## Comparison with Microsoft Symbol Server

Microsoft's symbol server uses a similar concept but different URL structure:

```
https://msdl.microsoft.com/download/symbols/<filename>/<hash>/<filename>
```

Where `<hash>` is typically PE timestamp+size or PDB GUID+age. debuginfod is simpler (build-id is the only key) and more Unix-native.

---

## Appendix: Sources

This document was compiled by Claude Code (Claude Opus 4.6, Anthropic) from its training data knowledge. No live web fetches were performed during generation. The information is derived from the following sources present in the model's training corpus:

- **elfutils project documentation** — `debuginfod(8)` and `debuginfod-find(1)` man pages from the elfutils project at sourceware.org
- **elfutils source code** — the `debuginfod/` directory in the elfutils git repository (`https://sourceware.org/git/?p=elfutils.git`)
- **GDB manual** — the "Separate Debug Files" section describing `.build-id` directory lookup conventions
- **GNU ld documentation** — the `--build-id` linker option and `NT_GNU_BUILD_ID` ELF note specification
- **Fedora wiki** — the original "Build ID" feature page (Fedora 8, 2007) that defined the `.build-id` directory layout convention
- **Frank Ch. Eigler's presentations** — GNU Tools Cauldron 2019 talk introducing the debuginfod protocol
- **Linux distribution documentation** — Fedora, Ubuntu, Debian, and Arch Linux documentation on their public debuginfod server deployments

**Note**: There is no formal RFC or IETF specification for the debuginfod protocol. The authoritative reference is the elfutils implementation itself and its accompanying man pages. Details in this document should be verified against the current elfutils documentation if used for production implementation work.
