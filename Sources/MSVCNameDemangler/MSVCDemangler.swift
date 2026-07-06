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

/// Demangles an MSVC C++ mangled name into a human-readable string.
///
/// If the name cannot be demangled (not a mangled name, or too complex),
/// returns the original string unchanged.
public func demangleMSVC(_ mangledName: String) -> String {
  let parser = MSVCDemanglerParser(mangledName)
  return parser.demangle() ?? mangledName
}

extension Character {
  var asciiValue: UInt8 {
    guard let scalar = unicodeScalars.first, scalar.isASCII else { return 0 }
    return UInt8(scalar.value)
  }
}

internal final class MSVCDemanglerParser {
  let input: [Character]
  var pos: Int = 0
  var nameBackrefs: [String] = []
  var typeBackrefs: [String] = []
  var failed: Bool = false

  init(_ mangledName: String) {
    self.input = Array(mangledName)
  }

  func demangle() -> String? {
    guard consume("?") else { return nil }

    // MD5-hashed names — bail
    if consumeIf("?@") { return nil }

    // Parse the qualified name
    guard let qualifiedName = demangleQualifiedName() else { return nil }

    // After @@, read the function/variable encoding
    guard let code = peek() else { return nil }

    if code >= "0" && code <= "4" {
      return demangleVariable(name: qualifiedName)
    } else if code == "9" {
      // extern "C" with no parameter list
      advance()
      return qualifiedName.joined(separator: "::")
    } else {
      return demangleFunction(name: qualifiedName)
    }
  }

  // MARK: - Function Demangling

  func demangleFunction(name: [String]) -> String? {
    guard let accessCode = advance() else { return nil }

    let (access, isStatic, isVirtual) = parseAccessSpecifier(accessCode)
    if failed { return nil }

    let isMember = accessCode != "Y" && accessCode != "Z"

    // Thunk adjustments — bail on complex cases
    if accessCode == "G" || accessCode == "H" || accessCode == "O" || accessCode == "P"
      || accessCode == "W" || accessCode == "X"
    {
      return nil
    }
    if let c = peek(), c == "$" { return nil }

    // For non-static member functions, the encoding between the access
    // code and the calling convention is:
    //   [E|I|F]*   — this-pointer modifiers (__ptr64 / __restrict / __unaligned)
    //   <cv-code>  — const/volatile on `this`
    // These move to the end of the rendered signature (e.g. `... const __ptr64`).
    var memberQualifierSuffix = ""
    if isMember && !isStatic {
      while let c = peek() {
        if c == "E" {
          memberQualifierSuffix += " __ptr64"
          advance()
        } else if c == "I" {
          memberQualifierSuffix += " __restrict"
          advance()
        } else if c == "F" {
          memberQualifierSuffix += " __unaligned"
          advance()
        } else {
          break
        }
      }
      let cvStr = qualifiersString(demangleQualifierCode())
      if !cvStr.isEmpty {
        memberQualifierSuffix = " " + cvStr + memberQualifierSuffix
      }
    }

    guard let callingConv = demangleCallingConvention() else { return nil }

    // Return type (constructors/destructors have none)
    var displayName = name
    let rawLast = displayName.last ?? ""
    let isConstructor = rawLast == "\u{0001}ctor"
    let isDestructor = rawLast == "\u{0001}dtor"

    if isConstructor, displayName.count >= 2 {
      displayName[displayName.count - 1] = displayName[displayName.count - 2]
    } else if isDestructor, displayName.count >= 2 {
      displayName[displayName.count - 1] = "~" + displayName[displayName.count - 2]
    }

    let returnType: String?
    if isConstructor || isDestructor {
      returnType = nil
    } else {
      returnType = demangleType(isParameter: false)
      if failed { return nil }
    }

    guard let params = demangleParameterList() else { return nil }

    // Build output
    var parts: [String] = []
    if let acc = access { parts.append(acc + ":") }
    if isStatic { parts.append("static") }
    if isVirtual { parts.append("virtual") }
    if let ret = returnType { parts.append(ret) }
    parts.append(callingConv)
    let fullName = displayName.joined(separator: "::")
    parts.append(fullName + "(" + params + ")" + memberQualifierSuffix)

    return parts.joined(separator: " ")
  }

