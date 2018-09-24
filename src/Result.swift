//
//  Result.swift
//  Suture
//
//  Created by Cristian Kocza on 15/08/2018.
//  Copyright © 2018 cristik. All rights reserved.
//

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
