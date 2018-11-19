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

//import XCTest
//
//class LockTests: XCTestCase {
//
//  func testSpinLock() {
//    var spinLock = OS_SPINLOCK_INIT
//    executeLockTest { (block) in
//      OSSpinLockLock(&spinLock)
//      block()
//      OSSpinLockUnlock(&spinLock)
//    }
//  }
//
//  func testUnfairLock() {
//    var unfairLock = os_unfair_lock_s()
//    executeLockTest { (block) in
//      os_unfair_lock_lock(&unfairLock)
//      block()
//      os_unfair_lock_unlock(&unfairLock)
//    }
//  }
//
//  func testDispatchSemaphore() {
//    let semaphore = DispatchSemaphore(value: 1)
//    executeLockTest { (block) in
//      _ = semaphore.wait(timeout: DispatchTime.distantFuture)
//      block()
//      semaphore.signal()
//    }
//  }
//
//  func testNSLock() {
//    let lock = NSLock()
//    executeLockTest { (block) in
//      lock.lock()
//      block()
//      lock.unlock()
//    }
//  }
//
//  func testPthreadMutex() {
//    var mutex = pthread_mutex_t()
//    pthread_mutex_init(&mutex, nil)
//    executeLockTest{ (block) in
//      pthread_mutex_lock(&mutex)
//      block()
//      pthread_mutex_unlock(&mutex)
//    }
//    pthread_mutex_destroy(&mutex);
//  }
//
//  func testReadWritePthreadMutex() {
//    var mutex = pthread_rwlock_t()
//    pthread_rwlock_init(&mutex, nil)
//    executeLockTest{ (block) in
//      pthread_rwlock_wrlock(&mutex)
//      block()
//      pthread_rwlock_unlock(&mutex)
//    }
//    pthread_rwlock_destroy(&mutex);
//  }
//
//  func testSyncronized() {
//    let object = NSObject()
//    executeLockTest{ (block) in
//      objc_sync_enter(object)
//      block()
//      objc_sync_exit(object)
//    }
//  }
//
//  func testDispatchQueue() {
//    let lockQueue = DispatchQueue.init(label: "com.test.LockQueue")
//    executeLockTest{ (block) in
//      lockQueue.sync() {
//        block()
//      }
//    }
//  }
//
//  func testNoLock() {
//    executeLockTest { (block) in
//      block()
//    }
//  }
//
//  private func executeLockTest(performBlock:@escaping (_ block:() -> Void) -> Void) {
//    let dispatchBlockCount = 16
//    let iterationCountPerBlock = 100_000
//    let queues = [
//      DispatchQueue.global(qos: .userInteractive),
//      DispatchQueue.global(qos: .default),
//      DispatchQueue.global(qos: .utility),
//      ]
//    var value = 0
//    self.measure {
//      let group = DispatchGroup()
//      for block in 0..<dispatchBlockCount {
//        group.enter()
//        let queue = queues[block % queues.count]
//        queue.async(execute: {
//          for _ in 0..<iterationCountPerBlock {
//            performBlock({
//              value = value + 2
//              value = value - 1
//            })
//          }
//          group.leave()
//        })
//      }
//      _ = group.wait(timeout: .distantFuture)
//    }
//  }
//
//}
