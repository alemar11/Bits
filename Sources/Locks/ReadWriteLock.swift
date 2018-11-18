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

// TODO: add errors http://pubs.opengroup.org/onlinepubs/009696899/functions/pthread_rwlock_trywrlock.html

/// A pthread-based read-write lock
public final class ReadWriteLock {

//  private var rwlock: pthread_rwlock_t = {
//    var rwlock = pthread_rwlock_t()
//    pthread_rwlock_init(&rwlock, nil)
//    return rwlock
//  }()

  private var rwlock: pthread_rwlock_t = pthread_rwlock_t()

  init() {
    pthread_rwlock_init(&rwlock, nil)
  }

  func writeLock() {
    pthread_rwlock_wrlock(&rwlock)
  }

  func readLock() {
    pthread_rwlock_rdlock(&rwlock)
  }

  func unlock() {
    pthread_rwlock_unlock(&rwlock)
  }

  deinit {
    assert(pthread_rwlock_trywrlock(&self.rwlock) == 0 && pthread_rwlock_unlock(&self.rwlock) == 0, "Deinitialization of a locked read-write lock results in undefined behavior.")
    pthread_rwlock_destroy(&self.rwlock)
  }

}
