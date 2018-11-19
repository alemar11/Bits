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

final class AtomicTests: XCTestCase {
  
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
    let array = Atomic<[Int]>([], lock: NSRecursiveLock())
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
    let array = Atomic<[Int]>([], lock: Mutex())
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

  func testRecursiveMutex() {
    let array = Atomic<[Int]>([], lock: RecursiveMutex())
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
    let array = Atomic<[Int]>([], lock: SpinLock())
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
  
//  func testReadWriteLock() {
//    let array = Atomic<[Int]>([], lockingType: .readWriteLock)
//    let iterations = 1000
//    DispatchQueue.concurrentPerform(iterations: iterations) { index in
//      array.modify { array -> [Int] in
//        var copy = array
//        copy.append(index)
//        return copy
//      }
//    }
//    XCTAssertEqual(array.value.count, iterations)
//    let prev = array.swap([1])
//    XCTAssertEqual(prev.count, iterations)
//    XCTAssertEqual(array.value.count, 1)
//    XCTAssertEqual(array.with { $0.reduce(0, +) }, 1)
//  }

}

// http://www.vadimbulavin.com/atomic-properties/

//class ReadWriteLockAtomicProperty {
//  private var underlyingFoo = 0
//  private let lock = ReadWriteLock()
//
//  var foo: Int {
//    get {
//      lock.readLock()
//      let value = underlyingFoo
//      lock.unlock()
//      return value
//    }
//    set {
//      lock.writeLock()
//      underlyingFoo = newValue
//      lock.unlock()
//    }
//  }
//}
//
//public final class ReadWriteLockAtomic<T> {
//
//  private let lock = ReadWriteLock()
//  private var _value: T
//
//  public init(_ value: T) {
//    self._value = value
//  }
//
//  public func with<U>(_ value: (T) -> U) -> U {
//    lock.readLock()
//    defer { lock.unlock() }
//    return value(_value)
//  }
//
//  public func modify(_ modify: (T) -> T) {
//    lock.writeLock()
//    _value = modify(_value)
//    lock.unlock()
//  }
//
//  public func mutate(_ transform: (inout T) -> Void) {
//    lock.writeLock()
//    transform(&_value)
//    lock.unlock()
//  }
//
//  @discardableResult
//  public func swap(_ value: T) -> T {
//    lock.writeLock()
//    let current = _value
//    _value = value
//    lock.unlock()
//    return current
//  }
//
//  public var value: T {
//    get {
//      lock.readLock()
//      let value = _value
//      lock.unlock()
//      return value
//    }
//    set {
//      lock.writeLock()
//      _value = newValue
//      lock.unlock()
//    }
//  }
//}
