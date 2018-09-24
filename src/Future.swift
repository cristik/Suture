//
//  Future.swift
//  SwiftFuture
//
//  Created by Cristian Kocza on 09/08/2018.
//  Copyright © 2018 cristik. All rights reserved.
//

import Foundation

public enum Result<Value> {
    case success(Value)
    case failure(Error)
}

protocol FutureResolver {
    
}

public final class Future<Value> {
    private typealias SuccessHandler = (Value) -> Void
    private typealias FailureHandler = (Error) -> Void
    private enum State { case pending, success(Value), failure(Error) }
    
    private var successHandlers = [SuccessHandler]()
    private var failureHandlers = [FailureHandler]()
    private var state = State.pending
    
    private func register(success: SuccessHandler? = nil, failure: FailureHandler? = nil) {
        synchronized(self) {
            switch state {
            case .pending:
                success.map { successHandlers.append($0) }
                failure.map { failureHandlers.append($0) }
            case let .success(value):
                success?(value)
            case let .failure(error):
                failure?(error)
            }
        }
    }
    
    private func resolve(with result: Result<Value>) {
        synchronized(self) {
            switch result {
            case let .success(value):
                state = .success(value)
                successHandlers.forEach { $0(value) }
            case let .failure(error):
                state = .failure(error)
                failureHandlers.forEach { $0(error) }
            }
            successHandlers = []
            failureHandlers = []
        }
    }
    
    public init(_ worker: (@escaping (Result<Value>) -> Void) -> Void) {
        worker(resolve(with:))
    }
    
    @discardableResult
    public func `try`(_ handler: @escaping (Value) -> Void) -> FutureCatch {
        register(success: handler)
        return self
    }
    
    @discardableResult
    public func `catch`<E: Error>(_ handler: @escaping (E) -> Void) -> FutureFinal {
        register(failure: { ($0 as? E).map(handler) })
        return self
    }
    
    @discardableResult
    public func `catch`(_ handler: @escaping (Error) -> Void) -> FutureFinal {
        register(failure: handler)
        return self
    }
    
    public func `finally`(_ handler: @escaping () -> Void) {
        register(success: { _ in handler() }, failure: { _ in handler() })
    }
}

extension Future: FutureCatch, FutureFinal { }

extension Future {
    func map<T>(_ transform: @escaping (Value) throws -> T) -> Future<T> {
        return Future<T> { (resolver: @escaping (Result<T>) -> Void) -> Void in
            self.try { do { try resolver(.success(transform($0))) } catch { resolver(.failure(error)) } }
                .catch { resolver(.failure($0)) }
        }
    }
    
    func flatMap<T>(_ transform: @escaping (Value) throws -> Future<T>) -> Future<T> {
        return Future<T> { (resolver: @escaping (Result<T>) -> Void) -> Void in
            self.try { do { try transform($0).try { resolver(.success($0)) }.catch { resolver(.failure($0)) } } catch { resolver(.failure(error)) } }
                .catch { resolver(.failure($0)) }
        }
    }
}

public protocol FutureCatch {
    @discardableResult
    func `catch`<E: Error>(_ handler: @escaping (E) -> Void) -> FutureFinal
    
    @discardableResult
    func `catch`(_ handler: @escaping (Error) -> Void) -> FutureFinal
    
    func `finally`(_ handler: @escaping () -> Void)
}

public protocol FutureFinal {
    func `finally`(_ handler: @escaping () -> Void)
}

fileprivate func synchronized<T>(_ obj: AnyObject, _ body: () throws -> T) rethrows -> T {
    objc_sync_enter(obj); defer { objc_sync_exit(obj) }
    return try body()
}
