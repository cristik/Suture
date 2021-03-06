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

extension DispatchQueue: Dispatcher {
    /// A dispatch queue will conform to `Dispatcher` by asynchronously dispatching
    /// the block
    ///
    /// - Parameter block: the block to execute async
    public func dispatch(_ block: @escaping () -> Void) {
        async(execute: block)
    }
}

extension DispatchQueue {
    /// Dispatches async the given computation and creates a Future that gets resolved
    /// with the value returned by the closure, or gets rejected with the thrown error
    ///
    /// - Parameter block: the computation to execute async
    /// - Returns: a Future
    public func asyncFuture<T>(_ computation: @escaping () throws -> T) -> Future<T, Error> {
        return .init { resolver in
            self.async {
                do { try resolver(.success(computation())) } catch { resolver(.failure(error)) }
            }
            return Cancelable()
        }
    }
}
