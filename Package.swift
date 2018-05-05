// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Bits",
  products: [
    .library(name: "Bits", targets: ["Bits"])
  ],
  targets: [
    .target(name: "Bits", path: "Sources"),
    .testTarget(name: "BitsTests", dependencies: ["Bits"], path: "Tests")
  ],
  swiftLanguageVersions: [4]
)
