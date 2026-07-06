# Windows Symbol Server Protocol (symsrv)

## Overview

The **Microsoft Symbol Server protocol** (implemented by **symsrv.dll**) is an HTTP GET-based convention for retrieving debug symbol files (PDB, DBG) and binary images (PE EXE/DLL) from a remote or local store. Introduced with the Windows 2000 Debugging Tools, the protocol has remained essentially unchanged for over 20 years.

There is **no formal RFC or specification**. The protocol is defined by the behaviour of `symsrv.dll` and the Microsoft documentation for WinDbg / Debugging Tools for Windows.

## Core URL Pattern

All requests follow a three-level path structure:

```
GET <server_url>/<filename>/<index>/<filename>
```

The filename appears **twice**, bracketing a unique identifier (the index). This same structure is used whether the store is a local directory, a UNC file share, or an HTTP server.

### Examples

```
https://msdl.microsoft.com/download/symbols/ntdll.pdb/B1B64CA83B574E8EB82B1A5A8B8B8B841/ntdll.pdb
https://msdl.microsoft.com/download/symbols/ntdll.dll/FA224001f2000/ntdll.dll
https://msdl.microsoft.com/download/symbols/kernel32.pdb/DCC5A8B0ABCD4C41A81CDE03DE64FF331/kernel32.pdb
```

## Index / Identifier Computation

The index (middle path component) is derived differently depending on the file type.

### PDB 7.0 (current format, "RSDS" / "DS")

Used since Visual Studio .NET 2002. The PDB contains a 128-bit GUID and a 32-bit "age" counter (incremented on incremental links).

**Index format:** `<GUID><age>`
- GUID: 32 uppercase hex characters, no dashes
- Age: lowercase hex, no leading zeros

**Example:** `3844DBB920174967BE7AA4A2C20430FA2`

The GUID and age are found in the PE file's debug directory entry (`IMAGE_DEBUG_TYPE_CODEVIEW`), which points to a `CV_INFO_PDB70` (RSDS) structure:

```c
struct CV_INFO_PDB70 {
    DWORD  CvSignature;   // "RSDS" = 0x53445352
    GUID   Signature;     // 16 bytes
    DWORD  Age;
    char   PdbFileName[]; // null-terminated
};
```

**GUID byte order note:** The GUID is stored in mixed-endian format per the Windows GUID structure (first 3 fields little-endian, last 2 big-endian). When converted to the hex string, it follows the standard GUID string representation `{3844DBB9-2017-4967-BE7A-A4A2C20430FA}` but with dashes and braces removed.

### PDB 2.0 (legacy, "NB10" / "JG")

Uses a 32-bit timestamp "signature" instead of a GUID, plus an age.

**Index format:** `<signature><age>`
- Signature: 8 uppercase hex characters
- Age: lowercase hex

**Example:** `4A5BC84B2`

```c
struct CV_INFO_PDB20 {
    DWORD  CvHeader;      // "NB10" = 0x3031424E
    DWORD  Offset;
    DWORD  Signature;     // timestamp
    DWORD  Age;
    char   PdbFileName[];
};
```

### PE Files (EXE / DLL / SYS)

Derived from the PE header fields **TimeDateStamp** (`IMAGE_FILE_HEADER`) and **SizeOfImage** (`IMAGE_OPTIONAL_HEADER`).

**Index format:** `<TimeDateStamp><SizeOfImage>`
- TimeDateStamp: 8 uppercase hex characters (with leading zeros)
- SizeOfImage: lowercase hex (minimal digits)

**Example:** `FA224001f2000`

### Mach-O Files (macOS / iOS)

Uses the UUID from the `LC_UUID` load command.

**Index format:** `<UUID>0`
- UUID: 32 uppercase hex characters, no dashes
- A literal `0` appended (age is always 0 for Mach-O)

**Example:** `A1B2C3D4E5F6789012345678ABCDEF010`

### ELF Files (Linux)

