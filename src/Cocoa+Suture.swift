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

extension DispatchQueue: Dispatcher {
    /// A dispatch queue will conform to `Dispatcher` by asynchronously dispatching
    /// the block
    ///
    /// - Parameter block: the block to execute async
    public func dispatch(_ block: @escaping () -> Void) {
        async(execute: block)
    }
}

extension URLSession {
    /// Creates a Future whose worker sends an HTTP GET request to the given URL.
    /// In case of success the Future reports a tuple containing the response and the data
    ///
    /// - Parameter url: the url to query
    /// - Returns: a Future
    public func httpData(from url: URL) -> Future<(HTTPURLResponse, Data)> {
        return httpData(for: URLRequest(url: url))
    }
    
    /// Creates a Future whose worker sends an HTTP request to the given URLRequest.
    /// In case of success the Future reports a tuple containing the response and the data
    ///
    /// - Parameter url: the url request to send
    /// - Returns: a Future
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
    
    /// Convenience method for sending a GET request and receive a decoded JSON
    /// In case the request fails or a decoding error occurs, the Future is marked as failed
    ///
    /// - Parameters:
    ///   - url: the URL to query
    ///   - type: the type to decode
    ///   - decoder: a JSONDecoder to use, by default a simple instance is created
    /// - Returns: a Future that gets resolved with a tupe made of the http response,
    /// and the decoded object
    public func httpObject<T: Decodable>(from url: URL, ofType type: T.Type = T.self, decoder: JSONDecoder = JSONDecoder()) -> Future<(HTTPURLResponse, T)> {
        return httpObject(for: URLRequest(url: url), ofType: type, decoder: decoder)
    }
    
    /// Convenience method for sending a HTTP request and receive a decoded JSON
    /// In case the request fails or a decoding error occurs, the Future is marked as failed
    ///
    /// - Parameters:
    ///   - url: the URLRequest to send
    ///   - type: the type to decode
    ///   - decoder: a JSONDecoder to use, by default a simple instance is created
    /// - Returns: a Future that gets resolved with a tupe made of the http response,
    /// and the decoded object
    public func httpObject<T: Decodable>(for request: URLRequest, ofType type: T.Type = T.self, decoder: JSONDecoder = JSONDecoder()) -> Future<(HTTPURLResponse, T)> {
        return httpData(for: request).mapValue { try ($0.0, decoder.decode(type, from: $0.1)) }
    }
}
