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
//  PTHREAD_MUTEX_NORMAL — no deadlock detection. A thread that attempts to relock this mutex without first unlocking it deadlocks. Attempts to unlock a mutex locked by a different thread or attempts to unlock an unlocked mutex result in undefined behavior.
//  PTHREAD_MUTEX_ERRORCHECK — provides error checking. A thread returns with an error when it attempts to relock this mutex without first unlocking it, unlock a mutex that another thread has locked, or unlock an unlocked mutex.
//  PTHREAD_MUTEX_RECURSIVE — a thread that attempts to relock this mutex without first unlocking it succeeds in locking the mutex. The relocking deadlock that can occur with mutexes of type PTHREAD_MUTEX_NORMAL can't occur with this mutex type. Multiple locks of this mutex require the same number of unlocks to release the mutex before another thread can acquire the mutex. A thread that attempts to unlock a mutex that another thread has locked, or unlock an unlocked mutex, returns with an error.
//  PTHREAD_MUTEX_DEFAULT — the default value of the type attribute. In QNX Neutrino, PTHREAD_MUTEX_DEFAULT mutexes are treated in the same way as PTHREAD_MUTEX_ERRORCHECK ones.

///
/// A mutex that can be acquired by the same thread many times.
///
/// A pthread-based mutex lock.
/// An object that coordinates the operation of multiple threads of execution within the same application.
/// Ensures that only one thread is active in a given region of code at a time. You can think of it as a semaphore with a maximum count of 1.

/// A pthread-based mutex lock.
public final class Mutex {
  private var mutex: pthread_mutex_t = pthread_mutex_t()

  public init(recursive: Bool = false) {
    var attributes: pthread_mutexattr_t = pthread_mutexattr_t()
    pthread_mutexattr_init(&attributes)
    defer {
      pthread_mutexattr_destroy(&attributes)
    }
    pthread_mutexattr_settype(&attributes, recursive ? PTHREAD_MUTEX_RECURSIVE : PTHREAD_MUTEX_ERRORCHECK)

    let status = pthread_mutex_init(&self.mutex, &attributes)
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
