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

// http://pubs.opengroup.org/onlinepubs/7908799/xsh/pthread_mutex_lock.html
/// A pthread-based recursive mutex lock.
public final class RecursiveMutex {
  private var mutex: pthread_mutex_t = pthread_mutex_t()

  public init() {
    var attributes: pthread_mutexattr_t = pthread_mutexattr_t()
    pthread_mutexattr_init(&attributes)
    pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE)

    let error = pthread_mutex_init(&self.mutex, &attributes)
    pthread_mutexattr_destroy(&attributes)

    switch error {
    case 0:
      break // Success

    case EAGAIN:
      fatalError("Could not create mutex: the system temporarily lacks the resources to create another mutex.")

    case EINVAL:
      fatalError("Could not create mutex: invalid attributes.")

    case ENOMEM:
      fatalError("Could not create mutex: no memory.")

    default:
      fatalError("Could not create mutex, unspecified error \(error).")
    }
  }

  private final func lock() {
    let result = pthread_mutex_lock(&self.mutex)
    switch result {
    case 0:
      break // Success

    case EDEADLK:
      fatalError("Could not lock mutex: a deadlock would have occurred.")

    case EINVAL:
      fatalError("Could not lock mutex: the mutex is invalid.")

    default:
      fatalError("Could not lock mutex: unspecified error \(result).")
    }
  }

  private final func unlock() {
    let result = pthread_mutex_unlock(&self.mutex)
    switch result {
    case 0:
      // Success
      break

    case EPERM:
      fatalError("Could not unlock mutex: thread does not hold this mutex.")

    case EINVAL:
      fatalError("Could not unlock mutex: the mutex is invalid.")

    default:
      fatalError("Could not unlock mutex: unspecified error \(result).")
    }
  }

  deinit {
    assert(pthread_mutex_trylock(&self.mutex) == 0 && pthread_mutex_unlock(&self.mutex) == 0, "Deinitialization of a locked mutex results in undefined behavior.")
    pthread_mutex_destroy(&self.mutex)
  }

  //  @discardableResult public final func locked<T>(_ block: () throws -> (T)) throws -> T {
  //    return try self.tryLocked(block)
  //  }
  //
  //  @discardableResult public final func locked<T>(_ block: () -> (T)) -> T {
  //    return try! self.tryLocked(block)
  //  }
  //
  //  /** Execute the given block while holding a lock to this mutex. */
  //  @discardableResult public final func tryLocked<T>(_ block: () throws -> (T)) throws -> T {
  //    self.lock()
  //
  //    defer {
  //      self.unlock()
  //    }
  //    let ret: T = try block()
  //    return ret
  //  }
}
