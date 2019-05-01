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

final class FutureSubscribeTests: XCTestCase {
    func test_subscribe_startsWorkingOnlyOnSubscribe() {
        var executed = false
        let future = Future<Void, FutureTestsError> { _ in
            executed = true; return Cancelable()
        }
        XCTAssertFalse(executed)
        _ = future.get { _ in }
        XCTAssertTrue(executed)
    }
    
    func test_subscribe_executesWorkerEachSubscription() {
        var executeCount = 0
        let future = Future<Void, FutureTestsError> { _ in
            executeCount += 1; return Cancelable()
        }
        _ = future.get { _ in }
        _ = future.get { _ in }
        XCTAssertEqual(executeCount, 2)
    }
    
    func test_cancel_cancelsChain() {
        var canceled = false
        let subscription = Future<Int, FutureTestsError> { _ in
            return Cancelable { canceled = true }
            }.mapSuccess { $0 * 2 }.mapFailure { _ in return 2 }.get()
        XCTAssertFalse(canceled)
        subscription.cancel()
        XCTAssertTrue(canceled)
    }
    
    func test_subscribing_usesTheDesiredDispatcher() {
        let dispatcher = TestDispatcher()
        let future = Future<Int, FutureTestsError>.success(17).notifying(on: dispatcher)
        XCTAssertNil(dispatcher.dispatchBlock)
        future.get()
        XCTAssertNotNil(dispatcher)
    }
    
    func test_subscribingOn_cancelsTheOriginalFuture() {
        let dispatcher = TestDispatcher()
        var originalCancelled = false
        let future = Future<Int, FutureTestsError> { _ in
            return Cancelable { originalCancelled = true }
        }.notifying(on: dispatcher)
        future.get().cancel()
        XCTAssertTrue(originalCancelled)
    }
    
    func test_workingOn_executesWorkerOnTheGivenDispatcher() {
        let dispatcher = TestDispatcher()
        let future = Future<Int, FutureTestsError>.success(17).working(on: dispatcher)
        XCTAssertNil(dispatcher.dispatchBlock)
        future.get()
        XCTAssertNotNil(dispatcher)
    }
    
    func test_workingOn_cancelsTheOriginalFuture() {
        let dispatcher = TestDispatcher()
        var originalCancelled = false
        let future = Future<Int, FutureTestsError> { _ in
            return Cancelable { originalCancelled = true }
        }.working(on: dispatcher)
        future.get().cancel()
        XCTAssertTrue(originalCancelled)
    }
}
