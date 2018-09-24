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

/// A Future represents a computation whose result is not yet determined, and whose
/// computation can fail. Thus, a Future's result is actually a Result instance
/// Futures are created by providing them a worker closure, which receives as single argument
/// another closure that is meant to report the error or the success.
/// A couple of notes:
/// - futures are lazy by default, the work will start only when `subscribe()` is called
/// - calling `subscribe()` multiple times will result in the worked being executed multiple times,
/// if that is not desired then the `reuse()` operator can be used, which will create a new Future
/// that caches the result of the first computation
public final class Future<Value> {
    /// Susbcriber
    public typealias Handler = (Result<Value>) -> Void
    
    /// Resolver
    public typealias Resolver = (Result<Value>) -> Void
    
    /// Worker
    public typealias Worker = (@escaping Resolver) -> Cancelable
    
    fileprivate let worker: Worker
    
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
    @discardableResult public func await(_ handler: @escaping Handler) -> Cancelable {
        return worker(handler)
    }
}

extension Future {
    
    /// Creates a successful Future
    ///
    /// - Parameter value: the value to report
    /// - Returns: a Future instance. Each subscriber will be notified with the given value
    public static func value(_ value: Value) -> Future<Value> {
        return .init { $0(.value(value)); return Cancelable() }
    }
    
    /// Creates a failed Future
    ///
    /// - Parameter error: the error to report
    /// - Returns: a Future instance. Each subscriber will be notified with the given error
    public static func error(_ error: Error) -> Future<Value> {
        return .init { $0(.error(error)); return Cancelable() }
    }
    
    /// Creates a future that never resolves, but throws an assertion in Debug builds
    /// Useful as a placeholder for not yet implemented functionality, in order to get
    /// a compilable application, that crashes however if forgotting to actually implement
    /// that part.
    ///
    /// - Returns: a Future instance that never notifies its subscribers
    public static func placeholder() -> Future<Value> {
        assertionFailure("Not yet implemented")
        return .init { _ in return Cancelable() }
    }
    
    /// Synchronously waits until the Future gets a result
    ///
    /// - Returns: the Future result
    @discardableResult public func wait() -> Result<Value> {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<Value>!
        await { result = $0; semaphore.signal() }
        semaphore.wait()
        return result
    }
    
    /// Synchronously waits until either the Future gets a result or the timeout ellapses
    ///
    /// - Parameter timeout: the time to wait
    /// - Parameter timeoutError: the error to report in case of failure
    /// - Returns: the Future result
    @discardableResult public func wait(for timeout: TimeInterval, timeoutError: Error) -> Result<Value> {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<Value>!
        await { result = $0; semaphore.signal() }
        if semaphore.wait(timeout: .now() + timeout) == .success {
            return result
        } else {
            return .error(timeoutError)
        }
    }
    
    /// Creates a Future that sends the worker closure on the given dispatcher
    ///
    /// - Parameter dispatcher: the dispatcher to perform the computation
    /// - Returns: a new Future, the callee remains unaffected
    public func working(on dispatcher: Dispatcher) -> Future<Value> {
        return .init { resolver in
            var subscription: Cancelable?
            var canceled = false
            dispatcher.dispatch {
                // TODO: can there occur race condition on the assign?
                if !canceled {
                    subscription = self.worker(resolver)
                }
            }
            return Cancelable {
                canceled = true
                subscription?.cancel()
            }
        }
    }
    
    /// Creates a Future that notifies the subscribers on the given dispatcher
    ///
    /// - Parameter dispatcher: the dispatcher to notify onto
    /// - Returns: a new Future, the callee remains unaffected
    public func subscribing(on dispatcher: Dispatcher) -> Future<Value> {
        return .init { resolver in
            let subscription = self.await(resolver)
            return Cancelable { subscription.cancel() }
        }
    }
    
