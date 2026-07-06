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

  // MARK: - Type Parsing

  func demangleType(isParameter: Bool) -> String? {
    guard let c = peek() else { return nil }

    // Back-reference in parameter position
    if isParameter && c >= "0" && c <= "9" {
      advance()
      return resolveTypeBackref(Int(String(c))!)
    }

    let startPos = pos
    let result = demangleTypeCore()

    // Memorize complex types for back-referencing
    if let result, isParameter, pos - startPos > 1 {
      memorizeTypeBackref(result)
    }

    return result
  }

  private func demangleTypeCore() -> String? {
    guard let c = peek() else { return nil }

    // Extended types with _ prefix
    if c == "_" {
      advance()
      return demangleExtendedPrimitive()
    }

    // $$ prefixed types
    if c == "$" && peekAt(1) == "$" {
      pos += 2
      return demangleDollarDollarType()
    }

    // Pointer types
    if c == "P" || c == "Q" || c == "R" || c == "S" {
      return demanglePointerType()
    }

    // Reference
    if c == "A" {
      advance()
      return demangleReferenceType(rvalue: false)
    }

    // Tag types (class/struct/union/enum)
    if c == "V" || c == "U" || c == "T" {
      return demangleTagType()
    }
    if c == "W" {
      advance()
      guard consume("4") else {
        failed = true
        return nil
      }
      return demangleEnumType()
    }

    // Function type (non-member function pointer content)
    if c == "6" {
      advance()
      return demangleFunctionSignatureType()
    }

    // Array type
    if c == "Y" {
      advance()
      return demangleArrayType()
    }

    // Primitive types
    return demanglePrimitiveType()
  }

  // MARK: - Primitive Types

  func demanglePrimitiveType() -> String? {
    guard let c = advance() else { return nil }
    switch c {
    case "X": return "void"
    case "D": return "char"
    case "C": return "signed char"
    case "E": return "unsigned char"
    case "F": return "short"
    case "G": return "unsigned short"
    case "H": return "int"
    case "I": return "unsigned int"
    case "J": return "long"
    case "K": return "unsigned long"
    case "M": return "float"
    case "N": return "double"
    case "O": return "long double"
    default:
      failed = true
      return nil
    }
  }

  func demangleExtendedPrimitive() -> String? {
    guard let c = advance() else { return nil }
    switch c {
    case "N": return "bool"
    case "J": return "__int64"
    case "K": return "unsigned __int64"
    case "W": return "wchar_t"
    case "Q": return "char8_t"
    case "S": return "char16_t"
    case "U": return "char32_t"
    case "P": return "auto"
    case "T": return "decltype(auto)"
    default:
      failed = true
      return nil
    }
  }

  func demangleDollarDollarType() -> String? {
    guard let c = peek() else { return nil }
    switch c {
    case "T":
      advance()
      return "std::nullptr_t"
    case "Q":
      // Rvalue reference
      advance()
      return demangleReferenceType(rvalue: true)
    case "A":
      // Function type (used in templates for function type params)
      advance()
      return demangleFunctionReferenceType()
    case "B":
      // Array in template
      advance()
      return demangleArrayType()
    case "C":
      // Qualified type in template
      advance()
      let quals = demangleQualifierCode()
      guard let inner = demangleType(isParameter: false) else { return nil }
      return applyQualifiers(quals, to: inner)
    default:
      failed = true
      return nil
    }
  }

  // MARK: - Pointer Types

  func demanglePointerType() -> String? {
    guard let ptrCode = advance() else { return nil }

    let ptrQual: String
    switch ptrCode {
    case "P": ptrQual = "*"
    case "Q": ptrQual = "*const"
    case "R": ptrQual = "*volatile"
    case "S": ptrQual = "*const volatile"
    default:
      failed = true
      return nil
    }

    // Extended qualifiers (E = __ptr64, I = __restrict, F = __unaligned)
    var ext = ""
    while let c = peek() {
      if c == "E" {
        ext += " __ptr64"
        advance()
      } else if c == "I" {
        ext += " __restrict"
        advance()
      } else if c == "F" {
        ext += " __unaligned"
        advance()
      } else {
        break
      }
    }

    // Pointee qualifiers
    let quals = demangleQualifierCode()

    // Check if this is a function pointer (6) or member function pointer (8)
    if let c = peek(), c == "6" {
      advance()
      guard let fnType = demangleFunctionSignatureType() else { return nil }
      return fnType + " " + ptrQual + ext
    }
    if let c = peek(), c == "8" {
      // Member function pointer — bail for now
      return nil
    }

    guard let pointee = demangleType(isParameter: false) else { return nil }
    let qualStr = qualifiersString(quals)
    if qualStr.isEmpty {
      return pointee + " " + ptrQual + ext
    }
    return pointee + " " + qualStr + " " + ptrQual + ext
  }

  func demangleReferenceType(rvalue: Bool) -> String? {
    let refSymbol = rvalue ? "&&" : "&"

    // Extended qualifiers
    while let c = peek() {
      if c == "E" || c == "I" || c == "F" { advance() } else { break }
    }

    // Qualifiers on the referent
    let quals = demangleQualifierCode()

    guard let referent = demangleType(isParameter: false) else { return nil }
    let qualStr = qualifiersString(quals)
    if qualStr.isEmpty {
      return referent + " " + refSymbol
    }
    return qualStr + " " + referent + " " + refSymbol
  }

  // MARK: - Tag Types

  func demangleTagType() -> String? {
    guard let tag = advance() else { return nil }
    let keyword: String
    switch tag {
    case "V": keyword = "class"
    case "U": keyword = "struct"
    case "T": keyword = "union"
    default:
      failed = true
      return nil
    }

    guard let name = demangleQualifiedName() else { return nil }
    return keyword + " " + name.joined(separator: "::")
  }

  func demangleEnumType() -> String? {
    guard let name = demangleQualifiedName() else { return nil }
    return "enum " + name.joined(separator: "::")
  }

  // MARK: - Function Type

  func demangleFunctionSignatureType() -> String? {
    guard let callingConv = demangleCallingConvention() else { return nil }
    guard let retType = demangleType(isParameter: false) else { return nil }
    guard let params = demangleParameterList() else { return nil }
    return "\(retType) \(callingConv)(\(params))"
  }

  func demangleFunctionReferenceType() -> String? {
    // $$A6 or $$A8 in templates for function type parameters
    if let c = peek(), c == "6" {
      advance()
      return demangleFunctionSignatureType()
    }
    if let c = peek(), c == "8" {
      // member function type — bail
      return nil
    }
    return nil
  }

  // MARK: - Array Types

  func demangleArrayType() -> String? {
    // Rank (number of dimensions)
    guard let rank = demangleNumber() else { return nil }

    var dims: [Int64] = []
    for _ in 0..<rank {
      guard let dim = demangleNumber() else { return nil }
      dims.append(dim)
    }

    guard let elementType = demangleType(isParameter: false) else { return nil }

    let dimStr = dims.map { "[\($0)]" }.joined()
    return elementType + dimStr
  }

  // MARK: - Parameter Lists

  func demangleParameterList() -> String? {
    var params: [String] = []

    while let c = peek() {
      if c == "@" {
        advance()
        break
      }
      if c == "Z" {
        advance()
        if params.isEmpty {
          // Z alone = end of encoding for void params
          break
        }
        params.append("...")
        break
      }
      if c == "X" {
        advance()
        // void parameter list
        break
      }

      guard let paramType = demangleType(isParameter: true) else { return nil }
      params.append(paramType)
    }

    if params.isEmpty {
      return "void"
    }
    return params.joined(separator: ",")
  }

  // MARK: - Qualifiers

  struct Qualifiers {
    var isConst: Bool = false
    var isVolatile: Bool = false
  }

  func demangleQualifierCode() -> Qualifiers {
    guard let c = peek() else { return Qualifiers() }
    switch c {
    case "A", "Q":
      advance()
      return Qualifiers()
    case "B", "R":
      advance()
      return Qualifiers(isConst: true)
    case "C", "S":
      advance()
      return Qualifiers(isVolatile: true)
    case "D", "T":
      advance()
      return Qualifiers(isConst: true, isVolatile: true)
    default:
      return Qualifiers()
    }
  }

  func qualifiersString(_ quals: Qualifiers) -> String {
    switch (quals.isConst, quals.isVolatile) {
    case (true, true): return "const volatile"
    case (true, false): return "const"
    case (false, true): return "volatile"
    case (false, false): return ""
    }
  }

  func applyQualifiers(_ quals: Qualifiers, to type: String) -> String {
    let q = qualifiersString(quals)
    if q.isEmpty { return type }
    return q + " " + type
  }

  // MARK: - Type Back-References

  func memorizeTypeBackref(_ typeStr: String) {
    guard typeBackrefs.count < 10 else { return }
    if !typeBackrefs.contains(typeStr) {
      typeBackrefs.append(typeStr)
    }
  }

  func resolveTypeBackref(_ idx: Int) -> String? {
    guard idx < typeBackrefs.count else {
      failed = true
      return nil
    }
    return typeBackrefs[idx]
  }
}
