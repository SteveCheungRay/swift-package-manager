/*
 This source file is part of the Swift.org open source project

 Copyright 2015 - 2016 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest

import Basic
import POSIX
import Utility

#if os(macOS)
import class Foundation.Bundle
#endif

public func XCTAssertBuilds(_ path: AbsolutePath, configurations: Set<Configuration> = [.Debug, .Release], file: StaticString = #file, line: UInt = #line, Xcc: [String] = [], Xld: [String] = [], Xswiftc: [String] = [], env: [String: String] = [:]) {
    for conf in configurations {
        do {
            print("    Building \(conf)")
            _ = try executeSwiftBuild(path, configuration: conf, printIfError: true, Xcc: Xcc, Xld: Xld, Xswiftc: Xswiftc, env: env)
        } catch {
            XCTFail("`swift build -c \(conf)' failed:\n\n\(error)\n", file: file, line: line)
        }
    }
}

public func XCTAssertSwiftTest(_ path: AbsolutePath, file: StaticString = #file, line: UInt = #line, env: [String: String] = [:]) {
    do {
        _ = try SwiftPMProduct.SwiftTest.execute([], chdir: path, env: env, printIfError: true)
    } catch {
        XCTFail("`swift test' failed:\n\n\(error)\n", file: file, line: line)
    }
}

public func XCTAssertBuildFails(_ path: AbsolutePath, file: StaticString = #file, line: UInt = #line, Xcc: [String] = [], Xld: [String] = [], Xswiftc: [String] = [], env: [String: String] = [:]) {
    do {
        _ = try executeSwiftBuild(path, Xcc: Xcc, Xld: Xld, Xswiftc: Xswiftc)

        XCTFail("`swift build' succeeded but should have failed", file: file, line: line)

    } catch SwiftPMProductError.executionFailure(let error, _) {
        switch error {
        case POSIX.Error.exitStatus(let status, _) where status == 1: break
            // noop
        default:
        XCTFail("`swift build' failed in an unexpected manner")
        }
    } catch {
        XCTFail("`swift build' failed in an unexpected manner")
    }
}

public func XCTAssertFileExists(_ path: AbsolutePath, file: StaticString = #file, line: UInt = #line) {
    if !isFile(path) {
        XCTFail("Expected file doesn’t exist: \(path.asString)", file: file, line: line)
    }
}

public func XCTAssertDirectoryExists(_ path: AbsolutePath, file: StaticString = #file, line: UInt = #line) {
    if !isDirectory(path) {
        XCTFail("Expected directory doesn’t exist: \(path.asString)", file: file, line: line)
    }
}

public func XCTAssertNoSuchPath(_ path: AbsolutePath, file: StaticString = #file, line: UInt = #line) {
    if exists(path) {
        XCTFail("path exists but should not: \(path.asString)", file: file, line: line)
    }
}

public func XCTAssertThrows<T: Swift.Error>(_ expectedError: T, file: StaticString = #file, line: UInt = #line, _ body: () throws -> ()) where T: Equatable {
    do {
        try body()
        XCTFail("body completed successfully", file: file, line: line)
    } catch let error as T {
        XCTAssertEqual(error, expectedError, file: file, line: line)
    } catch {
        XCTFail("unexpected error thrown", file: file, line: line)
    }
}