    /// Creates a Future that resolves with the transformed result
    ///
    /// - Parameter transform: the transform to apply on the result
    /// - Returns: a new Future, the callee remains unaffected
    public func map<T>(_ transform: @escaping (Result<Value>) -> Result<T>) -> Future<T> {
        return .init { resolver in
            let subscription = self.await { resolver(transform($0)) }
            return Cancelable { subscription.cancel() }
        }
    }
    
    /// Creates a Future that gets resolved with the Future resulted from the transformation
    ///
    /// - Parameter transform: a closure that receives the calles result and creates the Future that will
    ///   provide the final result
    /// - Returns: a new Future, the callee remains unaffected
    public func flatMap<T>(_ transform: @escaping (Result<Value>) -> Future<T>) -> Future<T> {
        return .init { resolver in
            var innerSubscription = Cancelable?.none
            let subscription = self.await { result in
                innerSubscription = transform(result).await(resolver)
            }
            return Cancelable { subscription.cancel(); innerSubscription?.cancel() }
        }
    }
    
    /// Creates a future that retries the worker block until either a success is received, or
    /// the attempts count reaches the provided argument
    ///
    /// - Parameter times: the maximum number of times to retry before giving up and reporting the last error
    /// - Returns: a new Future, the callee remains unaffected
    public func retry(_ times: Int) -> Future<Value> {
        return .init { resolver in
            var remaining = times - 1
            var handler: Handler!
            var subscription: Cancelable!
            handler = { result in
                switch result {
                case .value,
                     .error where remaining <= 0: resolver(result)
                case .error:
                    remaining -= 1
                    subscription = self.await(handler)
                }
            }
            subscription = self.await(handler)
            return Cancelable { subscription.cancel() }
        }
    }
    
    /// Creates a future that instead of calling the worker on each subscription, it holds onto the
    /// received value and reports that for future subscribers. Until the result is provided the
    /// subscribers accumulate
    /// Note that reused futures don't cancel the original worker
    ///
    /// - Returns: a new Future, the callee remains unaffected
    public func keep() -> Future<Value> {
        let lock = NSRecursiveLock()
        var started = false
        var result: Result<Value>?
        var subscribers = [Handler]()
        return .init { resolver in
            lock.lock(); defer { lock.unlock() }
            if let result = result {
                resolver(result)
            } else {
                subscribers.append(resolver)
                if !started {
                    started = true
                    self.await { res in
                        lock.lock(); defer { lock.unlock() }
                        result = res
                        subscribers.forEach { $0(res) }
                        subscribers = []
                    }
                }
            }
            return Cancelable()
        }
    }
    
    /// Creates a future that gets resolved when all child futures get resolved
    /// If any of those futures fail, the resul future is also marked as failed
    ///
    /// - Parameter futures: the array of futures to wait for
    /// - Returns: a Future
    public static func when(all futures: [Future]) -> Future<[Value]> {
        guard !futures.isEmpty else { return .value([]) }
        
        return .init { resolver in
            let lock = NSRecursiveLock()
            var values = Array(repeating: Value?.none, count: futures.count)
            let subscriptions: [Cancelable] = futures.enumerated().map {
                let (index, future) = $0
                return future.await { result in
                    switch result {
                    case let .value(value):
                        lock.lock(); defer { lock.unlock() }
                        values[index] = value
                        if !values.contains(where: { $0 == nil}) {
                            resolver(.value(values.compactMap { $0 }))
                        }
                    case let .error(error): resolver(.error(error))
                    }
                }
            }
            return Cancelable { subscriptions.forEach { $0.cancel() } }
        }
    }
    
    /// Creates a future that gets resolved when all child futures get resolved
    /// If any of those futures fail, the resul future is also marked as failed
    ///
    /// - Parameter firstFuture: the first future from the list
    /// - Parameter otherFutures: the rest of the array
    /// - Returns: a Future
    public static func when(all firstFuture: Future, _ otherFutures: Future...) -> Future<[Value]> {
        return when(all: [firstFuture] + otherFutures)
    }
    
