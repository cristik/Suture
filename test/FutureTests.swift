//
//  SwiftFutureTests.swift
//  SwiftFutureTests
//
//  Created by Cristian Kocza on 09/08/2018.
//  Copyright © 2018 cristik. All rights reserved.
//

import XCTest
@testable import SwiftFuture

class SwiftFutureTests: XCTestCase {
    
    func test_init_startsWorkRightAway() {
        var executed = false
        _ = Future<Void> { _ in
            executed = true            
        }
        XCTAssertTrue(executed)
    }
}
