//
//  Future+Operators.swift
//  Suture
//
//  Created by Cristian Kocza on 27/06/2019.
//  Copyright © 2019 cristik. All rights reserved.
//

import Foundation

extension Future {
    
    /// Creates a successful Future
    ///
    /// - Parameter value: the value to report
    /// - Returns: a Future instance. Each observer will be notified with the given value
    public static func success(_ success: Success) -> Future {
        return .init { $0(.success(success)); return Subscription() }
    }
    
    /// Creates a failed Future
    ///
    /// - Parameter error: the error to report
    /// - Returns: a Future instance. Each observer will be notified with the given error
    public static func failure(_ failure: Failure) -> Future {
        return .init { $0(.failure(failure)); return Subscription() }
    }
    
    /// Creates a future that never resolves, but throws an assertion in Debug builds
    /// Useful as a placeholder for not yet implemented functionality, in order to.subscribe
    /// a compilable application, that crashes however if forgotting to actually implement
    /// that part.
    ///
    /// - Returns: a Future instance that never notifies its observers
    public static func placeholder() -> Future {
        assertionFailure("Not yet implemented")
        return .init { _ in return Subscription() }
    }
    
    /// Creates a Future that sends the worker closure on the given dispatcher
    ///
    /// - Parameter dispatcher: the dispatcher to perform the computation
    /// - Returns: a new Future, the callee remains unaffected
    public func working(on dispatcher: Dispatcher) -> Future<Success, Failure> {
        return .init { subscriber in
            var subscription: Subscription?
            var canceled = false
            dispatcher.dispatch {
                // TODO: can there occur race condition on the assign?
                if !canceled {
                    subscription = self.subscribe(subscriber)
                }
            }
            return Subscription {
                canceled = true
                subscription?.cancel()
            }
        }
    }
    
    /// Creates a Future that notifies its result on the given dispatcher
    ///
    /// - Parameter dispatcher: the dispatcher to notify onto
    /// - Returns: a new Future, the callee remains unaffected
    public func notifying(on dispatcher: Dispatcher) -> Future<Success, Failure> {
        return .init { subscriber in
            let subscription = self.subscribe(subscriber)
            return Subscription { subscription.cancel() }
        }
    }
    
    /// Creates a Future that resolves with the transformed result
    ///
    /// - Parameter transform: the transform to apply on the result
    /// - Returns: a new Future, the callee remains unaffected
    public func map<NewSuccess>(_ transform: @escaping (Success) -> NewSuccess) -> Future<NewSuccess, Failure> {
        return .init { subscriber in
            let subscription = self.subscribe { subscriber($0.map(transform)) }
            return Subscription { subscription.cancel() }
        }
    }
    
    /// Creates a Future that gets resolved with the Future resulted from the transformation
    ///
    /// - Parameter transform: a closure that receives the calles result and creates the Future that will
    ///   provide the final result
    /// - Returns: a new Future, the callee remains unaffected
    public func flatMap<NewSuccess>(_ transform: @escaping (Success) -> Future<NewSuccess, Failure>) -> Future<NewSuccess, Failure> {
        return .init { subscriber in
            var innerSubscription = Subscription?.none
            let subscription = self.subscribe { result in
                switch result {
                case let .success(value): innerSubscription = transform(value).subscribe(subscriber)
                case let .failure(error): subscriber(.failure(error))
                }
            }
            return Subscription { subscription.cancel(); innerSubscription?.cancel() }
        }
    }
    
    /// Creates a future that retries the worker block until either a success is received, or
    /// the attempts count reaches the provided argument
    ///
    /// - Parameter times: the maximum number of times to retry before giving up and reporting the last error
    /// - Returns: a new Future, the callee remains unaffected
    public func retry(_ times: Int) -> Future<Success, Failure> {
        return .init { originalSubscriber in
            var remaining = max(times - 1, 0)
            var retrySubscriber: Subscriber!
            var retrySubscription: Subscription!
            retrySubscriber = { result in
                switch result {
                case .success,
                     .failure where remaining <= 0: originalSubscriber(result)
                case .failure:
                    remaining -= 1
                    retrySubscription = self.subscribe(retrySubscriber)
                }
            }
            retrySubscription = self.subscribe(retrySubscriber)
            return Subscription { retrySubscription.cancel() }
        }
    }
    
