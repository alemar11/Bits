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

class ThreadSafeTests: XCTestCase {

  func testConcurrentReadExclusiveWrite() {
    let safe = ThreadSafe.concurrentReadExclusiveWrite(qos: .default).make()
    let expectation = self.expectation(description: "\(#function)\(#line)")
    var array = [Int]()
    let iterations = 1000

    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      let last = safe.read { array.last ?? 0 }
      safe.write {
        array.append(last + 1)
        if index == 1000-1 {
          expectation.fulfill()
        }
      }
    }

    waitForExpectations(timeout: 3, handler: nil)
    XCTAssertEqual(array.count, iterations)
  }

  func testExclusiveReadExclusiveWrite() {
    let safe = ThreadSafe.exclusiveReadExclusiveWrite(qos: .default).make()
    let expectation = self.expectation(description: "\(#function)\(#line)")
    var array = [Int]()
    let iterations = 1000

    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      let last = safe.read { array.last ?? 0 }
      safe.write {
        array.append(last + 1)
        if index == 1000-1 {
          expectation.fulfill()
        }
      }
    }

    waitForExpectations(timeout: 3, handler: nil)
    XCTAssertEqual(array.count, iterations)
  }

  func testLocked() {
    let safe = ThreadSafe.locked(lock: NSRecursiveLock()).make()
    var array = [Int]()
    let iterations = 1000

    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      safe.write {
        let last = safe.read { array.last ?? 0 } // recursive locking
        array.append(last + 1)
      }
    }

    XCTAssertEqual(array.count, iterations)
  }

}
