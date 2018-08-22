// Copyright (c) 2018, Cristian Kocza
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER
// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
// OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import XCTest
@testable import Suture

enum FutureTestsError: Error {
    case one
}

class FutureTests: XCTestCase {
    
    func test_init_doesntStartWorkRightAway() {
        var executed = false
        _ = Future<Void> { _ in
            executed = true; return Subscription()
        }
        XCTAssertFalse(executed)
    }
    
    func test_subscribe_startsWorkingOnFirstSubscribe() {
        var executed = false
        let future = Future<Void> { _ in
            executed = true; return Subscription()
        }
        _ = future.subscribe { _ in }
        XCTAssertTrue(executed)
    }
    
    func test_subscribe_executesWorkerEachSubscription() {
        var executeCount = 0
        let future = Future<Void> { _ in
            executeCount += 1; return Subscription()
        }
        _ = future.subscribe { _ in }
        _ = future.subscribe { _ in }
        XCTAssertEqual(executeCount, 2)
    }
    
    func test_retrying_executesWorkerTheSpecifiedAmountOfTimes() {
        var executionCount = 0
        Future<Int> { resolver in
            executionCount += 1
            resolver(.error(FutureTestsError.one))
            return Subscription()
            }.retrying(3).subscribe()
        XCTAssertEqual(executionCount, 3)
    }
    
    func test_map_reportsValue_onSuccess() {
        var result: String?
        Future.value(2).map(map(String.init)).subscribe {
            result = $0.value
        }
        XCTAssertEqual(result, "2")
    }
    
    func test_cancel_cancelsChain() {
        var canceled = false
        let subscription = Future<Int> { _ in
            return Subscription { canceled = true }
            }.mapValue { $0 * 2 }.mapError { _ in return 2 }.subscribe()
        XCTAssertFalse(canceled)
        subscription.cancel()
        XCTAssertTrue(canceled)
    }
    
    func test_reuse_doesntExecuteTheWorkerMultipleTimes() {
        var count = 0
        let future = Future<Int> { count += 1; $0(.value(count)); return .init() }.reuse()
        future.subscribe()
        future.map { $0.map { $0 * 2} }.subscribe()
        future.subscribe()
        XCTAssertEqual(count, 1)
    }
    
    func test_reuse_returnsTheValueOfTheFirstComputation() {
        var count = 0
        var results = [Int?]()
        let future = Future<Int> { count += 1; $0(.value(count)); return .init() }.reuse()
        future.subscribe { results.append($0.value) }
        future.map { $0.map { $0 * 2} }.subscribe { results.append($0.value) }
        future.subscribe { results.append($0.value) }
        XCTAssertEqual(results, [.some(1), .some(2), .some(1)])
    }
}
