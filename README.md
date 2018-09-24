# Suture

[![CI Status](https://img.shields.io/travis/cristik/Suture.svg?style=flat)](https://travis-ci.org/cristik/Suture)
[![Version](https://img.shields.io/cocoapods/v/Suture.svg?style=flat)](https://cocoapods.org/pods/Suture)
[![License](https://img.shields.io/cocoapods/l/Suture.svg?style=flat)](https://cocoapods.org/pods/Suture)
[![Platform](https://img.shields.io/cocoapods/p/Suture.svg?style=flat)](https://cocoapods.org/pods/Suture)

## Introduction

A `Future` is a thin a wrapper around a computation that might or might not be asynchronous, and that can take less or more time.

You create a `Future` by initializing it with a closure that performs the computation, and that notifies when the computation is complete:

```swift
let future = Future<Int> { resolver in resolver(.value(19)) }
```
The above code creates a future that gets resolved with the value 19.

Futures report `Result` instances, thus a `Result` will need to be passed to the resolver.
```swift
enum Result<Value> {
    case value(Value)
    case error(Error)
}
```
Failures of the future can be reported via the `error` case.

Another example:

```swift
let future = Future<String> { resolver in resolver(.value(expensiveComputation())) }.working(on: someDispatchQueue) }
```
The above future executes the expensive computation on some background queue.

### Observation
Futures can be observed via the `await` and `wait` methods:

future.await { result in
    switch result {
    case let .value(value): print("Success: \(value)")
    case let .error(error): print("Error: \(error)")    
    }
}

// or synchronously
let result = future.wait()

Convenience methods exist for observing only success or failure:
future
    .await(onValue: { print("Success: \($0)") }
           onError: { print("Error: \($0)") })

## Installation

Suture is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'Suture'
```

## Author

cristik

## License

Suture is available under the MIT license. See the LICENSE file for more info.
