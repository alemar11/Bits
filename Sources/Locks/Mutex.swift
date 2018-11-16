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

// TODO: add errors

/// A pthread-based mutex lock.
/// An object that coordinates the operation of multiple threads of execution within the same application.
/// Ensures that only one thread is active in a given region of code at a time. You can think of it as a semaphore with a maximum count of 1.
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

  deinit {
    assert(pthread_mutex_trylock(&self.mutex) == 0 && pthread_mutex_unlock(&self.mutex) == 0, "Deinitialization of a locked mutex results in undefined behavior.")
    pthread_mutex_destroy(&self.mutex)
  }
}
