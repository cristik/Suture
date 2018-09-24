//
//  Cocoa+Suture.swift
//  Suture
//
//  Created by Cristian Kocza on 20/08/2018.
//  Copyright © 2018 cristik. All rights reserved.
//

import Foundation

extension DispatchQueue: Dispatcher {
    public func dispatch(_ block: @escaping () -> Void) {
        async(execute: block)
    }
}

extension URLSession {
    public func httpData(for url: URL) -> Future<(HTTPURLResponse, Data)> {
        return httpData(for: URLRequest(url: url))
    }
    
    public func httpData(for request: URLRequest) -> Future<(HTTPURLResponse, Data)> {
        return .init { resolver in
            let task = self.dataTask(with: request) { data, response, error in
                if let error = error {
                    resolver(.error(error))
                } else {
                    // FIXME: forced unwraps, hower a request should always have a url, and the initializer
                    // should always succeed, right?
                    let response = response as? HTTPURLResponse ?? HTTPURLResponse(url: request.url!,
                                                                                   statusCode: 0,
                                                                                   httpVersion: nil,
                                                                                   headerFields: nil)!
                    let data = data ?? Data()
                    resolver(Result<(HTTPURLResponse, Data)>.value((response, data)))
                }
            }
            task.resume()
            return Subscription { task.cancel() }
        }
    }
    
    public func httpObject<T: Decodable>(for url: URL, ofType type: T.Type = T.self, decoder: JSONDecoder = JSONDecoder()) -> Future<(HTTPURLResponse, T)> {
        return httpObject(for: URLRequest(url: url), ofType: type, decoder: decoder)
    }
    
    public func httpObject<T: Decodable>(for request: URLRequest, ofType type: T.Type = T.self, decoder: JSONDecoder = JSONDecoder()) -> Future<(HTTPURLResponse, T)> {
        return httpData(for: request).mapValue { try ($0.0, decoder.decode(type, from: $0.1)) }
    }
}