Uses the GNU build-id (`NT_GNU_BUILD_ID` ELF note), typically 20 bytes (40 hex chars).

**Index format:** `elf-buildid-sym-<buildid_hex>` (varies by implementation)

### Summary Table

| File Type | Index Format | Example |
|-----------|-------------|---------|
| PDB 7.0 | `<GUID_no_dashes><Age_hex>` | `3844DBB920174967BE7AA4A2C20430FA2` |
| PDB 2.0 | `<Signature_hex><Age_hex>` | `4A5BC84B2` |
| PE (EXE/DLL/SYS) | `<TimeDateStamp><SizeOfImage>` | `FA224001f2000` |
| Mach-O | `<UUID_no_dashes>0` | `A1B2C3D4E5F6789012345678ABCDEF010` |
| ELF | `<BuildID_hex>` | `abcdef1234567890...` (40 hex chars) |

## Lookup Cascade

When a client requests a file, it tries multiple URL variants in order. For `foo.pdb` with index `AABBCCDD1`:

1. `<server>/foo.pdb/AABBCCDD1/foo.pdb` -- uncompressed file
2. `<server>/foo.pdb/AABBCCDD1/foo.pd_` -- CAB-compressed file
3. `<server>/foo.pdb/AABBCCDD1/file.ptr` -- pointer/redirect file

Similarly for PE files like `bar.dll`:

1. `<server>/bar.dll/FA224001f2000/bar.dll`
2. `<server>/bar.dll/FA224001f2000/bar.dl_`
3. `<server>/bar.dll/FA224001f2000/file.ptr`

## File Types Served

| File Type | Extension | Compressed | Description |
|-----------|-----------|------------|-------------|
| PDB | `.pdb` | `.pd_` | Program Database (debug symbols) |
| PE Executable | `.exe` | `.ex_` | Windows executables |
| PE DLL | `.dll` | `.dl_` | Dynamic-link libraries |
| Driver | `.sys` | `.sy_` | Kernel-mode drivers |
| DBG | `.dbg` | `.db_` | Legacy debug info files |
| Pointer | `file.ptr` | -- | Redirect to another location |

The compressed naming convention is: replace the last character of the extension with `_`. Compression uses Microsoft **CAB (Cabinet)** format -- single-file archives where the inner file retains its original name.

## HTTP Protocol Details

### Request

```http
GET /download/symbols/ntdll.pdb/B1B64CA83B574E8EB82B1A5A8B8B8B841/ntdll.pdb HTTP/1.1
Host: msdl.microsoft.com
User-Agent: Microsoft-Symbol-Server/10.0.19041.1
```

- **Method:** Always `GET`
- **User-Agent:** `symsrv.dll` sends `Microsoft-Symbol-Server/<version>`. Some servers check this.
- **No authentication** in the base protocol (private servers may add API keys, Azure AD tokens, etc.)

### Response

