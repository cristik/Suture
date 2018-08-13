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

public final class Future<Value> {
    private typealias SuccessHandler = (Value) -> Void
    private typealias FailureHandler = (Error) -> Void
    public typealias Worker = (@escaping (Result<Value>) -> Void) -> Void
    private enum State { case pending, success(Value), failure(Error) }
    
    private var successHandlers = [SuccessHandler]()
    private var failureHandlers = [FailureHandler]()
    private var state = State.pending
    private let worker: Worker
    
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
    
    public init(_ worker: @escaping Worker) {
        self.worker = worker
        worker(resolve(with:))
    }
    
    @discardableResult
    public func `try`(_ handler: @escaping (Value) -> Void) -> FutureTry<Value> {
        let futureTry = FutureTry(self)
        register(success: handler)
        return futureTry
    }
    
    @discardableResult
    public func `catch`<E: Error>(_ handler: @escaping (E) -> Void) -> FutureCatch<Value> {
        register(failure: { ($0 as? E).map(handler) })
        return FutureCatch(self)
    }
    
    @discardableResult
    public func `catch`(_ handler: @escaping (Error) -> Void) -> FutureCatch<Value> {
        register(failure: handler)
        return FutureCatch(self)
    }
    
    public func `finally`(_ handler: @escaping () -> Void) -> FutureFinal<Value> {
        register(success: { _ in handler() }, failure: { _ in handler() })
        return FutureFinal(self)
    }
}

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

public protocol Cancelable {
    func cancel()
}

public class FutureTry<Value>: Cancelable {
    private var future: Future<Value>
    private var isCancelled = false
    
    fileprivate init(_ future: Future<Value>) {
        self.future = future
    }
    
    deinit { cancel() }
    
    public func cancel() {
        synchronized(self) { isCancelled = true }
    }
    
    @discardableResult
    public func `catch`<E: Error>(_ handler: @escaping (E) -> Void) -> FutureCatch<Value> {
        
    }
    
    @discardableResult
    public func `catch`(_ handler: @escaping (Error) -> Void) -> FutureCatch<Value> {
        
    }
    
    public func `finally`(_ handler: @escaping () -> Void) -> FutureFinal<Value> {
        
    }
}

public class FutureCatch<Value>: Cancelable {
    private var future: Future<Value>
    private var isCancelled = false
    
    fileprivate init(_ future: Future<Value>) {
        self.future = future
    }
    
    deinit { cancel() }
    
    public func cancel() {
        synchronized(self) { isCancelled = true }
    }
    
    public func `finally`(_ handler: @escaping () -> Void) {
        
    }
}

public class FutureFinal<Value>: Cancelable {
    private var future: Future<Value>
    private var isCancelled = false
    
    fileprivate init(_ future: Future<Value>) {
        self.future = future
    }
    
    deinit { cancel() }
    
    public func cancel() {
        synchronized(self) { isCancelled = true }
    }
}

fileprivate func synchronized<T>(_ obj: AnyObject, _ body: () throws -> T) rethrows -> T {
    objc_sync_enter(obj); defer { objc_sync_exit(obj) }
    return try body()
}