    /// Returns a future that gets resolved with the result of the first successful future
    /// If all future fail, the resulting future is marked as failed with the error of the
    /// last one that fails
    /// **Important** If the input array is empty then the future will never report
    /// - Parameter futures: the futures to wait for
    /// - Returns: a new Future instance
    public static func when(firstOf futures: [Future]) -> Future {
        return .init { resolver in
            let lock = NSRecursiveLock()
            var remaining = futures.count
            let subscriptions = futures.map { future in
                return future.await { result in
                    switch result {
                    case .value: resolver(result)
                    case .error:
                        lock.lock(); defer { lock.unlock() }
                        if remaining == 0 { resolver(result) }
                        else { remaining -= 1 }
                    }
                }
            }
            return Cancelable { subscriptions.forEach { $0.cancel() } }
        }
    }
    
    /// Returns a future that gets resolved with the result of the first successful future
    /// If all future fail, the resulting future is marked as failed with the error of the
    /// last one that fails
    /// - Parameter firstFuture: the first future from the list
    /// - Parameter otherFutures: the rest of the array
    /// - Returns: a new Future instance
    public static func when(firstOf firstFuture: Future, _ otherFutures: Future...) -> Future {
        return when(firstOf: [firstFuture] + otherFutures)
    }
    
    /// Convenience subscribing that unboxes the result and allows passing two dedicated closures:
    /// one for success, one for failure
    ///
    /// - Parameters:
    ///   - onValue: the closure to call in case the computation succeeds
    ///   - onError: the closure to call in case the computation fails
    /// - Returns: a subscription that can be cancelled
    @discardableResult public func subscribe(onValue: ((Value) -> Void)? = nil, onError: ((Error) -> Void)? = nil) -> Cancelable {
        return await { result in
            switch result {
            case let .value(value): onValue?(value)
            case let .error(error): onError?(error)
            }
        }
    }
    
    /// Convenience method for mapping the success value to another value. If the closure throws,
    /// the resulting Future will report failure
    ///
    /// - Parameter transform: the transform to apply on the succesful value
    /// - Returns: a new Future, the callee remains unaffected
    public func mapValue<T>(_ transform: @escaping (Value) throws -> T) -> Future<T> {
        return map { result in
            do {
                switch result {
                case let .value(value): return try .value(transform(value))
                case let .error(error): throw error
                }
            } catch {
                return .error(error)
            }
        }
    }
    
    /// Convenience method for transforming an error to a success
    ///
    /// - Parameter transform: the transform to apply on the received error
    /// - Returns: a new Future, the callee remains unaffected
    public func mapError(_ transform: @escaping (Error) throws -> Value) -> Future<Value> {
        return map { result in
            do {
                switch result {
                case let .value(value): return .value(value)
                case let .error(error): return try .value(transform(error))
                }
            } catch {
                return .error(error)
            }
        }
    }
    
    /// Convenience method for flatMapping a success value
    ///
    /// - Parameter transform: the transform to apply on the succesful value
    /// - Returns: a new Future, the callee remains unaffected
    public func flatMapValue<T>(_ transform: @escaping (Value) throws -> Future<T>) -> Future<T> {
        return flatMap { result in
            do {
                switch result {
                case let .value(value): return try transform(value)
                case let .error(error): throw error
                }
            } catch {
                return .error(error)
            }
        }
    }
    
    /// Convenience method for flatMapping a failure error
    ///
    /// - Parameter transform: the transform to apply on the received error
    /// - Returns: a new Future, the callee remains unaffected
    public func flatMapError(_ transform: @escaping (Error) throws -> Future<Value>) -> Future<Value> {
        return flatMap { result in
            do {
                switch result {
                case let .value(value): return .value(value)
                case let .error(error): return try transform(error)
                }
            } catch {
                return .error(error)
            }
        }
    }
}
