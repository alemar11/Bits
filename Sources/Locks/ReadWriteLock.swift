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

import Foundation

/// A pthread-based read-write lock.
public final class ReadWriteLock {

  // Initialization: pthread_rwlock_t is a value type and must be declared as var in order to refer it later. Make sure not to copy it.
  private var lock = pthread_rwlock_t()

  init() {
    let error = pthread_rwlock_init(&lock, nil)

    switch error {
    case 0: break // Success
    case EAGAIN: fatalError("The system temporarily lacks the resources to create another mutex.")
    case ENOMEM: fatalError("Insufficient memory exists to initialise the read-write lock.")
    case EPERM: fatalError("The caller does not have the privilege to perform the operation.")
    case EBUSY: fatalError("The implementation has detected an attempt to re-initialise the object referenced by rwlock, a previously initialised but not yet destroyed read-write lock.")
    case EINVAL: fatalError("Invalid attributes.")
    default: fatalError("Could not create mutex, unspecified error \(error).")
    }
  }

  func writeLock() {
    let error = pthread_rwlock_wrlock(&lock)

    switch error {
    case 0: break // Success
    case EBUSY: fatalError("The read-write lock could not be acquired for writing because it was already locked for reading or writing.")
    case EINVAL: fatalError("The value specified by rwlock does not refer to an initialised read-write lock object.")
    case EDEADLK: fatalError("The current thread already owns the read-write lock for writing or reading. (Deadlock)")
    default: fatalError("Could not create mutex, unspecified error \(error).")
    }
  }

  func readLock() {
    let error = pthread_rwlock_rdlock(&lock)

    switch error {
    case 0: break // Success
    case EBUSY: fatalError("The read-write lock could not be acquired for reading because a writer holds the lock or was blocked on it.")
    case EINVAL: fatalError("The value specified by rwlock does not refer to an initialised read-write lock object.")
    case EDEADLK: fatalError("The current thread already owns the read-write lock for writing. (Deadlock)")
    case EAGAIN: fatalError("The read lock could not be acquired because the maximum number of read locks for rwlock has been exceeded.")
    default: fatalError("Could not create mutex, unspecified error \(error).")
    }
  }

  func unlock() {
    let error = pthread_rwlock_unlock(&lock)

    switch error {
    case 0: break
    case EINVAL: fatalError("The value specified by rwlock does not refer to an initialised read-write lock object.")
    case EPERM: fatalError("The current thread does not own the read-write lock.")
    default: fatalError("Could not create mutex, unspecified error \(error).")
    }
  }

  deinit {
    assert(pthread_rwlock_trywrlock(&self.lock) == 0 && pthread_rwlock_unlock(&self.lock) == 0, "Deinitialization results in undefined behavior.")
    
    let error = pthread_rwlock_destroy(&self.lock)

    switch error {
    case 0: break // Success
    case EBUSY: fatalError("The implementation has detected an attempt to destroy the object referenced by rwlock while it is locked.")
    case EINVAL: fatalError("Invalid attributes.")
    default: fatalError("Could not create mutex, unspecified error \(error).")
    }
  }

}
