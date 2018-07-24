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

internal protocol Lock {
  func writeLock()
  func readLock()
  func unlock()
}

extension NSLock: Lock {
  internal func writeLock() {
    lock()
  }
  internal func readLock() {
    lock()
  }
}

extension NSRecursiveLock: Lock {
  internal func writeLock() {
    lock()
  }
  internal func readLock() {
    lock()
  }
}

/// An object that coordinates the operation of multiple threads of execution within the same application.
/// Causes a thread trying to acquire a lock to wait in a loop while checking if the lock is available. It is efficient if waiting is rare, but wasteful if waiting is common.
public final class SpinLock {

  private var unfairLock = os_unfair_lock_s()

  public func lock() {
    os_unfair_lock_lock(&unfairLock)
  }

  public func unlock() {
    os_unfair_lock_unlock(&unfairLock)
  }
}

extension SpinLock: Lock {
  func writeLock() {
    lock()
  }

  func readLock() {
    lock()
  }
}

/// An object that coordinates the operation of multiple threads of execution within the same application.
/// Eensures that only one thread is active in a given region of code at a time. You can think of it as a semaphore with a maximum count of 1.
public final class Mutex {

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

extension Mutex: Lock {
  func writeLock() {
    lock()
  }

  func readLock() {
    lock()
  }
}

/// Lower-level read-write lock
final class ReadWriteLock {
  private var rwlock: pthread_rwlock_t = {
    var rwlock = pthread_rwlock_t()
    pthread_rwlock_init(&rwlock, nil)
    return rwlock
  }()

  func writeLock() {
    pthread_rwlock_wrlock(&rwlock)
  }

  func readLock() {
    pthread_rwlock_rdlock(&rwlock)
  }

  func unlock() {
    pthread_rwlock_unlock(&rwlock)
  }
}

extension ReadWriteLock: Lock { }

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
    self.lock = Atomic.lockForType(lockType)
    self._value = value
  }

  static func lockForType(_ type: LockType) -> Lock {
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
