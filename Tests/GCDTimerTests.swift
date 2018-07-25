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

class GCDTimerTests: XCTestCase {

//  func testStress() {
//    (1...100).forEach { index in
//      print(index)
////      testResume()
////      testSuspend()
////      testCancel()
//      testOnce()
////      testStop()
////      testDeinit()
////      testMultiStop()
//    }
//  }

  func testResume() {
    let expectation = self.expectation(description: "\(#function)\(#line)")
    let timer = GCDTimer(interval: .seconds(1), infinite: false, tolerance: .nanoseconds(0), queue: .main) { timer in
      expectation.fulfill()
    }

    timer.resume()
    wait(for: [expectation], timeout: 5)
    timer.resume() // it does nothing
  }

  func testSuspend() {
    let timer = GCDTimer(interval: .seconds(1), queue: .main) { timer in }

    timer.resume()
    timer.suspend()
    XCTAssertTrue(timer.isSuspended)
    timer.resume()
  }

  func testCancel() {
    let timer = GCDTimer(interval: .seconds(1), queue: .main) { timer in }

    timer.resume()
    timer.cancel()
    XCTAssertTrue(timer.isCancelled)
    timer.resume()
  }

  func testOnce() { // FIXME: race if we don't pass the .main queue
    let expectation = self.expectation(description: "\(#function)\(#line)")
    let timer = GCDTimer(interval: .milliseconds(1), queue: .main) { timer in
      timer.cancel()
      expectation.fulfill()
    }

    timer.resume()

    wait(for: [expectation], timeout: 5)
    XCTAssertTrue(timer.isCancelled)
  }

  func testStop() { // FIXME: race if we don't pass the .main queue
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    let expectation2 = self.expectation(description: "\(#function)\(#line)")
    let count = Atomic(0)
    let lock = NSLock()
    let timer = GCDTimer(interval: .nanoseconds(1), queue: .main) { timer  in
//      let t = timer.ticks
//      print(t)

      XCTAssertEqual(timer.ticks, 1)

      switch count.value {
      case 0:
        timer.stop()
        timer.resume()
        expectation1.fulfill()

      case 1: expectation2.fulfill()
      default: XCTFail("Unexpected event")
      }
      count.mutate { $0 += 1 }
    }

    timer.resume()
    wait(for: [expectation1, expectation2], timeout: 30)
  }

  func testDeinit() {
    var timer: GCDTimer? = GCDTimer(interval: .seconds(1), queue: .main) { timer in }
    weak var weakTimer = timer
    timer = nil
    XCTAssertNil(weakTimer)
  }

  func testMultiStop() {
    let timer = GCDTimer(interval: .seconds(1), queue: .main) { timer in }
    timer.resume()
    timer.stop()
    timer.stop()
    timer.resume()
  }

}

