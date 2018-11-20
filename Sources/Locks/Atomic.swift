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

/// **Bits**
///
/// Thread-safe access using a locking mechanism conforming to `Lock` protocol.
final class Atomic<T> {

  private var _value: T
  private let lock: Lock

  // Atomic properties with a setter are kind of dangerous in some scenarios
  // https://github.com/ReactiveCocoa/ReactiveSwift/issues/269

  init(_ value: T, lock: Lock) {
    self.lock = lock
    self._value = value
  }

  public var value: T {
    lock.lock()
    defer { lock.unlock() }
    return _value
  }

  @inline(__always)
  public func read<U>(_ value: (T) -> U) -> U {
    lock.lock()
    defer { lock.unlock() }
    return value(_value)
  }

  @inline(__always)
  public func write(_ transform: (inout T) -> Void) {
    lock.lock()
    defer { lock.unlock() }
    transform(&_value)
  }

  @inline(__always)
  func access<U>(_ body: (inout T) -> U) -> U {
    lock.lock()
    defer { lock.unlock() }
    return body(&_value)
  }

}
