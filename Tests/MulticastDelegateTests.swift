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

private protocol DispatcherDelegate: class {
  func didDispatch()
}

private class Listener: DispatcherDelegate {
  var didDispatch_callsCount = 0
  
  func didDispatch() {
    didDispatch_callsCount += 1
  }
}

private class ExpectationListener: DispatcherDelegate {
  var failIfCalled = false
  
  func didDispatch() {
    if failIfCalled {
      XCTFail("The delegate shouldn't be called.")
    }
  }
}

final class MulticastDelegateTests: XCTestCase {
  
  func testCallingSingleDelegate() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let listener = Listener()
    
    delegates.addDelegate(listener)
    delegates.invoke { $0.didDispatch() }
    
    XCTAssertEqual(listener.didDispatch_callsCount, 1)
  }
  
  func testAddingDelegates() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let listener1 = Listener()
    let listener2 = Listener()
    let listener3 = Listener()
    
    delegates.addDelegate(listener1)
    delegates.addDelegate(listener2)
    delegates.addDelegate(listener3)
    delegates.invoke { $0.didDispatch() }
    
    XCTAssertEqual(listener1.didDispatch_callsCount, 1)
    XCTAssertEqual(listener2.didDispatch_callsCount, 1)
    XCTAssertEqual(listener3.didDispatch_callsCount, 1)
  }
  
  func testRemovingDelegates() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let listener1 = Listener()
    let listener2 = Listener()
    let listener3 = Listener()
    
    delegates.addDelegate(listener1)
    delegates.addDelegate(listener2)
    delegates.addDelegate(listener3)
    delegates.invoke { $0.didDispatch() }
    delegates.removeDelegate(listener3)
    delegates.invoke { $0.didDispatch() }
    delegates.removeDelegate(listener2)
    delegates.invoke { $0.didDispatch() }
    
    XCTAssertEqual(listener1.didDispatch_callsCount, 3)
    XCTAssertEqual(listener2.didDispatch_callsCount, 2)
    XCTAssertEqual(listener3.didDispatch_callsCount, 1)
  }
  
  func testKeepingWeakReferences() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let listener1 = Listener()
    delegates.addDelegate(listener1)
    
    autoreleasepool {
      let listener2 = Listener()
      delegates.addDelegate(listener2)
    }
    
    var numberOfCallsMade = 0
    delegates.invoke { _ in numberOfCallsMade += 1 }
    
    XCTAssertEqual(numberOfCallsMade, 1)
  }
  
  func testOperators() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let listener1 = Listener() as DispatcherDelegate
    let listener2 = Listener() as DispatcherDelegate
    let listener3 = Listener() as DispatcherDelegate
    delegates += listener1
    delegates += listener2
    delegates += listener3
    
    XCTAssertEqual(delegates.count, 3)
    XCTAssertTrue(delegates.containsDelegate(listener1))
    XCTAssertTrue(delegates.containsDelegate(listener2))
    XCTAssertTrue(delegates.containsDelegate(listener3))
    
    delegates -= listener1
    delegates -= listener2
    delegates -= listener3
    
    XCTAssertEqual(delegates.count, 0)
    XCTAssertFalse(delegates.containsDelegate(listener1))
    XCTAssertFalse(delegates.containsDelegate(listener2))
    XCTAssertFalse(delegates.containsDelegate(listener3))
  }
  
  func testWeakReference() {
    var listener: ExpectationListener? = ExpectationListener()
    listener?.failIfCalled = true
    weak var weakListener = listener
    let delegates = MulticastDelegate<DispatcherDelegate>()
    delegates.addDelegate(weakListener!)
    listener = nil
    delegates.invoke { $0.didDispatch() }
  }
  
  func testWeakReferences() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    autoreleasepool {
      (0...9).forEach { _ in
        let listener = Listener()
        delegates.addDelegate(listener)
      }
    }
    
    XCTAssertTrue(delegates.isEmpty)
  }
  
  func testStrongReferences() {
    let delegates = MulticastDelegate<DispatcherDelegate>(usingStrongReferences: true)
    autoreleasepool {
      (0...9).forEach { _ in
        let listener = Listener()
        delegates.addDelegate(listener)
      }
    }
    
    XCTAssertEqual(delegates.count, 10)
  }
}
