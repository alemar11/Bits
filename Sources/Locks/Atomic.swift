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

  private let lock: Lock
  private let lockingType: LockingType
  private var _value: T

  public init(_ value: T, lockingType: LockingType = .nslock) {
    self.lockingType = lockingType
    self.lock = Atomic.lock(for: lockingType)
    self._value = value
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

  public func mutate(_ transform: (inout T) -> Void) {
    lock.writeLock()
    transform(&_value)
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

extension Atomic {

  /// All the available locking mechanism.
  ///
  /// - nslock: `NSLock`
  /// - nsrecursiveLock: `NSRecursiveLock`
  /// - spinLock: `SpinLock` (Bits)
  /// - mutex: `Mutex` (Bits)
  /// - readWriteLock: `ReadWriteLock` (Bits)
  public enum LockingType {
    case nslock
    case nsrecursiveLock
    case spinLock
    case mutex
    case readWriteLock
  }

  static func lock(for type: LockingType) -> Lock {
    switch type {
    case .nslock: return NSLock()
    case .nsrecursiveLock: return NSRecursiveLock()
    case .spinLock: return SpinLock()
    case .mutex: return Mutex()
    case .readWriteLock: return ReadWriteLock()
    }
  }

}
