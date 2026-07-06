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

@_spi(SymbolLocation) import Runtime
@_spi(Utils) import Runtime

@_spi(SymbolLocation)
extension SymbolLoader.Image {
  var id: String {
    guard let uuid else {
      return ""
    }

    return hex(uuid)
  }
}