| Status | Meaning |
|--------|---------|
| `200 OK` | File found; body is the file content |
| `301` / `302` | Redirect (Microsoft's server often redirects to Azure CDN) |
| `404 Not Found` | Symbol not available |

- **Content-Type:** Not standardised; typically `application/octet-stream`. Clients don't check it.
- Standard caching headers (`ETag`, `Last-Modified`, `Cache-Control`) may be present.
- Range requests are not part of the base protocol.

### Negative Caching

When a server returns 404, `symsrv.dll` caches the negative result locally to avoid repeated lookups for the same missing file.

### Case Sensitivity

Microsoft's servers are case-insensitive. On Linux (case-sensitive filesystems), server implementations must handle this -- some lowercase everything, others preserve original casing.

## Directory Layout

### Three-Tier (Standard / Indexed)

The standard layout created by `symstore.exe`:

```
<root>/
  000admin/
    0000000001          (transaction file)
    0000000002
    lastid.txt          (last transaction ID)
    server.txt          (server description)
    history.txt         (transaction history)
  ntdll.pdb/
    B1B64CA83B574E8EB82B1A5A8B8B8B841/
      ntdll.pdb
  ntdll.dll/
    FA224001f2000/
      ntdll.dll
  kernel32.pdb/
    DCC5A8B0ABCD4C41A81CDE03DE64FF331/
      kernel32.pd_      (compressed)
```

Multiple versions of the same-named file coexist, each under its unique index.

### Two-Tier (Flat)

A legacy layout without the index subdirectory -- only works with a single version of each file:

```
<root>/<filename>/<filename>
```

Rarely used in practice.

## Server Metadata Files

### pingme.txt

Located at `<root>/pingme.txt`. A connectivity check -- clients may request this to verify the server is alive before attempting symbol lookups. A `200` means the server is online; `404` or a timeout causes the client to skip the server (with a cooldown period).

### index2.txt

A flat-file index listing all available `<filename>/<index>` pairs. Allows clients to check availability with a single HTTP request rather than probing individual paths. Located at the store root or under `000admin/`.

### refs.ptr

Tracks which symstore transactions reference a particular file in the index directory, enabling safe deletion.

### file.ptr (Pointer Files)

A `file.ptr` file in an index directory contains a path (UNC or URL) redirecting to the actual symbol file stored elsewhere.

## _NT_SYMBOL_PATH

The environment variable that configures symbol lookup. Stores are separated by semicolons (`;`).

### Basic Syntax

```
SRV*<local_cache>*<server_url>
```

### Examples

```bash
# Server with local cache
SRV*C:\symbols*https://msdl.microsoft.com/download/symbols

# Multiple servers
SRV*C:\symbols*https://msdl.microsoft.com/download/symbols;SRV*C:\symbols*https://symbols.nuget.org/download/symbols

# Two-level caching (local -> downstream -> upstream)
SRV*C:\local*\\server\symbols*https://msdl.microsoft.com/download/symbols

# Local directory (no SRV prefix needed)
C:\my_symbols

# CACHE* keyword -- default cache for subsequent entries
CACHE*C:\symbols;SRV*https://msdl.microsoft.com/download/symbols
```

The `SRV` prefix tells the debugger to use `symsrv.dll`. Asterisks (`*`) separate tiers; the last element is the upstream source, and intermediate elements are caches (written to on successful lookup).

## CAB Compression

Symbols can be compressed when added to a store via `symstore add /compress`. The compressed variant uses the last-character-replaced-with-underscore naming convention (`.pdb` -> `.pd_`, `.dll` -> `.dl_`).

**Tools:**
- Windows: `makecab.exe` (compress), `expand.exe` (decompress)
- Linux: `lcab` or `gcab` (compress), `cabextract` (decompress)

The client downloads the `.pd_` file, decompresses it, and stores the uncompressed result in the local cache.

## symstore.exe -- Populating a Store

```bash
# Add symbols recursively with compression
symstore add /r /f "C:\build\output\*.pdb" /s "\\server\symbols" /t "MyProduct" /v "1.0.0" /c "Build 12345" /compress

# Add a single file
symstore add /f "C:\build\ntdll.pdb" /s "C:\symbols" /t "Windows"

# Store pointer files instead of copying
symstore add /f "C:\build\*.pdb" /s "C:\symbols" /t "MyProduct" /p

# Delete a transaction
symstore del /i 0000000003 /s "C:\symbols"
```

**Key flags:** `/f` (source files), `/r` (recurse), `/s` (store path), `/t` (product name, required), `/v` (version), `/c` (comment), `/compress` (CAB compress), `/p` (store pointers).

Each operation is recorded as a transaction in `000admin/`, with an incrementing 10-digit zero-padded ID. The `lastid.txt` file tracks the most recent transaction number.

## Known Public Symbol Servers

| Organisation | URL |
|---|---|
| Microsoft | `https://msdl.microsoft.com/download/symbols` |
| NuGet / .NET | `https://symbols.nuget.org/download/symbols` |
| Chromium | `https://chromium-browser-symsrv.commondatastorage.googleapis.com` |
| Electron | `https://symbols.electronjs.org` |
| Mozilla | `https://symbols.mozilla.org` |
| Unity | `http://symbolserver.unity3d.com` |

## Source Server (srcsrv)

Source Server is a companion technology that embeds source-file retrieval commands into PDB files.

### How It Works

1. `ssindex.cmd` or `pdbstr.exe` writes a `srcsrv` stream into the PDB
2. The stream maps source file paths to commands/URLs for retrieving the exact version
3. When a debugger needs source, it reads the stream and executes the retrieval command

### srcsrv Stream Format

```
SRCSRV: ini ------------------------------------------------
VERSION=2
INDEXVERSION=2
VERCTRL=http
SRCSRV: variables ------------------------------------------
SRCSRVTRG=https://raw.githubusercontent.com/org/repo/%var3%/%var2%
SRCSRV: source files ---------------------------------------
C:\src\foo.c*src/foo.c*abc123commit
C:\src\bar.c*src/bar.c*abc123commit
SRCSRV: end ------------------------------------------------
```

Each source file line has `*`-separated fields substituted into the `SRCSRVTRG` template.

### Source Link (Modern Replacement)

Source Link (used in .NET) embeds a JSON document mapping local paths to URLs:

```json
{
  "documents": {
    "C:\\src\\*": "https://raw.githubusercontent.com/org/repo/abc123/*"
  }
}
```

## Implementing a Minimal Symbol Server

A symbol server can be any HTTP server (or static file host) that serves files in the correct directory structure.

**Minimum requirements:**
1. Accept GET requests at `/<filename>/<index>/<filename>`
2. Return `200` with file content if found
3. Return `404` if not found

**Example nginx configuration:**

```nginx
server {
    listen 80;
    root /var/symbols;
    autoindex off;

    location / {
        try_files $uri =404;
    }
}
```

Any static file server (nginx, Apache, S3, Azure Blob Storage) works -- no server-side logic required. Simply organise files in the `<filename>/<index>/<filename>` directory structure.

## Comparison with debuginfod

| Aspect | symsrv (Windows) | debuginfod (Linux) |
|---|---|---|
| URL pattern | `/<filename>/<index>/<filename>` | `/buildid/<buildid>/<type>` |
| Identifier | Varies by file type (GUID+age, timestamp+size, etc.) | ELF build-id only |
| Compressed variants | Client-side fallback to `.pd_` etc. | Server-side via HTTP Content-Encoding |
| Source retrieval | Separate (srcsrv in PDB) | Built-in (`/source/<path>` endpoint) |
| Env variable | `_NT_SYMBOL_PATH` | `DEBUGINFOD_URLS` |
| Formal spec | No (defined by symsrv.dll behaviour) | No (defined by elfutils implementation) |

---

## Appendix: Sources

This document was compiled by Claude Code (Claude Opus 4.6, Anthropic) from its training data knowledge and web research. The information is derived from the following sources present in the model's training corpus:

- **Microsoft Debugging Tools documentation** -- WinDbg help, "Symbol Stores and Symbol Servers" documentation on learn.microsoft.com
- **symsrv.dll behaviour** -- reverse-engineered protocol behaviour documented by the debugging community
- **symstore.exe documentation** -- Microsoft's official documentation for the symbol store utility
- **Open source implementations** -- Projects such as SymbolStore (.NET), Techdump, and various community symbol server implementations that document the protocol
- **Microsoft PDB format** -- The CodeView debug info structures (CV_INFO_PDB70 / RSDS, CV_INFO_PDB20 / NB10) documented in the Microsoft PE/COFF specification

**Note**: There is no formal RFC for the symsrv protocol. The protocol has been stable since its introduction (~2000) but details should be verified against current Microsoft documentation and symsrv.dll behaviour if used for production implementation work.
