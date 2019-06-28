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

import Foundation

/// Objective-C compatible class for `Result`
@objc(SUResult) @objcMembers public final class ObjcResult: NSObject {
    fileprivate let result: Result<Any, NSError>
    
    internal init<T>(_ result: Result<T, NSError>) {
        switch result {
        case let .success(success): self.result = .success(success)
        case let .failure(failure): self.result = .failure(failure)
        }
    }
    
    public var isSuccess: Bool {
        if case .success = result { return true }
        else { return false }
    }
    
    public var isFailure: Bool {
        if case .failure = result { return true }
        else { return false }
    }
    
    public var success: Any? {
        switch result {
        case let .success(success): return success
        case .failure: return nil
        }
    }
    
    public var failure: NSError? {
        switch result {
        case .success: return nil
        case let .failure(failure): return failure
        }
    }
}

/// Class that bridges to Objective-C, allowing callers from Objective-C to use a Future created
/// on the Swift side. Currently there is no support for creating or transforming futures in
/// Objective-C, only for consuming them
@objc(SUFuture) @objcMembers public final class ObjcFuture: NSObject {
    public typealias Subscriber = (ObjcResult) -> Void
    public typealias Worker = (@escaping Subscriber) -> Subscription
    
    private let future: Future<Any, NSError>
    
    internal init<T>(_ future: Future<T, NSError>) {
        self.future = future.map { $0 as Any } 
    }
    
    @discardableResult
    public func subscribe(_ subscriber: @escaping Subscriber) -> Subscription {
        return future.subscribe { subscriber(ObjcResult($0)) }
    }
}

/// Converts a Swift future to an Objective-C one
///
/// - Parameter future: the Swift future
/// - Returns: an instance of `SUFuture` whose resolution will be the same as Swift's one
func toObjc<T>(_ future: Future<T, NSError>) -> ObjcFuture {
    return .init(future)
}
