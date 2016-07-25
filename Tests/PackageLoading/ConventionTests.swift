/*
 This source file is part of the Swift.org open source project

 Copyright 2015 - 2016 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest

import Basic
import PackageDescription
import PackageModel
import Utility

@testable import PackageLoading

/// Tests for the handling of source layout conventions.
class ConventionTests: XCTestCase {
    /// Parse the given test files according to the conventions, and check the result.
    private func test<T: Module>(files: [RelativePath], file: StaticString = #file, line: UInt = #line, body: (T) throws -> ()) {
        do {
            try fixture(files: files) { (package, modules) in 
                XCTAssertEqual(modules.count, 1)
                guard let module = modules.first as? T else { XCTFail(file: #file, line: line); return }
                XCTAssertEqual(module.name, package.name)
                do {
                    try body(module)
                } catch {
                    XCTFail("\(error)", file: file, line: line)
                }
            }
        } catch {
            XCTFail("\(error)", file: file, line: line)
        }
    }
    
    func testDotFilesAreIgnored() throws {
        do {
            try fixture(files: [ RelativePath(".Bar.swift"), RelativePath("Foo.swift") ]) { (package, modules) in
                XCTAssertEqual(modules.count, 1)
                guard let swiftModule = modules.first as? SwiftModule else { return XCTFail() }
                XCTAssertEqual(swiftModule.sources.paths.count, 1)
                XCTAssertEqual(swiftModule.sources.paths.first?.basename, "Foo.swift")
                XCTAssertEqual(swiftModule.name, package.name)
            }
        } catch {
            XCTFail("\(error)")
        }
    }

    func testResolvesSingleSwiftModule() throws {
        let files = [ RelativePath("Foo.swift") ]
        test(files: files) { (module: SwiftModule) in 
            XCTAssertEqual(module.sources.paths.count, files.count)
            XCTAssertEqual(Set(module.sources.relativePaths), Set(files))
        }
    }

    func testResolvesSystemModulePackage() throws {
        test(files: [ RelativePath("module.modulemap") ]) { module in }
    }

    func testResolvesSingleClangModule() throws {
        test(files: [ RelativePath("Foo.c"), RelativePath("Foo.h") ]) { module in }
    }

    func testMixedSources() throws {
        var fs = InMemoryFileSystem()
        try fs.createEmptyFiles("/Sources/main.swift",
                                "/Sources/main.c")
        PackageBuilderTester(.root, in: fs) { result in
            result.checkError("the module at /Sources contains mixed language source files fix: use only a single language within a module")
        }
    }

    func testTwoModulesMixedLanguage() throws {
        var fs = InMemoryFileSystem()
        try fs.createEmptyFiles("/Sources/ModuleA/main.swift",
                                "/Sources/ModuleB/main.c",
                                "/Sources/ModuleB/foo.c")

        PackageBuilderTester(.root, in: fs) { result in
            result.checkModule("ModuleA") { moduleResult in
                moduleResult.check(c99name: "ModuleA", type: .executable)
                moduleResult.check(isTest: false)
                moduleResult.checkSources(root: "/Sources/ModuleA", paths: "main.swift")
            }

            result.checkModule("ModuleB") { moduleResult in
                moduleResult.check(c99name: "ModuleB", type: .executable, isTest: false)
                moduleResult.checkSources(root: "/Sources/ModuleB")
                moduleResult.checkSources(paths: "main.c", "foo.c")
            }
        }
    }

    static var allTests = [
        ("testDotFilesAreIgnored", testDotFilesAreIgnored),
        ("testResolvesSingleSwiftModule", testResolvesSingleSwiftModule),
        ("testResolvesSystemModulePackage", testResolvesSystemModulePackage),
        ("testResolvesSingleClangModule", testResolvesSingleClangModule),
        ("testMixedSources", testMixedSources),
        ("testTwoModulesMixedLanguage", testTwoModulesMixedLanguage),
    ]
}

/// Create a test fixture with empty files at the given paths.
private func fixture(files: [RelativePath], body: @noescape (AbsolutePath) throws -> ()) {
    mktmpdir { prefix in
        try makeDirectories(prefix)
        for file in files {
            try system("touch", prefix.appending(file).asString)
        }
        try body(prefix)
    }
}

/// Check the behavior of a test project with the given file paths.
private func fixture(files: [RelativePath], file: StaticString = #file, line: UInt = #line, body: @noescape (PackageModel.Package, [Module]) throws -> ()) throws {
    fixture(files: files) { (prefix: AbsolutePath) in
        let manifest = Manifest(path: prefix.appending(component: "Package.swift"), url: prefix.asString, package: Package(name: "name"), products: [], version: nil)
        let package = try PackageBuilder(manifest: manifest, path: prefix).construct(includingTestModules: false)
        try body(package, package.modules)
    }
}

// FIXME: These test Utilities can/should be moved to test-specific library when we start supporting them.
private extension FileSystem {
    /// Create a file on the filesystem while recursively creating the parent directory tree.
    ///
    /// - Parameters:
    ///     - file: Path of the file to create.
    ///     - contents: Contents of the file. Empty by default.
    ///
    /// - Throws: FileSystemError
    mutating func create(_ file: AbsolutePath, contents: ByteString = ByteString()) throws {
        // Auto create the tree.
        try createDirectory(file.parentDirectory, recursive: true)
        try writeFileContents(file, bytes: contents)
    }

    /// Create multiple empty files on the filesystem while recursively creating the parent directory tree.
    ///
    /// - Parameters:
    ///     - files: Paths of empty files to create.
    ///
    /// - Throws: FileSystemError
    mutating func createEmptyFiles(_ files: String ...) throws {
        // Auto create the tree.
        for filePath in files {
            let file = AbsolutePath(filePath)
            try createDirectory(file.parentDirectory, recursive: true)
            try writeFileContents(file, bytes: ByteString())
        }
    }
}

/// Loads a package using PackageBuilder at the given path. If package description is provided it is used,
/// otherwise a default package with name of directory is passed to manifest.
///
/// - Parameters:
///     - path: Directory where the package is located.
///     - in: FileSystem in which the package should be loaded from.
///     - package: PackageDescription instance to use for loading this package.
///
/// - Throws: ModuleError, ProductError
private func loadPackage(_ path: AbsolutePath, in fs: FileSystem, package: PackageDescription.Package? = nil) throws -> PackageModel.Package {
    let pkg: PackageDescription.Package
    if let package = package {
        pkg = package
    } else {
        pkg = Package(name: path.basename)
    }
    let manifest = Manifest(path: path.appending(component: Manifest.filename), url: "", package: pkg, products: [], version: nil)
    let builder = PackageBuilder(manifest: manifest, path: path, fileSystem: fs)
    return try builder.construct(includingTestModules: true)
}

extension PackageModel.Package {
    var allModules: [Module] {
        return modules + testModules
    }
}

final class PackageBuilderTester {
    private enum Result {
        case package(PackageModel.Package)
        case error(String)
    }

    /// Contains the result produced by PackageBuilder.
    private let result: Result

    /// Contains the diagnostics which have not been checked yet.
    private var uncheckedDiagnostics = Set<String>()

    /// Setting this to true will disable checking for any unchecked diagnostics prodcuted by PackageBuilder during loading process.
    var ignoreDiagnostics: Bool = false

    /// Contains the modules which have not been checked yet.
    private var uncheckedModules = Set<Module>()

    /// Setting this to true will disable checking for any unchecked module.
    var ignoreOtherModules: Bool = false

    @discardableResult
    init(_ path: AbsolutePath, in fs: FileSystem, package: PackageDescription.Package? = nil, file: StaticString = #file, line: UInt = #line, _ body: @noescape (PackageBuilderTester) -> Void) {
        do {
            let loadedPackage = try loadPackage(path, in: fs, package: package)
            result = .package(loadedPackage)
            uncheckedModules = Set(loadedPackage.allModules)
        } catch {
            let errorStr = String(error)
            result = .error(errorStr)
            // FIXME: We need to extend dianostics to load warnings too.
            // Right now warnings are dumped directly to stdout, we can use OutputByteStream
            // instead to write warnings to a stream and then capture them for testing.
            uncheckedDiagnostics.insert(errorStr)
        }
        body(self)
        validateDiagnostics(file: file, line: line)
        validateCheckedModules(file: file, line: line)
    }

    private func validateDiagnostics(file: StaticString, line: UInt) {
        guard !ignoreDiagnostics && !uncheckedDiagnostics.isEmpty else { return }
        XCTFail("Unchecked diagnostics: \(uncheckedDiagnostics)", file: file, line: line)
    }

    private func validateCheckedModules(file: StaticString, line: UInt) {
        guard !ignoreOtherModules && !uncheckedModules.isEmpty else { return }
        XCTFail("Unchecked modules: \(uncheckedModules)", file: file, line: line)
    }

    func checkError(_ str: String, file: StaticString = #file, line: UInt = #line) {
        switch result {
        case .package(let package):
            XCTFail("\(package) did not have any error", file: file, line: line)
        case .error(let error):
            uncheckedDiagnostics.remove(error)
            XCTAssertEqual(error, str, file: file, line: line)
        }
    }

    func checkModule(_ name: String, file: StaticString = #file, line: UInt = #line, _ body: (@noescape (ModuleResult) -> Void)? = nil) {
        guard case .package(let package) = result else {
            return XCTFail("Expected package did not load \(self)", file: file, line: line)
        }
        guard let module = package.allModules.first(where: {$0.name == name}) else {
            return XCTFail("Module: \(name) not found", file: file, line: line)
        }
        uncheckedModules.remove(module)
        body?(ModuleResult(module))
    }

    final class ModuleResult {
        private let module: Module
        private lazy var sources: Set<RelativePath> = { Set(self.module.sources.relativePaths) }()

        private init(_ module: Module) {
            self.module = module
        }

        func check(c99name: String? = nil, type: ModuleType? = nil, isTest: Bool? = nil, file: StaticString = #file, line: UInt = #line) {
            if let c99name = c99name {
                XCTAssertEqual(module.c99name, c99name, file: file, line: line)
            }
            if let type = type {
                XCTAssertEqual(module.type, type, file: file, line: line)
            }
            if let isTest = isTest {
                XCTAssertEqual(module.isTest, isTest, file: file, line: line)
            }
        }

        func checkSources(root: String? = nil, paths: String..., file: StaticString = #file, line: UInt = #line) {
            if let root = root {
                XCTAssertEqual(module.sources.root, AbsolutePath(root), file: file, line: line)
            }
            for path in paths {
                XCTAssert(sources.contains(RelativePath(path)), "\(path) not found in module \(module.name)", file: file, line: line)
            }
        }
    }
}
