// swift-tools-version: 6.2

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

// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var products: [PackageDescription.Product] =
  [
    .executable(
      name: "swift-symbolicate",
      targets: ["swift-symbolicate"]
    ),
    .executable(
      name: "crashMe",
      targets: ["crashMe"]
    ),
    .executable(
      name: "crashMeOpenFds",
      targets: ["crashMeOpenFds"]
    ),
    .library(name: "Minidump", targets: ["Minidump"]),
    .library(name: "MSVCNameDemangler", targets: ["MSVCNameDemangler"]),
    .library(
      name: "SwiftSymbolicate", type: .dynamic,
      targets: [
        "SwiftSymbolicate"
      ]),
  ]

var targets: [PackageDescription.Target] =
  [
    .target(
      name: "Minidump"
    ),
    .target(
      name: "MSVCNameDemangler",
      swiftSettings: [
        .interoperabilityMode(.Cxx)
      ]
    ),
    .target(
      name: "SwiftSymbolicate",
      dependencies: ["Minidump", "MSVCNameDemangler"],
      swiftSettings: [
        .interoperabilityMode(.Cxx)
      ]
    ),
    .executableTarget(
      name: "swift-symbolicate",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "SwiftSymbolicate",
      ],
      swiftSettings: [
        .interoperabilityMode(.Cxx)
      ]
    ),
    .executableTarget(
      name: "crashMe"
    ),
    .executableTarget(
      name: "crashMeOpenFds"
    ),
  ]

products.append(
  .executable(
    name: "crashMeMultithreaded",
    targets: ["crashMeMultithreaded"]
  )
)

targets.append(contentsOf: [
  .target(
    name: "CxxCrashHelper",
    publicHeadersPath: "include"
  ),
  .executableTarget(
    name: "crashMeMultithreaded",
    dependencies: ["CxxCrashHelper"]
  ),
])

#if os(Windows)
  products.append(
    .executable(
      name: "index-pdb-files",
      targets: ["index-pdb-files"]
    )
  )
  targets.append(
    .executableTarget(
      name: "index-pdb-files",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "SwiftSymbolicate",
      ],
      swiftSettings: [
        .interoperabilityMode(.Cxx),
      ],
    )
  )
#endif

#if os(macOS) || os(Linux)
  let testTargetDeps: [PackageDescription.Target.Dependency] =
    [
      "swift-symbolicate",
      .target(name: "SwiftSymbolicate"),
      "crashMe",
      "crashMeOpenFds",
      "crashMeMultithreaded",
      .product(name: "Subprocess", package: "swift-subprocess"),
    ]
#elseif os(Windows)
  let testTargetDeps: [PackageDescription.Target.Dependency] =
    [
      "swift-symbolicate",
      .target(name: "SwiftSymbolicate"),
      "crashMe",
      "crashMeMultithreaded",
      .product(name: "Subprocess", package: "swift-subprocess"),
    ]
#endif

let testTarget: PackageDescription.Target =
  .testTarget(
    name: "swift-symbolicateTests",
    dependencies: testTargetDeps,
    swiftSettings: [
      .interoperabilityMode(.Cxx)
    ]
  )

targets.append(testTarget)

let package = Package(
  name: "swift-symbolicate",
  platforms: [
    .macOS(.v26)
  ],
  products: products,
  traits: [
    .trait(name: "TestSymbolicating"),
    .trait(name: "TestGeneral"),
    .trait(name: "TestIntegrations"),
    .trait(name: "DebuggingSymbolicator"),
    .trait(name: "DebugStandardLibrary"),
    .trait(name: "Betax86Registers"),
    .default(enabledTraits: ["TestSymbolicating", "TestGeneral"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    .package(
      url: "https://github.com/swiftlang/swift-subprocess.git", branch: "main",
      traits: ["SubprocessFoundation"]),
  ],
  targets: targets
)
