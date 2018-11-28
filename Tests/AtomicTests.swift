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
  
  // MARK: - Atomic
  
  func testAtomicMethods() {
    let myVar = Atomic([1, 2, 3, 4, 5, 6, 7, 8, 9], lock: NSLock())
    
    XCTAssertEqual(myVar.read { $0.first }, 1)
    
    myVar.write { $0.append(10) }
    
    XCTAssertEqual(myVar.read { $0 }, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    
    myVar.write { $0 = [10] }
    let sum = myVar.safeAccess { (array) -> Int in
      return array.reduce(0, +)
    }
    
    XCTAssertEqual(myVar.read { $0 }, [10])
    XCTAssertEqual(sum, 10)
    
    let swap = myVar.safeAccess { array -> [Int] in
      let copy = array
      array = [1, 2, 3]
      return copy
    }
    
    XCTAssertEqual(swap, [10])
    XCTAssertEqual(myVar.read { $0 }, [1, 2, 3])
    
    let result = myVar.safeAccess { array -> Int in
      return 11
    }
    
    XCTAssertEqual(myVar.read { $0 }, [1, 2, 3])
    XCTAssertEqual(result, 11)
  }
  
  func testAtomicUsingNSLock() {
    let array = Atomic<[Int]>([], lock: NSLock())
    let iterations = 1000
    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      array.write { array in
        array.append(index)
      }
    }
    XCTAssertEqual(array.value.count, iterations)
  }
  
  func testAtomicUsingNSRecursiveLock() {
    let array = Atomic<[Int]>([], lock: NSRecursiveLock())
    let iterations = 1000
    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      array.write { _array in
        _array.append(index)
      }
    }
    XCTAssertEqual(array.value.count, iterations)
  }
  
  func testAtomicUsingMutex() {
    let array = Atomic<[Int]>([], lock: Mutex())
    let iterations = 1000
    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      array.write { array in
        array.append(index)
      }
    }
    XCTAssertEqual(array.value.count, iterations)
  }
  
  func testAtomicUsingRecursiveMutex() {
    let mutex = Mutex(recursive: true)
    let array = Atomic<[Int]>([], lock: mutex)
    let iterations = 1000
    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      array.write { array in
        mutex.lock()
        array.append(index)
        mutex.unlock()
      }
    }
    XCTAssertEqual(array.value.count, iterations)
  }
  
  func testAtomicUsingUnfairLock() {
    let array = Atomic<[Int]>([], lock: UnfairLock())
    let iterations = 1000
    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      array.write { array in
        array.append(index)
        
      }
    }
    XCTAssertEqual(array.value.count, iterations)
  }
  
  // MARK: - DispatchedAtomic
  
  func testDispatchedAtomicMethods() {
    let myVar = DispatchedAtomic([1, 2, 3, 4, 5, 6, 7, 8, 9])
    
    XCTAssertEqual(myVar.read { $0.first }, 1)
    
    myVar.write { $0.append(10) }
    
    XCTAssertEqual(myVar.read { $0 }, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    
    myVar.write { $0 = [10] }
    let sum = myVar.safeAccess { (array) -> Int in
      return array.reduce(0, +)
    }
    
    XCTAssertEqual(myVar.read { $0 }, [10])
    XCTAssertEqual(sum, 10)
    
    let swap = myVar.safeAccess { array -> [Int] in
      let copy = array
      array = [1, 2, 3]
      return copy
    }
    
    XCTAssertEqual(swap, [10])
    XCTAssertEqual(myVar.read { $0 }, [1, 2, 3])
    
    let result = myVar.safeAccess { array -> Int in
      return 11
    }
    
    XCTAssertEqual(myVar.read { $0 }, [1, 2, 3])
    XCTAssertEqual(result, 11)
  }
  
  func testDispatchedAtomic() {
    let array = DispatchedAtomic([Int]())
    let iterations = 1000
    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      array.write { array in
        array.append(index)
      }
    }
    XCTAssertEqual(array.read { $0.count }, iterations)
  }
  
}
