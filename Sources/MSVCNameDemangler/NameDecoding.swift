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

extension MSVCDemanglerParser {

  // MARK: - Qualified Names

  func demangleQualifiedName() -> [String]? {
    var segments: [String] = []

    while true {
      if failed { return nil }
      guard let c = peek() else { return nil }

      if c == "@" {
        advance()
        if consume("@") {
          // @@ terminates the qualified name
          break
        }
        // single @ is a separator, continue
        continue
      }

      guard let segment = demangleNameSegment() else { return nil }
      segments.append(segment)
    }

    // Names are stored in reverse order in the mangled form
    segments.reverse()
    return segments
  }

  func demangleNameSegment() -> String? {
    guard let c = peek() else { return nil }

    // Back-reference: digit 0-9
    if c >= "0" && c <= "9" {
      advance()
      let idx = Int(String(c))!
      return resolveNameBackref(idx)
    }

    // Anonymous/Template/Operator: \?[A|$|.]
    if c == "?" {
      // Anonymous namespace: ?A
      if peekAt(1) == "A" {
        return demangleAnonymousNamespace()
      }

      // Template: ?$
      if peekAt(1) == "$" {
        return demangleTemplate()
      }

      // Operator or special name
      advance()
      return demangleOperatorName()
    }

    // Simple identifier: read until @
    return demangleSimpleIdentifier()
  }

  func demangleSimpleIdentifier() -> String? {
    var name = ""
    while let c = peek(), c != "@" {
      name.append(c)
      advance()
    }
    guard !name.isEmpty else {
      failed = true
      return nil
    }
    memorizeNameBackref(name)
    return name
  }

  func demangleAnonymousNamespace() -> String? {
    // Skip ?A then hex chars then @
    let name = "`anonymous namespace'"
    while let c = peek(), c != "@" {
      advance()
    }
    memorizeNameBackref(name)
    return name
  }

  // MARK: - Templates

  func demangleTemplate() -> String? {
    // Consume ?$
    guard consume("?"), consume("$") else {
      failed = true
      return nil
    }

    // Template name (simple identifier up to @)
    var templateName = ""
    while let c = peek(), c != "@" {
      templateName.append(c)
      advance()
    }
    guard !templateName.isEmpty, consume("@") else {
      failed = true
      return nil
    }

    // Save and reset type back-references for template scope
    let savedTypeBackrefs = typeBackrefs
    typeBackrefs = []

    guard let args = demangleTemplateArgs() else {
      typeBackrefs = savedTypeBackrefs
      return nil
    }

    typeBackrefs = savedTypeBackrefs

    let result = "\(templateName)<\(args)>"
    memorizeNameBackref(result)
    return result
  }

  func demangleTemplateArgs() -> String? {
    var args: [String] = []

    while let c = peek() {
      if c == "@" {
        advance()
        break
      }
      guard let arg = demangleTemplateArg() else { return nil }
      args.append(arg)
    }

    return args.joined(separator: ", ")
  }

  func demangleTemplateArg() -> String? {
    guard let c = peek() else { return nil }

    // Non-type integer template parameter: $0 followed by encoded number
    if c == "$" {
      advance()
      guard let kind = advance() else { return nil }
      if kind == "0" {
        guard let num = demangleNumber() else { return nil }
        return String(num)
      }
      // Other $ forms ($1, $H, $I, $J, $E, $F, $G) — bail for now
      return nil
    }

    // $$V = empty parameter pack
    if c == "$" && peekAt(1) == "$" && peekAt(2) == "V" {
      pos += 3
      return ""
    }

    // Type argument
    return demangleType(isParameter: true)
  }

  // MARK: - Operators

  func demangleOperatorName() -> String? {
    guard let code = advance() else { return nil }

    switch code {
    case "0":
      // Constructor — name matches the enclosing class name
      return "\u{0001}ctor"
    case "1":
      // Destructor — name is ~ClassName
      return "\u{0001}dtor"
    case "2": return "operator new"
    case "3": return "operator delete"
    case "4": return "operator="
    case "5": return "operator>>"
    case "6": return "operator<<"
    case "7": return "operator!"
    case "8": return "operator=="
    case "9": return "operator!="
    case "A": return "operator[]"
    case "B": return "operator T"  // conversion — simplified
    case "C": return "operator->"
    case "D": return "operator*"
    case "E": return "operator++"
    case "F": return "operator--"
    case "G": return "operator-"
    case "H": return "operator+"
    case "I": return "operator&"
    case "J": return "operator->*"
    case "K": return "operator/"
    case "L": return "operator%"
    case "M": return "operator<"
    case "N": return "operator<="
    case "O": return "operator>"
    case "P": return "operator>="
    case "Q": return "operator,"
    case "R": return "operator()"
    case "S": return "operator~"
    case "T": return "operator^"
    case "U": return "operator|"
    case "V": return "operator&&"
    case "W": return "operator||"
    case "X": return "operator*="
    case "Y": return "operator+="
    case "Z": return "operator-="
    case "_":
      return demangleExtendedOperator()
    default:
      failed = true
      return nil
    }
  }

  func demangleExtendedOperator() -> String? {
    guard let code = advance() else { return nil }
    switch code {
    case "0": return "operator/="
    case "1": return "operator%="
    case "2": return "operator>>="
    case "3": return "operator<<="
    case "4": return "operator&="
    case "5": return "operator|="
    case "6": return "operator^="
    case "7": return "vftable"
    case "8": return "vbtable"
    case "U": return "operator new[]"
    case "V": return "operator delete[]"
    case "_":
      // Double-underscore operators
      guard let ext = advance() else { return nil }
      switch ext {
      case "K": return "operator\"\""
      case "L": return "operator co_await"
      case "M": return "operator<=>"
      default: return nil
      }
    default:
      // Many special names we don't handle — bail
      return nil
    }
  }

  // MARK: - Numbers

  func demangleNumber() -> Int64? {
    // Number encoding has two schemes:
    // For the numbers 1-10, they are encoded by '0' to '9' respectively.
    // For the numbers 0 and anything 11 or higher, they are encoded by hex
    // digits, with 'A'-'P' corresponding to the digits 0-F, respectively, and
    // terminated with @.
    // ABCDEFGHIJKLMNOP
    // 0123456789ABCDEF

    guard let c = peek() else { return nil }

    var negative = false
    if c == "?" {
      negative = true
      advance()
    }

    guard let d = peek() else { return nil }

    var value: Int64
    if d >= "0" && d <= "9" {
      advance()
      value = Int64(String(d))!
    } else if d >= "A" && d <= "P" {
      // Hex-encoded number terminated by @
      value = 0
      while let h = peek(), h != "@" {
        advance()
        guard h >= "A" && h <= "P" else {
          failed = true
          return nil
        }
        let digit = Int64(h.asciiValue &- 0x41)  // 'A' = 0
        value = value * 16 + digit
      }
      guard consume("@") else {
        failed = true
        return nil
      }
    } else {
      failed = true
      return nil
    }

    return negative ? -value : value
  }

  // MARK: - Back-References

  func memorizeNameBackref(_ name: String) {
    guard nameBackrefs.count < 10 else { return }
    if !nameBackrefs.contains(name) {
      nameBackrefs.append(name)
    }
  }

  func resolveNameBackref(_ idx: Int) -> String? {
    guard idx < nameBackrefs.count else {
      failed = true
      return nil
    }
    return nameBackrefs[idx]
  }
}
