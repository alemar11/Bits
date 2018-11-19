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
///
/// A mutex that can be acquired by the same thread many times.
public final class RecursiveMutex {
  private var mutex: pthread_mutex_t = pthread_mutex_t()

  public init() {
    var attributes: pthread_mutexattr_t = pthread_mutexattr_t()
    pthread_mutexattr_init(&attributes)
    pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE)

    let status = pthread_mutex_init(&self.mutex, &attributes)
    pthread_mutexattr_destroy(&attributes)

    guard status == 0 else {
      fatalError(String(cString: strerror(status)))
    }
  }

  public func lock() {
    let status = pthread_mutex_lock(&mutex)
    guard status == 0 else {
      fatalError(String(cString: strerror(status)))
    }
  }

  @discardableResult
  public func `try`() -> Bool {
    let status = pthread_mutex_trylock(&mutex)
    return status == 0
  }

  public func unlock() {
    let status =  pthread_mutex_unlock(&mutex)
    guard status == 0 else {
      fatalError(String(cString: strerror(status)))
    }
  }

  deinit {
    assert(pthread_mutex_trylock(&self.mutex) == 0 && pthread_mutex_unlock(&self.mutex) == 0, "Deinitialization results in undefined behavior.")
    let status = pthread_mutex_destroy(&self.mutex)
    guard status == 0 else {
      fatalError(String(cString: strerror(status)))
    }
  }

}
