//
//  Future+Combine.swift
//  Suture
//
//  Created by Cristian Kocza on 27/06/2019.
//  Copyright © 2019 cristik. All rights reserved.
//

import Combine

@available(iOS 13.0, macOS 10.15, *)
public final class FuturePublisher<Success, Failure: Error>: Publisher {
    public typealias Output = Success
    
    private let future: Future<Success, Failure>
    
    internal init(future: Future<Success, Failure>) {
        self.future = future
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        future.subscribe { result in
            switch result {
            case let .success(value):
                _ = subscriber.receive(value)
                subscriber.receive(completion: .finished)
            case let .failure(error):
                subscriber.receive(completion: .failure(error))
            }
        }
    }
}

@available(iOS 13.0, macOS 10.15, *)
extension Future {
    public func asPublisher() -> FuturePublisher<Success, Failure> {
        return .init(future: self)
    }
}
