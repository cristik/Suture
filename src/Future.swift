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

/// A Future represents a computation whose result is not yet determined, and whose
/// computation can fail. Thus, a Future's result is actually a Result instance
/// Futures are created by providing them a worker closure, which receives as single argument
/// another closure that is meant to report the error or the success.
/// A couple of notes:
/// - futures are lazy by default, the work will start only when `get()` is called
/// - calling `get()` multiple times will result in the worked being executed multiple times,
/// if that is not desired then the `reuse()` operator can be used, which will create a new Future
/// that caches the result of the first computation
public final class Future<Success, Failure: Error> {
    /// A Susbcriber is a value that is notified when the Future suceeds/fails
    public typealias Subscriber = (Result<Success, Failure>) -> Void
    
    /// A worker is the closure that does the actual work
    public typealias Worker = (@escaping (Result<Success, Failure>) -> Void) -> Subscription
    
    private let worker: Worker
    
    /// Creates a Future that uses the given worker as resolver for the future value
    ///
    /// - Parameter worker: a closure that computes and reports the Future result
    public required init(_ worker: @escaping Worker) {
        self.worker = worker
    }
    
    /// Registers a callback to be executed when the Future gets a result
    ///
    /// - Parameter handler: the closure to execute on completion
    /// - Returns: a Subscription that can be cancelled
    @discardableResult public func subscribe(_ subscriber: @escaping Subscriber) -> Subscription {
        return worker(subscriber)
    }
}
