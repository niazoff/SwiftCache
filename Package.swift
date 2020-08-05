// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "SwiftCache",
  products: [
    .library(
      name: "SwiftCache",
      targets: ["SwiftCache"]),
  ],
  targets: [
    .target(
      name: "SwiftCache",
      dependencies: []),
    .testTarget(
      name: "SwiftCacheTests",
      dependencies: ["SwiftCache"]),
  ]
)