  // MARK: - Variable Demangling

  func demangleVariable(name: [String]) -> String? {
    guard let storageCode = advance() else { return nil }

    let storage: String?
    switch storageCode {
    case "0": storage = "private: static"
    case "1": storage = "protected: static"
    case "2": storage = "public: static"
    case "3": storage = nil
    case "4": storage = "static"
    default: return nil
    }

    guard let varType = demangleType(isParameter: false) else { return nil }

    let fullName = name.joined(separator: "::")

    if let stor = storage {
      return "\(stor) \(varType) \(fullName)"
    }
    return "\(varType) \(fullName)"
  }

  // MARK: - Access Specifiers

  func parseAccessSpecifier(_ code: Character) -> (access: String?, isStatic: Bool, isVirtual: Bool)
  {
    switch code {
    case "A", "B": return ("private", false, false)
    case "C", "D": return ("private", true, false)
    case "E", "F": return ("private", false, true)
    case "I", "J": return ("protected", false, false)
    case "K", "L": return ("protected", true, false)
    case "M", "N": return ("protected", false, true)
    case "Q", "R": return ("public", false, false)
    case "S", "T": return ("public", true, false)
    case "U", "V": return ("public", false, true)
    case "Y", "Z": return (nil, false, false)
    default:
      failed = true
      return (nil, false, false)
    }
  }

  // MARK: - Calling Conventions

  func demangleCallingConvention() -> String? {
    guard let code = advance() else { return nil }
    switch code {
    case "A", "B": return "__cdecl"
    case "C", "D": return "__pascal"
    case "E", "F": return "__thiscall"
    case "G", "H": return "__stdcall"
    case "I", "J": return "__fastcall"
    case "M", "N": return "__clrcall"
    case "O", "P": return "__eabi"
    case "Q": return "__vectorcall"
    case "S": return "__swift"
    case "W": return "__swiftasync"
    default:
      failed = true
      return nil
    }
  }

  // MARK: - Cursor Management

  @discardableResult
  func advance() -> Character? {
    guard pos < input.count else {
      failed = true
      return nil
    }
    let c = input[pos]
    pos += 1
    return c
  }

  func peek() -> Character? {
    guard pos < input.count else { return nil }
    return input[pos]
  }

  func peekAt(_ offset: Int) -> Character? {
    let idx = pos + offset
    guard idx < input.count else { return nil }
    return input[idx]
  }

  @discardableResult
  func consume(_ expected: Character) -> Bool {
    guard pos < input.count, input[pos] == expected else { return false }
    pos += 1
    return true
  }

  func consumeIf(_ prefix: String) -> Bool {
    let chars = Array(prefix)
    guard pos + chars.count <= input.count else { return false }
    for (i, c) in chars.enumerated() {
      if input[pos + i] != c { return false }
    }
    pos += chars.count
    return true
  }
}

// Footnote: the initial version was created with Claude Opus 4.6 with the
// prompt instructions...

// create a new target called MSVCNameDemangler, the intended purpose is a
// minimal demangler, so that we can make human readable versions of MSVC
// mangled C++ function names when we are running on linux symbolicating a
// crash log that was
//  produced on windows, so we can display something more user friendly.
//  In complicated cases, it is probably OK to just leave the mangled name,
//  but it would be good to demangle most normal cases.

// note that I sense checked all of the code, going through the logic and
// fixing bugs Claude had written, but this should still be viewed as a work
// in progress and of limited scope, it will be tested, and unit tests added,
// for a fairly good list of standard mangled names, but is likely to contain
// some bugs or opportunities for improvement/extension... however, this should
// be good enough for our specific use case, which is symbolicating crash logs
// cross platform - e.g. after symbolicating to a mangled name, attempt an
// accurate demangled name, and if not possible, just report the original
// name... it is more important that the parser is accurate than complete.
// Also the calling code should allow the user to disable demangling, just as
// the standard backtracer does. (The standard backtracer uses the Swift
// runtime for swift symbol demangling, and the platform hosted C++
// demangler for same-platform name demangling. This library is only needed
// when symbolicating offline, and when doing it cross platform... specifically
// symbolicating MSVC mangled C++ names in a backtrace on a non windows
// machine, such as Linux or Darwin).
