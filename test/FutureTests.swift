//
//  SwiftFutureTests.swift
//  SwiftFutureTests
//
//  Created by Cristian Kocza on 09/08/2018.
//  Copyright © 2018 cristik. All rights reserved.
//

import XCTest
@testable import SwiftFuture

enum FutureTestsError: Error {
    case one
}

class FutureTests: XCTestCase {
    
    func test_init_doesntStartWorkRightAway() {
        var executed = false
        _ = Future<Void> { _ in
            executed = true            
        }
        XCTAssertFalse(executed)
    }
    
    func test_subscribe_startsWorkingOnFirstSubscribe() {
        var executed = false
        let future = Future<Void> { _ in
            executed = true
        }
        _ = future.subscribe { _ in }
        XCTAssertTrue(executed)
    }
    
    func test_subscribe_executesWorkerOnlyOnce() {
        var executeCount = 0
        let future = Future<Void> { _ in
            executeCount += 1
        }
        _ = future.subscribe { _ in }
        _ = future.subscribe { _ in }
        XCTAssertEqual(executeCount, 1)
    }
    
    func test_retrying_executesWorkerTheSpecifiedAmountOfTimes() {
        var executionCount = 0
        Future<Int>.retrying(3) { executionCount += 1; $0(.error(FutureTestsError.one)) }.subscribe { _ in }
        XCTAssertEqual(executionCount, 3)
    }
}
