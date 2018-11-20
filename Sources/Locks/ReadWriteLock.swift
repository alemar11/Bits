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

// http://pubs.opengroup.org/onlinepubs/7908799/xsh/pthread_rwlock_init.html
// https://medium.com/@dmytro.anokhin/concurrency-in-swift-reader-writer-lock-4f255ae73422

import Darwin.os.lock

/// **Bits**
///
/// A pthread-based read-write lock.
///
/// Provides concurrent access for read-only operations, but exclusive access for write operations.
///
/// Efficient when reading is common and writing is rare.
/// - Note: 
public final class ReadWriteLock {

  // Initialization: pthread_rwlock_t is a value type and must be declared as var in order to refer it later. Make sure not to copy it.
  private var lock = pthread_rwlock_t()

  init() {
    let status = pthread_rwlock_init(&lock, nil)
    guard status == 0 else {
      fatalError(String(cString: strerror(status)))
    }
  }

  func writeLock() {
    let status = pthread_rwlock_wrlock(&lock)
    guard status == 0 else {
      fatalError(String(cString: strerror(status)))
    }
  }

  func readLock() {
    let status = pthread_rwlock_rdlock(&lock)
    guard status == 0 else {
      fatalError(String(cString: strerror(status)))
    }
  }

  func unlock() {
    let status = pthread_rwlock_unlock(&lock)
    guard status == 0 else {
      fatalError(String(cString: strerror(status)))
    }
  }

  func `try`() -> Bool {
    let status = pthread_rwlock_trywrlock(&self.lock)
    return status == 0
  }

  deinit {
    assert(pthread_rwlock_trywrlock(&self.lock) == 0 && pthread_rwlock_unlock(&self.lock) == 0, "Deinitialization results in undefined behavior.")

    let status = pthread_rwlock_destroy(&self.lock)
    guard status == 0 else {
      fatalError(String(cString: strerror(status)))
    }
  }

}
