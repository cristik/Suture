# Suture

[![CI Status](https://img.shields.io/travis/cristik/Suture.svg?style=flat)](https://travis-ci.org/cristik/Suture)
[![Version](https://img.shields.io/cocoapods/v/Suture.svg?style=flat)](https://cocoapods.org/pods/Suture)
[![License](https://img.shields.io/cocoapods/l/Suture.svg?style=flat)](https://cocoapods.org/pods/Suture)
[![Platform](https://img.shields.io/cocoapods/p/Suture.svg?style=flat)](https://cocoapods.org/pods/Suture)

### **Important** The current version of `Suture` works on Swift 5.1 and above, only. For Swift 5.0 please use version  0.3.0. For Swift 4.x please use vesion 0.2.2

## Introduction

A `Future` is a thin a wrapper around a computation that might or might not be asynchronous, and that can take less or more time.

You create a `Future` by initializing it with a closure that performs the computation, and that notifies when the computation is complete:

```swift
let future = Future<Int, Error> { resolver in resolver(.value(19)) }
```
The above code creates a future that gets resolved with the value 19.

Futures report `Result` instances, thus a `Result` instance will need to be passed to the resolver.
Failures of the future can be reported via the `failure` case.

Another example:

```swift
let future = Future<String, Error> { resolver in resolver(.value(expensiveComputation())) }.working(on: someDispatchQueue) }
```
The above future executes the expensive computation on some background queue.

### Observation
Futures can be observed via the `get` and `wait` methods:
```swift
future.get { result in
    switch result {
    case let .value(value): print("Success: \(value)")
    case let .error(error): print("Error: \(error)")    
    }
}

// or synchronously
let result = future.wait()
```
Convenience methods exist for observing only success or failure:
```swift
future
    .get(onValue: { print("Success: \($0)") }
         onError: { print("Error: \($0)") })
```

**Note**  `get` might not run always report the future result in an asynchronous manner. The behaviour of the method depends on how the worker provides the result. Also the `get` closure is not guaranteed to run on the caller thread, if you want to ensure a specific thread you need to use `notifying(on:)`.

### Examples

```swift
let future = Future<Double, Error> { resolver in
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { resolver(.value(9)) }
    return Cancelable()
    }
    .mapValue(sqrt)
    .get(onValue: { print("Value: \($0)") })
```
The above code prints "Value: 3"

### Other
Check `Cocoa+Suture` for some Foundation

### Transformations
`Future` allows the following transformations:

#### map()
This operator creates a new `Future` that reports the transformed result. It comes in the following flavors:
- `map`:  `func map<T>(_ transform: @escaping (Result<Success, Failure>) -> Result<NewSuccess, Failure>) -> Future<NewSuccess, Failure>` 
- `mapSuccess()`:  `func mapSuccess<NewSuccess>(_ transform: @escaping (Success) -> NewSuccess) -> Future<NewSuccess, Failure>`
- `mapFailure()`: `func mapFailure(_ transform: @escaping (Failure) throws -> Success) -> Future<Success, Failure>`

#### flatMap()
This operator allow to specify continuations to future.
-`flatMap`:  `func flatMap<NewSuccess>(_ transform: @escaping (Result<Success, Failure>) -> Future<NewSuccess, Failure>) -> Future<NewSuccess, Failure>`
- `flatMapValue()`: `func flatMapSuccess<NewSuccess>(_ transform: @escaping (Success) -> Future<NewSuccess, Failure>) -> Future<NewSuccess, Failure> {`
- `flatMapFailure()`: `func flatMapFailure(_ transform: @escaping (Failure) -> Future) -> Future<Success, Failure>`

#### retry()
Creates a future that retries the worker until either it succeeds, or it fails the specified amount of times
`func retry(_ times: Int) -> Future<Success, Failure>`

#### keep()
Creates a future that holds on the received value result. Subsequent observer registrations will receive the same result, without triggering a new worked execution.
`func keep() -> Future<Success, Failure>`

#### when(all:)
Creates a future that waits for all other futures to complete. If one of them fails, it instantly report that failure
`static func when(all futures: [Future]) -> Future<[Success], Failure>`

#### when(firstOf:)
Creates a future that reports the success of the first future that succeds, or the error of the last future that fails, if all fail
`static func when(firstOf futures: [Future]) -> Future`

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
