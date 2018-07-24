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

public protocol Lock {
  func lock()
  func unlock()
}

extension NSLock: Lock {}
extension NSRecursiveLock: Lock {}

/// An object that coordinates the operation of multiple threads of execution within the same application.
public final class SpinLock: Lock {

  private var unfairLock = os_unfair_lock_s()

  public func lock() {
    os_unfair_lock_lock(&unfairLock)
  }

  public func unlock() {
    os_unfair_lock_unlock(&unfairLock)
  }
}

/// An object that coordinates the operation of multiple threads of execution within the same application.
public final class Mutex: Lock {

  private var mutex: pthread_mutex_t = {
    var mutex = pthread_mutex_t()
    pthread_mutex_init(&mutex, nil)
    return mutex
  }()

  public func lock() {
    pthread_mutex_lock(&mutex)
  }

  public func unlock() {
    pthread_mutex_unlock(&mutex)
  }
}

/// **Bits**
///
/// Thread-safe access using a locking mechanism conforming to `Lock` protocol.
public final class Atomic<T> {
  private let lock: Lock
  private var _value: T

  public init(_ value: T, lock: Lock = NSLock()) {
    self.lock = lock
    self._value = value
  }

  public func with<U>(_ value: (T) -> U) -> U {
    lock.lock()
    defer { lock.unlock() }
    return value(_value)
  }

  public func modify(_ modify: (T) -> T) {
    lock.lock()
    _value = modify(_value)
    lock.unlock()
  }

  @discardableResult
  public func swap(_ value: T) -> T {
    lock.lock()
    let current = _value
    _value = value
    lock.unlock()
    return current
  }

  public var value: T {
    get {
      lock.lock()
      let value = _value
      lock.unlock()
      return value
    }
    set {
      lock.lock()
      _value = newValue
      lock.unlock()
    }
  }
}
