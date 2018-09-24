// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Suture",
    products: [.library(name: "Suture", targets: ["Suture"])],
    dependencies: [],
    targets: [
        .target(name: "Suture", path: "src"),
        .testTarget(name: "SutureTests", dependencies: ["Suture"], path: "test")
    ])