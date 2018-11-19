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
    case 0: break // Success
    case EAGAIN: fatalError("The system lacked the necessary resources (other than memory) to initialise another mutex.")
    case ENOMEM: fatalError("Insufficient memory exists to initialise the mutex.")
    case EPERM: fatalError("The caller does not have the privilege to perform the operation.")
    case EBUSY: fatalError("The implementation has detected an attempt to re-initialise the object referenced by mutex, a previously initialised, but not yet destroyed, mutex.")
    case EINVAL: fatalError("Invalid attributes.")
    default: fatalError("Could not create mutex, unspecified error \(error).")
    }
  }

  public func lock() {
    let error = pthread_mutex_lock(&mutex)

    switch error {
    case 0:
    break // Success
    case EINVAL: fatalError("The value specified by mutex does not refer to an initialised mutex object.")
    case EAGAIN: fatalError("The mutex could not be acquired because the maximum number of recursive locks for mutex has been exceeded.")
    case EDEADLK: fatalError("The current thread already owns the mutex. (Deadlock)")
    default: fatalError("Could not create mutex, unspecified error \(error).")
    }
  }

  public func trylock() { //TODO: should return true or false
    let status = pthread_mutex_trylock(&mutex)
    switch status {
    case 0:
      break
    case EBUSY:
      fatalError("EBUSY")
    case EAGAIN:
      fatalError("EAGAIN")
    default:
      fatalError("Unexpected pthread mutex error code: \(status)")
    }
  }

  public func unlock() {
    let error =  pthread_mutex_unlock(&mutex)

    switch error {
    case 0: break // Success
    case EINVAL: fatalError("The mutex was created with the protocol attribute having the value PTHREAD_PRIO_PROTECT and the calling thread's priority is higher than the mutex's current priority ceiling.")
    case EAGAIN: fatalError("The mutex could not be acquired because the maximum number of recursive locks for mutex has been exceeded.")
    case EPERM: fatalError("The current thread does not own the mutex.")
    default: fatalError("Could not create mutex, unspecified error \(error).")
    }
  }

  deinit {
    assert(pthread_mutex_trylock(&self.mutex) == 0 && pthread_mutex_unlock(&self.mutex) == 0, "Deinitialization results in undefined behavior.")
    let error = pthread_mutex_destroy(&self.mutex)

    switch error {
    case 0: break // Success
    case EBUSY: fatalError("The implementation has detected an attempt to destroy the object referenced by mutex while it is locked or referenced.")
    case EINVAL: fatalError("The value specified by mutex is invalid.")
    default: fatalError("Could not create mutex, unspecified error \(error).")
    }
  }

}
