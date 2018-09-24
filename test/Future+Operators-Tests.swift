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

final class FutureOperatorsTests: XCTestCase {
    func test_retrying_executesWorkerTheSpecifiedAmountOfTimes() {
        var executionCount = 0
        Future<Int> { resolver in
            executionCount += 1
            resolver(.error(FutureTestsError.first))
            return Cancelable()
            }.retry(3).subscribe()
        XCTAssertEqual(executionCount, 3)
    }
    
    func test_retry_cancelsTheFirstAttemptIfNotStarted() {
        var cancelled = false
        let subscription = Future<Int> { _ in return Cancelable { cancelled = true } }
            .retry(5)
            .subscribe()
        subscription.cancel()
        XCTAssertTrue(cancelled)
    }
    
    func test_retry_cancelsTheSecondAttemptIfTheFirstFailed() {
        var resolvers = [Future<Int>.Resolver]()
        var cancellations = Array(repeatElement(false, count: 5))
        let subscription = Future<Int> { resolvers.append($0); return Cancelable { cancellations[resolvers.count-1] = true } }
            .retry(5)
            .subscribe()
        resolvers[0](.error(FutureTestsError.first))
        subscription.cancel()
        XCTAssertFalse(cancellations[0])
        XCTAssertTrue(cancellations[1])
        XCTAssertFalse(cancellations[2])
    }
    
    func test_map_reportsValue_onSuccess() {
        var result: String?
        Future.value(2).mapValue     { String($0) }.await {
            result = $0.value
        }
        XCTAssertEqual(result, "2")
    }
    
    func test_reuse_doesntExecuteTheWorkerMultipleTimes() {
        var count = 0
        let future = Future<Int> { count += 1; $0(.value(count)); return .init() }.keep()
        future.subscribe()
        future.map { $0.map { $0 * 2} }.subscribe()
        future.subscribe()
        XCTAssertEqual(count, 1)
    }
    
    func test_reuse_returnsTheValueOfTheFirstComputation() {
        var count = 0
        var results = [Int?]()
        let future = Future<Int> { count += 1; $0(.value(count)); return .init() }.keep()
        future.await { results.append($0.value) }
        future.map { $0.map { $0 * 2} }.await { results.append($0.value) }
        future.await { results.append($0.value) }
        XCTAssertEqual(results, [.some(1), .some(2), .some(1)])
    }
    
    func test_flatMap_doesntStartTheChainIfNotSubscribed() {
        var started = false
        let future = Future<Int> { _ in started = true; return Cancelable() }
            .flatMap { .value("\($0)") }
        XCTAssertFalse(started)
        future.subscribe()
        XCTAssertTrue(started)
    }
    
    func test_flatMap_recoversIfOriginalFails() {
        var value: String?
        Future<Int>.error(FutureTestsError.first)
            .flatMap { _ in .value("12") }
            .await { value = $0.value }
        XCTAssertEqual(value, "12")
    }
    
    func test_flatMap_failsIfSecondFails() {
        var error: FutureTestsError?
        Future<Int>.value(97)
            .flatMap { _ in Future<String>.error(FutureTestsError.second) }
            .await { error = $0.error as? FutureTestsError }
        XCTAssertEqual(error, .second)
    }
    
    func test_flatMap_reportSecondsValue() {
        var value: String?
        Future<Int>.value(99)
            .flatMap { .value("\($0.value!)") }
            .await { value = $0.value }
        XCTAssertEqual(value, "99")
    }
    
    func test_flatMap_cancelsTheOriginal() {
        var cancelled = false
        let subscription = Future<Int> { _ in Cancelable { cancelled = true } }
            .flatMap { .value("\($0)") }
            .subscribe()
        XCTAssertFalse(cancelled)
        subscription.cancel()
        XCTAssertTrue(cancelled)
    }
}
