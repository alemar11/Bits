//
// Bits
//
// Copyright © 2016-2018 Tinrobots.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

public protocol ThreadSafe {
  // swiftlint:disable:next type_name
  associatedtype T
  var value: T { get }
  func read<U>(_ value: (T) -> U) -> U
  func write(_ transform: (inout T) -> Void)
  func safeAccess<U>(_ transform: (inout T) -> U) -> U
}

/// **Bits**
///
/// Thread-safe access using a locking mechanism conforming to `NSLocking` protocol.
public final class Atomic<T>: ThreadSafe {
  private var _value: T
  private let lock: NSLocking

  public init(_ value: T, lock: NSLocking) {
    self.lock = lock
    self._value = value
  }

  public var value: T {
    // Atomic properties with a setter are kind of dangerous in some scenarios
    // https://github.com/ReactiveCocoa/ReactiveSwift/issues/269
    return read { $0 }
  }

  public func read<U>(_ value: (T) -> U) -> U {
    lock.lock()
    defer { lock.unlock() }
    return value(_value)
  }

  public func write(_ transform: (inout T) -> Void) {
    lock.lock()
    defer { lock.unlock() }
    transform(&_value)
  }

  public func safeAccess<U>(_ transform: (inout T) -> U) -> U {
    lock.lock()
    defer { lock.unlock() }
    return transform(&_value)
  }

}

/// **Bits**
///
/// Thread-safe access using using serial dispatch queues.
public final class DispatchedAtomic<T>: ThreadSafe {
  private var _value: T
  private let queue: DispatchQueue

  public init(_ value: T, qos: DispatchQoS = .default) {
    self._value = value
    self.queue = DispatchQueue(label: "\(identifier).\(type(of: self))", qos: qos)
  }

  public var value: T {
    return read { $0 }
  }

  public func read<U>(_ value: (T) -> U) -> U {
    return queue.sync { value(_value) }
  }

  public func write(_ transform: (inout T) -> Void) {
    queue.sync { transform(&_value) }
  }

  public func safeAccess<U>(_ transform: (inout T) -> U) -> U {
    return queue.sync { transform(&_value) }
  }

}
