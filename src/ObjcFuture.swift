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

import Foundation

/// Objective-C compatible class for `Result`
@objc(SUResult) @objcMembers public final class ObjcResult: NSObject {
    fileprivate let result: Result<Any>
    
    internal init<T>(_ result: Result<T>) {
        switch result {
        case let .value(value): self.result = .value(value)
        case let .error(error): self.result = .error(error)
        }
    }
    
    public var isValue: Bool {
        if case .value = result { return true }
        else { return false }
    }
    
    public var isError: Bool {
        if case .error = result { return true }
        else { return false }
    }
    
    public var value: Any? { return result.value }
    
    public var error: Error? { return result.error }
}

/// Class that bridges to Objective-C, allowing callers from Objective-C to use a Future created
/// on the Swift side. Currently there is no support for creating or transformint futures in
/// Objective-C, only to use them
@objc(SUFuture) @objcMembers public final class ObjcFuture: NSObject {
    public typealias Subscriber = (ObjcResult) -> Void
    public typealias Worker = (@escaping Subscriber) -> Subscription
    
    private let future: Future<Any>
    
    internal init<T>(_ future: Future<T>) {
        self.future = future.map { $0.map { $0 as Any} }
    }
    
    @discardableResult
    public func subscribe(_ handler: @escaping Subscriber) -> Subscription {
        return future.subscribe { handler(ObjcResult($0)) }
    }
}

/// Converts a Swift future to an Objective-C one
///
/// - Parameter future: the Swift future
/// - Returns: an instance of `SUFuture` whose resolution will be the same as Swift's one
func toObjc<T>(_ future: Future<T>) -> ObjcFuture {
    return .init(future)
}
