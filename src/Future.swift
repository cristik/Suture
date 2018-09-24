//
//  Future.swift
//  Suture
//
//  Created by Cristian Kocza on 09/08/2018.
//  Copyright © 2018 cristik. All rights reserved.
//

import Foundation

public protocol Cancelable {
    func cancel()
}

public protocol Dispatcher {
    func dispatch(_ block: @escaping () -> Void)
}

public class Subscription: Cancelable {
    public private(set) var isCancelled = false
    private var cancelAction: (() -> Void)?
    
    public init(_ cancelAction:  (() -> Void)? = nil) {
        self.cancelAction = cancelAction
    }
    
    public func cancel() {
        synchronized(self) { cancelAction?(); cancelAction = nil; isCancelled = true }
    }
}

public final class Future<Value> {
    public typealias ResultHandler = (Result<Value>) -> Void
    public typealias Worker = (@escaping ResultHandler) -> Subscription
    
    private let worker: Worker
    
    public init(worker: @escaping Worker) {
        self.worker = worker
    }
    
    @discardableResult
    public func subscribe(_ handler: @escaping ResultHandler) -> Subscription {
        return worker(handler)
    }
    
    public func subscribing(on dispatcher: Dispatcher) -> Future<Value> {
        return .init { resolver in
            let subscription = self.subscribe(resolver)
            return Subscription { subscription.cancel() }
        }
    }
    
    public func map<T>(_ transform: @escaping (Result<Value>) throws -> Result<T>) -> Future<T> {
        return .init { resolver in
            let subscription = self.subscribe { result in
                do { try resolver(transform(result)) } catch { resolver(.error(error)) }
            }
            return Subscription { subscription.cancel() }
        }
    }
    
    public func flatMap<T>(_ transform: @escaping (Result<Value>) throws -> Future<T>) -> Future<T> {
        return .init { resolver in
            let subscription = self.subscribe { result in
                do { try transform(result).subscribe(resolver) } catch { resolver(.error(error)) }
            }
            return Subscription { subscription.cancel() }
        }
    }
}

extension DispatchQueue: Dispatcher {
    public func dispatch(_ block: @escaping () -> Void) {
        async(execute: block)
    }
}

extension Future {
    
    public static func value(_ value: Value) -> Future<Value> {
        return .init { $0(.value(value)); return Subscription() }
    }
    
    public static func error(_ error: Error) -> Future<Value> {
        return .init { $0(.error(error)); return Subscription() }
    }
    
    public static func placeholder() -> Future<Value> {
        assertionFailure("Not yet implemented")
        return .init { _ in return Subscription() }
    }
    
    public func retrying(_ times: Int) -> Future<Value> {
        return .init { resolver in
            var remaining = times - 1
            var handler: ResultHandler!
            var subscription: Subscription!
            handler = { result in
                print(remaining)
                switch result {
                case .value,
                     .error where remaining <= 0: resolver(result)
                case .error:
                    remaining -= 1
                    subscription = self.subscribe(handler)
                }
            }
            subscription = self.subscribe(handler)
            return Subscription { subscription.cancel() }
        }
    }
    
    public func hold() -> Future<Value> {
        return .init { resolver in
            _ = self.subscribe(resolver)
            return Subscription()
        }
    }
    
    @discardableResult
    public func subscribe(onValue: ((Value) -> Void)? = nil, onError: ((Error) -> Void)? = nil) -> Subscription {
        return subscribe { result in
            switch result {
            case let .value(value): onValue?(value)
            case let .error(error): onError?(error)
            }
        }
    }
    
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

fileprivate func synchronized<T>(_ lock: AnyObject, _ body: () throws -> T) rethrows -> T {
    objc_sync_enter(lock); defer { objc_sync_exit(lock) }; return try body()
}
