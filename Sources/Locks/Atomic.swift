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
public final class Atomic<T> {

  public enum LockType {
    case lock
    case recursive
    case spin
    case mutex
    case readWrite
  }

  private let lock: Lock
  private let type: LockType
  private var _value: T

  public init(_ value: T, lockType: LockType = .lock) {
    self.type = lockType
    self.lock = Atomic.lock(for: lockType)
    self._value = value
  }

  static func lock(for type: LockType) -> Lock {
    switch type {
    case .lock: return NSLock()
    case .recursive: return NSRecursiveLock()
    case .spin: return SpinLock()
    case .mutex: return Mutex()
    case .readWrite: return ReadWriteLock()
    }
  }

  public func with<U>(_ value: (T) -> U) -> U {
    lock.readLock()
    defer { lock.unlock() }
    return value(_value)
  }

  public func modify(_ modify: (T) -> T) {
    lock.writeLock()
    _value = modify(_value)
    lock.unlock()
  }

  @discardableResult
  public func swap(_ value: T) -> T {
    lock.writeLock()
    let current = _value
    _value = value
    lock.unlock()
    return current
  }

  public var value: T {
    get {
      lock.readLock()
      let value = _value
      lock.unlock()
      return value
    }
    set {
      lock.writeLock()
      _value = newValue
      lock.unlock()
    }
  }
}