    /// Creates a future that instead of calling the worker on each subscription, it holds onto the
    /// received value and reports that for future observers. Until the result is provided the
    /// observers accumulate, and are retained
    /// Note that reused futures don't cancel the original worker
    ///
    /// - Returns: a new Future, the callee remains unaffected
    public func keep() -> Future<Success, Failure> {
        let lock = NSRecursiveLock()
        var started = false
        var result: Result<Success, Failure>?
        var observers = [Subscriber]()
        return .init { subscriber in
            lock.lock(); defer { lock.unlock() }
            if let result = result {
                subscriber(result)
            } else {
                observers.append(subscriber)
                if !started {
                    started = true
                    self.subscribe { res in
                        lock.lock(); defer { lock.unlock() }
                        result = res
                        observers.forEach { $0(res) }
                        observers = []
                    }
                }
            }
            return Subscription()
        }
    }
    
    /// Creates a future that gets resolved when all child futures.subscribe resolved
    /// If any of those futures fail, the result future is also marked as failed
    ///
    /// - Parameter futures: the array of futures to wait for
    /// - Returns: a Future
    public static func when(all futures: [Future]) -> Future<[Success], Failure> {
        guard !futures.isEmpty else { return .success([]) }
        
        return .init { subscriber in
            let lock = NSRecursiveLock()
            var values = Array(repeating: Success?.none, count: futures.count)
            let subscriptions: [Subscription] = futures.enumerated().map {
                let (index, future) = $0
                return future.subscribe { result in
                    switch result {
                    case let .success(success):
                        lock.lock(); defer { lock.unlock() }
                        values[index] = success
                        if !values.contains(where: { $0 == nil}) {
                            subscriber(.success(values.compactMap { $0 }))
                        }
                    case let .failure(failure): subscriber(.failure(failure))
                    }
                }
            }
            return Subscription { subscriptions.forEach { $0.cancel() } }
        }
    }
    
    /// Creates a future that gets resolved when all child futures.subscribe resolved
    /// If any of those futures fail, the resul future is also marked as failed
    ///
    /// - Parameter firstFuture: the first future from the list
    /// - Parameter otherFutures: the rest of the array
    /// - Returns: a Future
    public static func when(all firstFuture: Future, _ otherFutures: Future...) -> Future<[Success], Failure> {
        return when(all: [firstFuture] + otherFutures)
    }
    
