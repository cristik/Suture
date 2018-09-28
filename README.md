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
```swift
future.await { result in
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
    .await(onValue: { print("Success: \($0)") }
           onError: { print("Error: \($0)") })
```

**Note**  `await` might not run always report the future result in an asynchronous manner. The behaviour of the method depends on how the worker provides the result. Also the `await` closure is not guaranteed to run on the caller thread, if you want to ensure a specific thread you need to use `notifying(on:)`.

### Examples

```swift
let future = Future<Double> { resolver in
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { resolver(.value(9)) }
    return Cancelable()
    }
    .mapValue(sqrt)
    .await(onValue: { print("Value: \($0)") })
```
The above code prints "Value: 3"

### Other
Check `Cocoa+Suture` for some Foundation extensions (`URLSession` for example)

### Transformations
`Future` allows the following transformations:

#### map()
This operator creates a new `Future` that reports the transformed result. It comes in the following flavors:
- `map`:  `func map<T>(_ transform: @escaping (Result<Value>) -> Result<T>) -> Future<T>` 
- `mapValue()`:  `func mapValue<T>(_ transform: @escaping (Value) throws -> T) -> Future<T>`
- `mapError()`: `func mapError(_ transform: @escaping (Error) throws -> Value) -> Future<Value>`

#### flatMap()
This operator allow to specify continuations to future.
- `flatMap()`: `func flatMap<T>(_ transform: @escaping (Result<Value>) -> Future<T>) -> Future<T>`
- `flatMapValue()`: `func flatMapValue<T>(_ transform: @escaping (Value) throws -> Future<T>) -> Future<T>`
- `flatMapError()`: `func flatMapError(_ transform: @escaping (Error) throws -> Future<Value>) -> Future<Value>`

#### retry()
Creates a future that retries the worker until either it succeeds, or it fails the specified amount of times
`func retry(_ times: Int) -> Future<Value>`

#### keep()
Creates a future that holds on the received value result. Subsequent observer registrations will receive the same result, without triggering a new worked execution.
`func keep() -> Future<Value>`

#### when(all:)
Creates a future that waits for all other futures to complete. If one of them fails, it instantly report that failure
`static func when(all futures: [Future]) -> Future<[Value]>`

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
