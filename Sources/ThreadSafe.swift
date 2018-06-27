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


/// ThreadSafe
///
/// - exclusiveReadExclusiveWrite: Only one thread can read or write at one time. The writing operation is asynchronous while the reading is synchronous.
/// - concurrentReadExclusiveWrite: Only one thread can write or multiple threads can read. The writing operation is asynchronous while the reading is synchronous.
/// - locked: Only one thread can read or write at one time. The writing and reading operations are both synchronous.
public enum ThreadSafe {
  case exclusiveReadExclusiveWrite(qos: DispatchQoS)
  case concurrentReadExclusiveWrite(qos: DispatchQoS)
  case locked(lock: NSLocking)

  public func make() -> ThreadSafeType {
    switch self {
    case .exclusiveReadExclusiveWrite(qos: let qos):
      return ExclusiveReadExclusiveWrite(qos: qos)
    case .concurrentReadExclusiveWrite(qos: let qos):
      return ConcurrentReadExclusiveWrite(qos: qos)
    case .locked(lock: let lock):
      return Locked(lock: lock)
    }
  }
}

/// Represents a thread safe access.
public protocol ThreadSafeType {

  /// Thread safe read operation.
  func read<T>(_ block: () -> T) -> T

  /// Thread safe write operation.
  func write(_ block: @escaping () -> Void)
}

/// Exclusive read, exclusive write. Only one thread can read or write at one time.
/// The writing operation is asynchronous while the reading is synchronous.
final class ExclusiveReadExclusiveWrite: ThreadSafeType {
  private let queue: DispatchQueue

  init(qos: DispatchQoS = .default) {
    self.queue = DispatchQueue(label: "\(identifier).\(type(of:self))", qos: qos)
  }

  func read<T>(_ block: () -> T) -> T {
    return queue.sync(execute: block)
  }

  func write(_ block: @escaping () -> Void) {
    queue.async(execute: block)
  }
}

/// Concurrent read, exclusive write.
/// Only one thread can write or multiple threads can read.
/// Write waits for all previously-enqueued multiple threads can read. Write waits for all previously-enqueued.
/// The writing operation is asynchronous while the reading is synchronous.
final class ConcurrentReadExclusiveWrite: ThreadSafeType {
  private let queue: DispatchQueue

  init(qos: DispatchQoS = .default) {
    self.queue = DispatchQueue(label: "\(identifier).\(type(of:self))", qos: qos, attributes: .concurrent)
  }

  func read<T>(_ block: () -> T) -> T {
    return queue.sync(execute: block)
  }

  public func write(_ block: @escaping () -> Void) {
    queue.async(flags: .barrier, execute: block)
  }
}

/// Exclusive read, exclusive write. Only one thread can read or write at one time.
final class Locked: ThreadSafeType {
  private let lock: NSLocking

  init(lock: NSLocking = NSLock()) {
    self.lock = lock
  }

  func read<T>(_ block: () -> T) -> T {
    lock.lock(); defer { lock.unlock() }
    return block()
  }

  func write(_ block: @escaping () -> Void) {
    lock.lock(); defer { lock.unlock() }
    block()
  }

}