    /// Returns a future that gets resolved with the result of the first successful future
    /// If all future fail, the resulting future is marked as failed with the error of the
    /// last one that fails
    /// **Important** If the input array is empty then the future will never report
    /// - Parameter futures: the futures to wait for
    /// - Returns: a new Future instance
    public static func when(firstOf futures: [Future]) -> Future {
        return .init { subscriber in
            let lock = NSRecursiveLock()
            var remaining = futures.count
            let subscriptions = futures.map { future in
                return future.subscribe { result in
                    switch result {
                    case .success: subscriber(result)
                    case .failure:
                        lock.lock(); defer { lock.unlock() }
                        if remaining == 0 { subscriber(result) }
                        else { remaining -= 1 }
                    }
                }
            }
            return Subscription { subscriptions.forEach { $0.cancel() } }
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
    
    /// Convenience `get` that unboxes the result and allows passing two dedicated closures:
    /// one for success, one for failure
    ///
    /// - Parameters:
    ///   - onSuccess: the closure to call in case the computation succeeds
    ///   - onFailure: the closure to call in case the computation fails
    /// - Returns: a subscription that can be cancelled
    @discardableResult public func subscribe(onSuccess: ((Success) -> Void)? = nil, onFailure: ((Failure) -> Void)? = nil) -> Subscription {
        return subscribe { result in
            switch result {
            case let .success(success): onSuccess?(success)
            case let .failure(failure): onFailure?(failure)
            }
        }
    }
    
    /// Convenience method for transforming an error to a success
    ///
    /// - Parameter transform: the transform to apply on the received error
    /// - Returns: a new Future, the callee remains unaffected
    public func mapFailure(_ transform: @escaping (Failure) -> Success) -> Future<Success, Failure> {
        return .init { subscriber in
            let subscription = self.subscribe { result in
                switch result {
                case let .success(value): subscriber(.success(value))
                case let .failure(failure): subscriber(.success(transform(failure)))
                }
            }
            return Subscription { subscription.cancel() }
        }
    }
    
    /// Convenience method for flatMapping a failure error
    ///
    /// - Parameter transform: the transform to apply on the received error
    /// - Returns: a new Future, the callee remains unaffected
    public func flatMapFailure(_ transform: @escaping (Failure) -> Future) -> Future {
        return .init { subscriber in
            var innerSubscription = Subscription?.none
            let subscription = self.subscribe { result in
                switch result {
                case let .success(value): subscriber(.success(value))
                case let .failure(error): innerSubscription = transform(error).subscribe(subscriber)
                }
            }
            return Subscription { subscription.cancel(); innerSubscription?.cancel() }
        }
    }
}

extension Future where Failure == Error {
    
    /// Creates a Future that resolves with the transformed result
    ///
    /// - Parameter transform: the transform to apply on the result
    /// - Returns: a new Future, the callee remains unaffected
    public func tryMap<NewSuccess>(_ transform: @escaping (Success) throws -> NewSuccess) -> Future<NewSuccess, Failure> {
        return .init { subscriber in
            let subscription = self.subscribe {
                do {
                    switch $0 {
                    case let .success(value): try subscriber(.success(transform(value)))
                    case let .failure(error): subscriber(.failure(error))
                    }
                } catch {
                    subscriber(.failure(error))
                }
            }
            return Subscription { subscription.cancel() }
        }
    }
    
    /// Creates a Future that gets resolved with the Future resulted from the transformation
    ///
    /// - Parameter transform: a closure that receives the calles result and creates the Future that will
    ///   provide the final result
    /// - Returns: a new Future, the callee remains unaffected
    public func tryFlatMap<NewSuccess>(_ transform: @escaping (Success) throws -> Future<NewSuccess, Failure>) -> Future<NewSuccess, Failure> {
        return .init { subscriber in
            var innerSubscription = Subscription?.none
            let subscription = self.subscribe { result in
                do {
                    switch result {
                    case let .success(value): innerSubscription = try transform(value).subscribe(subscriber)
                    case let .failure(error): subscriber(.failure(error))
                    }
                } catch {
                    subscriber(.failure(error))
                }
            }
            return Subscription { subscription.cancel(); innerSubscription?.cancel() }
        }
    }
    
    /// Convenience method for transforming an error to a success
    ///
    /// - Parameter transform: the transform to apply on the received error
    /// - Returns: a new Future, the callee remains unaffected
    public func tryMapFailure(_ transform: @escaping (Failure) throws -> Success) -> Future {
        return .init { subscriber in
            let subscription = self.subscribe { result in
                do {
                    switch result {
                    case let .success(value): subscriber(.success(value))
                    case let .failure(failure): try subscriber(.success(transform(failure)))
                    }
                } catch {
                    subscriber(.failure(error))
                }
            }
            return Subscription { subscription.cancel() }
        }
    }
    
    /// Convenience method for flatMapping a failure error
    ///
    /// - Parameter transform: the transform to apply on the received error
    /// - Returns: a new Future, the callee remains unaffected
    public func tryFlatMapFailure(_ transform: @escaping (Failure) throws -> Future) -> Future {
        return .init { subscriber in
            var innerSubscription = Subscription?.none
            let subscription = self.subscribe { result in
                do {
                    switch result {
                    case let .success(value): subscriber(.success(value))
                    case let .failure(error): innerSubscription = try transform(error).subscribe(subscriber)
                    }
                } catch {
                    subscriber(.failure(error))
                }
            }
            return Subscription { subscription.cancel(); innerSubscription?.cancel() }
        }
    }
}
