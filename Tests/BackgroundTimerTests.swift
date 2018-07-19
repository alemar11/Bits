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

class BackgroundTimerTests: XCTestCase {


  func testStress() {
    (1...100).forEach { (i) in
      print(i)
      testStartAndPause()
      testFireOnce()
      testFireEverySecond()
      testInitializeWithAllTheOperationAndDefaultParameters()
      testMultipleStartBetweenDifferentStates()
    }
  }



  func testStartAndPause() {
    let expectation = self.expectation(description: "\(#function)\(#line)")
    let timer = BackgroundTimer(interval: .nanoseconds(5), mode: .infinite) { _ in }

    timer.onStateChanged = { (t, state) in
      if state == .paused {
        expectation.fulfill()
        XCTAssertTrue(t.state == .paused, "The state should be paused.")
        XCTAssertFalse(t.pause(), "A paused scheduler cannot be paused again.")
      }
    }

    XCTAssertFalse(timer.state == .running, "The timer is not yet started.")

    //XCTAssertTrue(timer.start(), "The timer should start.")
    //XCTAssertFalse(timer.start(), "The timer is already started.")
    DispatchQueue.concurrentPerform(iterations: 10) { index in
      timer.start() //random concurrent start...
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      timer.pause()
    }

    wait(for: [expectation], timeout: 30)
    XCTAssertTrue(timer.state == .paused, "The state should be paused instead of \(timer.state).")
    XCTAssertTrue(timer.mode.isInfinite, "The timer mode should be \"infinite\" instead of \(timer.mode)")
  }

  func testFireOnce() {
    let expectation = self.expectation(description: "\(#function)\(#line)")
    let timer = BackgroundTimer.once(after: .milliseconds(500), queue: DispatchQueue(label: "\(#function)\(#file)")) { _ in
      XCTAssertFalse(Thread.isMainThread)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 2)
    XCTAssertTrue(timer.state == .finished)
    XCTAssertFalse(timer.state == .running)
  }

  func testFireEverySecond() {
    let expectation = self.expectation(description: "\(#function)\(#line)")
    var value = 0
    let count = 5
    let timer = BackgroundTimer.every(.seconds(1), count: count, queue: .main) { timer in
      XCTAssertEqual(timer.remainingIterations, count-value)
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertTrue(timer.state == .running)
      value += 1
      if value >= 5 {
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 6)
    XCTAssertTrue(timer.state == .finished)
    XCTAssertTrue(timer.mode.isRepeating)
    XCTAssertFalse(timer.state == .running)
    XCTAssertFalse(timer.mode.isInfinite)
  }

  func testInitializeWithAllTheOperationAndDefaultParameters() {
    let expectation = self.expectation(description: "\(#function)\(#line)")

    let timer = BackgroundTimer(interval: .nanoseconds(1_000), mode: .infinite, tolerance: .nanoseconds(0), queue: DispatchQueue(label: "test", attributes: .concurrent)) { _ in
      XCTAssertFalse(Thread.isMainThread)
    }
    XCTAssertTrue(timer.mode.isInfinite)
    XCTAssertNil(timer.mode.countIterations)
    XCTAssertTrue(timer.start())
    XCTAssertFalse(timer.start())

    timer.onStateChanged = { (_, state) in
      if state == .paused {
        expectation.fulfill()
        XCTAssertTrue(timer.state == .paused)
        XCTAssertFalse(timer.pause())
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
      timer.pause()
    }

    wait(for: [expectation], timeout: 6)
  }

  func testMultipleStartBetweenDifferentStates() {
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    let expectation2 = self.expectation(description: "\(#function)\(#line)")
    let expectation3 = self.expectation(description: "\(#function)\(#line)")
    let timer = BackgroundTimer.every(.milliseconds(500), count: 10, queue: nil) { _ in }

    var finishCount = 0
    var pauseCount = 0
    timer.onStateChanged = { (_, state) in
      switch state {
      case .finished:
        finishCount += 1
        if finishCount == 1 {
          expectation2.fulfill()
        } else {
          expectation3.fulfill() // restart
        }
      case .paused:
        pauseCount += 1
        if pauseCount == 1 {
          expectation1.fulfill()
        }
      default:
        break
      }
    }

    XCTAssertFalse(timer.start())
    XCTAssertTrue(timer.pause())

    wait(for: [expectation1], timeout: 6)
    XCTAssertTrue(timer.start())

    wait(for: [expectation2], timeout: 6)
    XCTAssertTrue(timer.start()) // restart (it's a reset, so the state will change to pause

    wait(for: [expectation3], timeout: 6)
  }

  func testPauseAnIdleTimer() {
     let timer = BackgroundTimer(interval: .seconds(1), mode: .infinite, queue: nil) { _ in }
    XCTAssertFalse(timer.pause())
  }

    func testReset() {
      let expectation1 = self.expectation(description: "\(#function)\(#line)")
      let expectation2 = self.expectation(description: "\(#function)\(#line)")
      let timer = BackgroundTimer(interval: .seconds(1), mode: .infinite, queue: nil) { _ in }

      timer.onIntervalChanged = { (_, interval) in
        switch interval {
        case .seconds(let value) where value == 2:
          expectation1.fulfill()

        case .nanoseconds(let value) where value == 500:
          expectation2.fulfill()

        default:
          XCTFail("The timer should not have changed the interval in \(interval)")
        }
      }

      timer.start()
      timer.reset(interval: .seconds(2), restart: false)
      XCTAssertTrue(timer.state == .paused)
      timer.start()
      timer.reset(interval: .nanoseconds(500), restart: true)

      wait(for: [expectation1, expectation2], timeout: 5)
    }

}

