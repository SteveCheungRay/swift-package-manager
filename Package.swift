/*
 This source file is part of the Swift.org open source project

 Copyright 2015 - 2016 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import PackageDescription

let package = Package(
    name: "SwiftPM",
    
    /**
     The following is parsed by our bootstrap script, so
     if you make changes here please check the bootstrap still
     succeeds! Thanks.
    */
    targets: [
        // The `PackageDescription` module is special, it defines the API which
        // is available to the `Package.swift` manifest files.
        Target(
            /** Package Definition API */
            name: "PackageDescription",
            dependencies: []),

        // MARK: Support libraries
        
        Target(
            /** Cross-platform access to bare `libc` functionality. */
            name: "libc",
            dependencies: []),
        Target(
            /** “Swifty” POSIX functions from libc */
            name: "POSIX",
            dependencies: ["libc"]),
        Target(
            /** Basic support library */
            name: "Basic",
            dependencies: ["libc", "POSIX"]),
        Target(
            /** Abstractions for common operations, should migrate to Basic */
            name: "Utility",
            dependencies: ["POSIX", "Basic", "PackageDescription"]),
            // FIXME: We should kill the PackageDescription dependency above.
        Target(
            /** Source control operations */
            name: "SourceControl",
            dependencies: ["Basic", "Utility"]),

        // MARK: Project Model
        
        Target(
            /** Primitive Package model objects */
            name: "PackageModel",
            dependencies: ["Basic", "PackageDescription", "Utility"]),
        Target(
            /** Package model conventions and loading support */
            name: "PackageLoading",
            dependencies: ["Basic", "PackageDescription", "PackageModel"]),

        // MARK: Package Dependency Resolution
        
        Target(
            /** Fetches Packages and their dependencies */
            name: "Get",
            dependencies: ["Basic", "PackageDescription", "PackageModel", "PackageLoading"]),
        Target(
            /** Data structures and support for complete package graphs */
            name: "PackageGraph",
            dependencies: ["Basic", "PackageLoading", "PackageModel", "SourceControl", "Utility"]),
        
        // MARK: Package Manager Functionality
        
        Target(
            /** Builds Modules and Products */
            name: "Build",
            dependencies: ["Basic", "PackageGraph"]),
        Target(
            /** Generates Xcode projects */
            name: "Xcodeproj",
            dependencies: ["Basic", "PackageGraph"]),

        // MARK: Commands
        
        Target(
            /** High-level commands */
            name: "Commands",
            dependencies: ["Basic", "Build", "Get", "PackageGraph", "SourceControl", "Xcodeproj"]),
        Target(
            /** The main executable provided by SwiftPM */
            name: "swift-package",
            dependencies: ["Commands"]),
        Target(
            /** Builds packages */
            name: "swift-build",
            dependencies: ["Commands"]),
        Target(
            /** Runs package tests */
            name: "swift-test",
            dependencies: ["Commands"]),
        Target(
            /** Shim tool to find test names on OS X */
            name: "swiftpm-xctest-helper",
            dependencies: []),

        // MARK: Additional Test Dependencies

        Target(
            /** Test support library */
            name: "TestSupport",
            dependencies: ["Basic", "POSIX", "PackageGraph", "PackageLoading", "SourceControl", "Utility"]),
        Target(
            /** Test support executable */
            name: "TestSupportExecutable",
            dependencies: ["Basic", "POSIX", "Utility"]),
        
        Target(
            name: "BasicTests",
            dependencies: ["TestSupport", "TestSupportExecutable"]),
        Target(
            name: "BasicPerformanceTests",
            dependencies: ["Basic"]),
        Target(
            name: "BuildTests",
            dependencies: ["Build", "TestSupport"]),
        Target(
            name: "CommandsTests",
            dependencies: ["Commands", "TestSupport"]),
        Target(
            name: "FunctionalTests",
            dependencies: ["Basic", "Utility", "PackageModel", "TestSupport"]),
        Target(
            name: "GetTests",
            dependencies: ["Get", "TestSupport"]),
        Target(
            name: "PackageLoadingTests",
            dependencies: ["PackageLoading", "TestSupport"]),
        Target(
            name: "PackageLoadingPerformanceTests",
            dependencies: ["PackageLoading", "TestSupport"]),
        Target(
            name: "PackageGraphTests",
            dependencies: ["PackageGraph", "TestSupport"]),
        Target(
            name: "PackageGraphPerformanceTests",
            dependencies: ["PackageGraph", "TestSupport"]),
        Target(
            name: "POSIXTests",
            dependencies: ["POSIX", "TestSupport"]),
        Target(
            name: "SourceControlTests",
            dependencies: ["SourceControl", "TestSupport"]),
        Target(
            name: "UtilityTests",
            dependencies: ["Utility", "TestSupport"]),
        Target(
            name: "XcodeprojTests",
            dependencies: ["Xcodeproj", "TestSupport"]),
    ],
    exclude: [
        "Tests/PackageLoadingTests/Inputs",
    ]
)


// The executable products are automatically determined by SwiftPM; any module
// that contains a `main.swift` source file results in an implicit executable
// product.


// Runtime Library -- contains the package description API itself
products.append(
    Product(
        name: "PackageDescription",
        type: .Library(.Dynamic),
        modules: ["PackageDescription"]
    )
)


// SwiftPM Library -- provides package management functionality to clients
products.append(
    Product(
        name: "SwiftPM",
        type: .Library(.Dynamic),
        modules: ["libc", "POSIX", "Basic", "Utility", "SourceControl", "PackageDescription", "PackageModel", "PackageLoading", "Get", "PackageGraph", "Build", "Xcodeproj"]
    )
)
