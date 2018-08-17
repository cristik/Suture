//
//  Future.swift
//  SwiftFuture
//
//  Created by Cristian Kocza on 09/08/2018.
//  Copyright © 2018 cristik. All rights reserved.
//

import Foundation

public protocol Cancelable {
    func cancel()
}

public class Subscription: Cancelable {
    public private(set) var isCancelled = false
    
    public func cancel() {
        synchronized(self) { isCancelled = true }
    }
}

public protocol Dispatcher {
    func dispatch(_ block: @escaping () -> Void)
}

public final class Future<Value> {
    public typealias ResultHandler = (Result<Value>) -> Void
    public typealias Worker = (@escaping (Result<Value>) -> Void) -> Void
    
    fileprivate var registrations = [ResultHandler]()
    private var result = Result<Value>?.none
    private var worker: Worker?
    private var dispatcher: Dispatcher?
    private var isCanceled = false
    
    private func resolve(with result: Result<Value>) {
        synchronized(self) {
            self.result = result
            registrations.forEach { $0(result) }
            registrations = []
        }
    }
    
    public init(dispatcher: Dispatcher? = nil, worker: @escaping Worker) {
        self.dispatcher = dispatcher
        self.worker = worker
    }
    
    public func notifying(on dispatcher: Dispatcher) -> Future<Value> {
        return Future(dispatcher: dispatcher) { resolver in
            self.subscribe(resolver)
        }
    }
    
    @discardableResult
    public func subscribe(_ handler: @escaping (Result<Value>) -> Void) -> Subscription {
        return synchronized(self) {
            // this is one lazy future :)
            worker?(resolve(with:))
            worker = nil
            
            let subscription = Subscription()
            
            // intended retaing cycle, will be broken when the future receives a result
            let wrapped: (Result<Value>) -> Void = { result in
                guard !subscription.isCancelled else { return }
                self.dispatcher.map { $0.dispatch { handler(result) } } ?? handler(result)
            }
            
            switch result {
            case .none:
                registrations.append(wrapped)
            case let .some(result):
                wrapped(result)
            }
            
            return subscription
        }
    }
    
    public func cancel() {
        synchronized(self) { isCanceled = true }
    }
    
    public func map<T>(_ transform: @escaping (Result<Value>) throws -> Result<T>) -> Future<T> {
        return .init { resolver in
            self.subscribe { result in
                do { try resolver(transform(result)) } catch { resolver(.error(error)) }
            }
        }
    }
    
    public func flatMap<T>(_ transform: @escaping (Result<Value>) throws -> Future<T>) -> Future<T> {
        return .init { resolver in
            self.subscribe { result in
                do { try transform(result).subscribe(resolver) } catch { resolver(.error(error)) }
            }
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
        return .init { $0(.value(value)) }
    }
    
    public static func error(_ error: Error) -> Future<Value> {
        return .init { $0(.error(error)) }
    }
    
    public static func placeholder() -> Future<Value> {
        assertionFailure("Not yet implemented")
        return .init { _ in }
    }
    
    public static func retrying(_ times: Int, _ worker: @escaping Worker) -> Future<Value> {
        let times = max(times, 0)
        var attempts = 1
        var originalResolver: ((Result<Value>) -> Void)!
        var modifiedResolver: ((Result<Value>) -> Void)!
        modifiedResolver = { result in
            switch result {
            case .value: originalResolver(result)
            case .error:
                if attempts < times {
                    attempts += 1
                    worker(modifiedResolver)
                } else {
                    originalResolver(result)
                }
            }
        }
        return Future { resolver in
            originalResolver = resolver
            worker(modifiedResolver)
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

fileprivate func synchronized<T>(_ obj: AnyObject, _ body: () throws -> T) rethrows -> T {
    objc_sync_enter(obj); defer { objc_sync_exit(obj) }
    return try body()
}
