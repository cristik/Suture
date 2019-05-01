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

final class FutureCreationTests: XCTestCase {
    
    func test_init_doesntStartWorkRightAway() {
        var executed = false
        _ = Future<Void, FutureTestsError> { _ in
            executed = true; return Cancelable()
        }
        XCTAssertFalse(executed)
    }
    
    func test_value_reportsSuccess() {
        var result = Result<String, FutureTestsError>?.none
        Future<String, FutureTestsError>.success("abc").get { result = $0 }
        XCTAssertEqual(try? result?.get(), "abc")
    }
    
    func test_error_reportsError() {
        var result = Result<String, FutureTestsError>?.none
        Future<String, FutureTestsError>.failure(.second).get { result = $0 }
        XCTAssertEqual(result, .failure(.second))
    }
}
