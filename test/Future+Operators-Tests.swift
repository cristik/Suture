// Copyright (c) 2018-2019, Cristian Kocza
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
        Future<Int, FutureTestsError> { resolver in
            executionCount += 1
            resolver(.failure(.first))
            return Subscription()
            }.retry(3).subscribe()
        XCTAssertEqual(executionCount, 3)
    }
    
    func test_retry_cancelsTheFirstAttemptIfNotStarted() {
        var cancelled = false
        let subscription = Future<Int, FutureTestsError> { _ in return Subscription { cancelled = true } }
            .retry(5)
            .subscribe()
        subscription.cancel()
        XCTAssertTrue(cancelled)
    }
    
    func test_retry_cancelsTheSecondAttemptIfTheFirstFailed() {
        var subscribers = [Future<Int, FutureTestsError>.Subscriber]()
        var subscriptions = Array(repeatElement(false, count: 5))
        let subscription = Future<Int, FutureTestsError> { subscribers.append($0); return Subscription { subscriptions[subscribers.count-1] = true } }
            .retry(5)
            .subscribe()
        subscribers[0](.failure(.first))
        subscription.cancel()
        XCTAssertFalse(subscriptions[0])
        XCTAssertTrue(subscriptions[1])
        XCTAssertFalse(subscriptions[2])
    }
    
    func test_map_reportsValue_onSuccess() {
        var result: Result<String, FutureTestsError>?
        Future.success(2).map { String($0) }.subscribe {
            result = $0
        }
        XCTAssertEqual(result, .success("2"))
    }
    
    func test_reuse_doesntExecuteTheWorkerMultipleTimes() {
        var count = 0
        let future = Future<Int, FutureTestsError> { count += 1; $0(.success(count)); return .init() }.keep()
        future.subscribe()
        future.map { $0 * 2 }.subscribe()
        future.subscribe()
        XCTAssertEqual(count, 1)
    }
    
    func test_reuse_returnsTheValueOfTheFirstComputation() {
        var count = 0
        var results = [Result<Int, FutureTestsError>]()
        let future = Future<Int, FutureTestsError> { count += 1; $0(.success(count)); return .init() }.keep()
        future.subscribe { results.append($0) }
        future.subscribe { results.append($0) }
        future.subscribe { results.append($0) }
        XCTAssertEqual(results, [.success(1), .success(1), .success(1)])
    }
    
    func test_flatMap_doesntStartTheChainIfNotSubscribed() {
        var started = false
        let future = Future<Int, FutureTestsError> { _ in started = true; return Subscription() }
            .flatMap { .success("\($0)") }
        XCTAssertFalse(started)
        future.subscribe()
        XCTAssertTrue(started)
    }
    
    func test_flatMap_recoversIfOriginalFails() {
        var value: Result<Int, FutureTestsError>?
        Future<Int, FutureTestsError>.failure(.first)
            .flatMapFailure { _ in .success(12) }
            .subscribe { value = $0 }
        XCTAssertEqual(value, .success(12))
    }
    
    func test_flatMap_failsIfSecondFails() {
        var error: Result<String, FutureTestsError>?
        Future<Int, FutureTestsError>.success(97)
            .flatMap { _ in Future<String, FutureTestsError>.failure(.second) }
            .subscribe { error = $0 }
        XCTAssertEqual(error, .failure(.second))
    }
    
    func test_flatMap_reportSecondsValue() {
        var value: Result<String, FutureTestsError>?
        Future<Int, FutureTestsError>.success(99)
            .flatMap { .success("\($0)") }
            .subscribe { value = $0 }
        XCTAssertEqual(value, .success("99"))
    }
    
    func test_flatMap_cancelsTheOriginal() {
        var cancelled = false
        let subscription = Future<Int, FutureTestsError> { _ in Subscription { cancelled = true } }
            .flatMap { .success("\($0)") }
            .subscribe()
        XCTAssertFalse(cancelled)
        subscription.cancel()
        XCTAssertTrue(cancelled)
    }
}
