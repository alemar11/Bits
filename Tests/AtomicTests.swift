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

class AtomicTests: XCTestCase {

  func testNSLock() {
    let array = Atomic<[Int]>([])
    let iterations = 1000
    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      // array.value.append(1) isn't thread safe, the only way to mutate the array is using 'modify' or `mutate`
      array.modify({ array -> [Int] in
        var copy = array
        copy.append(index)
        return copy
      })
    }
    XCTAssertEqual(array.value.count, iterations)
    let prev = array.swap([1])
    XCTAssertEqual(prev.count, iterations)
    XCTAssertEqual(array.value.count, 1)
    XCTAssertEqual(array.with { $0.reduce(0, +) }, 1)
  }

  func testNSRecursiveLock() {
    let array = Atomic<[Int]>([], lockingType: .nsrecursiveLock)
    let iterations = 1000
    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      array.modify({ array -> [Int] in
        var copy = array
        copy.append(index)
        return copy
      })
    }
    XCTAssertEqual(array.value.count, iterations)
    let prev = array.swap([1])
    XCTAssertEqual(prev.count, iterations)
    XCTAssertEqual(array.value.count, 1)
    XCTAssertEqual(array.with { $0.reduce(0, +) }, 1)
  }

  func testMutex() {
    let array = Atomic<[Int]>([], lockingType: .mutex)
    let iterations = 1000
    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      array.modify({ array -> [Int] in
        var copy = array
        copy.append(index)
        return copy
      })
    }
    XCTAssertEqual(array.value.count, iterations)
    let prev = array.swap([1])
    XCTAssertEqual(prev.count, iterations)
    XCTAssertEqual(array.value.count, 1)
    XCTAssertEqual(array.with { $0.reduce(0, +) }, 1)
  }

  func testSpinLock() {
    let array = Atomic<[Int]>([], lockingType: .spinLock)
    let iterations = 1000
    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      array.modify({ array -> [Int] in
        var copy = array
        copy.append(index)
        return copy
      })
    }
    XCTAssertEqual(array.value.count, iterations)
    let prev = array.swap([1])
    XCTAssertEqual(prev.count, iterations)
    XCTAssertEqual(array.value.count, 1)
    XCTAssertEqual(array.with { $0.reduce(0, +) }, 1)
  }

  func testReadWriteLock() {
    let array = Atomic<[Int]>([], lockingType: .readWriteLock)
    let iterations = 1000
    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      array.modify({ array -> [Int] in
        var copy = array
        copy.append(index)
        return copy
      })
    }
    XCTAssertEqual(array.value.count, iterations)
    let prev = array.swap([1])
    XCTAssertEqual(prev.count, iterations)
    XCTAssertEqual(array.value.count, 1)
    XCTAssertEqual(array.with { $0.reduce(0, +) }, 1)
  }

}
