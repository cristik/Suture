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

/// A Result holds the result of a computation that can fail. In case the computation suceeds
/// the result is set with the .value case, in case it fails it's set with the .error case
///
/// - value: the success path
/// - error: the error path
public enum Result<Value> {
    case value(Value)
    case error(Error)
    
    func map<T>(_ transform: (Value) throws -> T) -> Result<T> {
        do {
            switch self {
            case let .value(value): return try .value(transform(value))
            case let .error(error): throw error
            }
        } catch {
            return .error(error)
        }
    }
    
    func flatMap<T>(_ transform: (Value) throws -> Result<T>) -> Result<T> {
        do {
            switch self {
            case let .value(value): return try transform(value)
            case let .error(error): throw error
            }
        } catch {
            return .error(error)
        }
    }
}

public extension Result {
    public var value: Value? { if case let .value(value) = self { return value } else { return nil } }
    public var error: Error? { if case let .error(error) = self { return error } else { return nil } }
}

func map<T,U>(_ transform: @escaping (T) throws -> U) -> (Result<T>) -> Result<U> {
    return { $0.map(transform) }
}

func flatMap<T,U>(_ transform: @escaping (T) throws -> Result<U>) -> (Result<T>) -> Result<U> {
    return { $0.flatMap(transform) }
}
