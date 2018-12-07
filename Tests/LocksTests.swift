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

import XCTest
@testable import Bits

final class LocksTests: XCTestCase {

  // MARK: - UnfairLock

  func testTryAcquiringUnfairLock() {
    let lock = UnfairLock()
    XCTAssertTrue(lock.try())
    XCTAssertFalse(lock.try())
    lock.unlock()
  }

  func testPerformanceUnfairLock() {
    let value = Atomic(value: 0, lock: UnfairLock())
    execute { value.write{ $0 += 1 } }
  }

  // MARK: - Mutex

  func testTryAcquiringMutex() {
    let lock = Mutex()
    XCTAssertTrue(lock.try())
    XCTAssertFalse(lock.try())
    lock.unlock()
  }

  func testPerformanceMutex() {
    let value = Atomic(value: 0, lock: Mutex())
    execute { value.write{ $0 += 1 }
    }
  }

   // MARK: - Recursive Mutex

  func testTryAcquiringRecursiveMutex() {
    let lock = Mutex(recursive: true)
    XCTAssertTrue(lock.try())
    XCTAssertTrue(lock.try())
    lock.unlock()
    lock.unlock()
  }

  func testPerformanceRecursiveMutex() {
    let value = Atomic(value: 0, lock: Mutex(recursive: true))
    execute { value.write{ $0 += 1 }
    }
  }

  // MARK: - ReadWriteLock

  func testTryAcquiringReadWriteLock() {
    let lock = ReadWriteLock()

    XCTAssertTrue(lock.try())
    XCTAssertFalse(lock.try())
    lock.unlock()

    lock.readLock()
    XCTAssertFalse(lock.try())
    lock.unlock()

    lock.writeLock()
    XCTAssertFalse(lock.try())
    lock.unlock()
  }

  func testPerformanceReadWriteLock() {
    var value = 0
    let rwLock = ReadWriteLock()
    execute {
      rwLock.writeLock()
      value += 1
      rwLock.unlock()
    }
  }

  // MARK: - Private

  private func execute(performBlock: @escaping () -> Void) {
    let dispatchBlockCount = 16
    let iterationCountPerBlock = 1000
    let queues = [DispatchQueue.global(qos: .userInteractive),
                  DispatchQueue.global(qos: .default)]

    self.measure {
      let group = DispatchGroup()
      for block in 0..<dispatchBlockCount {
        group.enter()
        let queue = queues[block % queues.count]
        queue.async {
          (0..<iterationCountPerBlock).forEach { _ in
            performBlock()
          }
          group.leave()
        }
      }
      _ = group.wait(timeout: .distantFuture)
    }
  }

}
