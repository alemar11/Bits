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
///
public final class Atomic<T> {
  private let _lock: NSLocking
  private var _value: T

  public init(_ value: T, lock: NSLocking = NSLock()) {
    _value = value
    _lock = lock
  }

  public func with<U>(_ value: (T) -> U) -> U {
    _lock.lock()
    defer { _lock.unlock() }
    return value(_value)
  }

  public func modify(_ modify: (T) -> T) {
    _lock.lock()
    _value = modify(_value)
    _lock.unlock()
  }

  @discardableResult
  public func swap(_ value: T) -> T {
    _lock.lock()
    let current = _value
    _value = value
    _lock.unlock()
    return current
  }

  public var value: T {
    get {
      _lock.lock()
      let value = _value
      _lock.unlock()
      return value
    }
    set {
      _lock.lock()
      _value = newValue
      _lock.unlock()
    }
  }
}
