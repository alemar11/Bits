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

//  func testStress() {
//    (1...10).forEach { (i) in
//      print(i)
//      testStartAndPause()
//      testFireOnce()
//      testFireEverySecond()
//      testInitializeWithAllTheOperationAndDefaultParameters()
//      testMultipleStartBetweenDifferentStates()
//      testPauseAnIdleTimer()
//      testReset()
//      testResetAnIdleTimer()
//      testConcurrentAccess()
//      testResetFiniteTimer()
//      testDeinitIdleTimer()
//    }
//  }

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

    DispatchQueue.concurrentPerform(iterations: 10) { index in
      timer.start() //random concurrent start commands...
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
  }

  func testStopAfterAFireOnceTimer() {
    let expectation = self.expectation(description: "\(#function)\(#line)")
    let timer = BackgroundTimer.once(after: .milliseconds(500), queue: DispatchQueue(label: "\(#function)\(#file)")) { _ in
      XCTAssertFalse(Thread.isMainThread)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 2)
    timer.stop()
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

    wait(for: [expectation], timeout: 7)
    XCTAssertTrue(timer.state == .finished, "The timer should be in finished state instead of \(timer.state)")
    XCTAssertTrue(timer.mode.isRepeating)
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
      DispatchQueue.concurrentPerform(iterations: 10) { index in
        timer.pause() //random concurrent pause commands...
      }
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
    XCTAssertTrue(timer.start()) // restart (it's a reset, so the state will change to pause)

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

    timer.onStateChanged = { (timer, state) in
      switch (timer.interval, state) {
      case (.microseconds(let value), .running) where value == 2:
        XCTFail("This reset shouldn't have started.")

      case (.seconds(let value), .running) where value == 30:
        expectation1.fulfill()

      case (.nanoseconds(let value), .running) where value == 500:
        expectation2.fulfill()

      default:
        break
      }

    }

    timer.start()
    timer.reset(interval: .microseconds(2), restart: false)
    XCTAssertTrue(timer.state == .paused)
    timer.reset(interval: .seconds(30), restart: false)
    XCTAssertTrue(timer.state == .paused)
    timer.start() // (re)starts the timer with a new interval

    wait(for: [expectation1], timeout: 5)
    timer.reset(interval: .nanoseconds(500), restart: true) // resets and (re)starts the timer again

    wait(for: [expectation2], timeout: 5)
  }

  func testResetAnIdleTimer() {
    let timer = BackgroundTimer(interval: .seconds(1), mode: .infinite, queue: nil) { _ in }
    XCTAssertFalse(timer.pause())
    XCTAssertTrue(timer.state == .idle)
    timer.reset(interval: .nanoseconds(300), restart: true)
    XCTAssertTrue(timer.state == .running)
    timer.reset(interval: .nanoseconds(100), restart: false)
    XCTAssertTrue(timer.state == .paused)
  }

  func testConcurrentAccess() {
    let timer = BackgroundTimer(interval: .seconds(1), mode: .finite(100), queue: nil) { _ in }
    DispatchQueue.concurrentPerform(iterations: 10) { index in
      timer.start()
    }
    XCTAssertTrue(timer.state == .running)

    DispatchQueue.concurrentPerform(iterations: 10) { index in
      timer.pause()
    }
    XCTAssertTrue(timer.state == .paused)

    DispatchQueue.concurrentPerform(iterations: 10) { index in
      timer.reset(interval: .nanoseconds(500), restart: true)
    }
    XCTAssertTrue(timer.state == .running)
  }


  func testStopIdleTimer() {
    let timer = BackgroundTimer(interval: .seconds(1), mode: .infinite, queue: nil) { _ in }
    timer.stop()
    XCTAssertTrue(timer.state == .idle)
  }


  func testResetFiniteTimer() {
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    let expectation2 = self.expectation(description: "\(#function)\(#line)")
    var count = 0

    var enable1 = true
    var enable2 = false
    let timer = BackgroundTimer(interval: .seconds(1), mode: .finite(5)) { currentTimer in
      count += 1

      if count >= 5 && enable2 {
        expectation2.fulfill()
        count = 0
      }
      if count >= 5 && enable1 {
        expectation1.fulfill()
        count = 0
      }
    }

    timer.start()
    wait(for: [expectation1], timeout: 10)
    timer.reset(interval: .seconds(2), restart: false)
    enable1 = false
    enable2 = true
    timer.start()
    wait(for: [expectation2], timeout: 10)
  }

  func testDeinitIdleTimer() {
    var timer: BackgroundTimer? = BackgroundTimer(interval: .seconds(1), mode: .finite(5)) { _ in }
    weak var weakTimer = timer
    timer = nil
    XCTAssertNil(weakTimer)
  }

}

