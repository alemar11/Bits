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

class SchedulerTests: XCTestCase {

  func testStartAndPause() {
    let expectation = self.expectation(description: "\(#function)\(#line)")
    let timer = Scheduler(interval: .milliseconds(500), mode: .infinite) { _ in }

    timer.onStateChanged = { (_, state) in
      if state == .paused {
        expectation.fulfill()
        XCTAssertTrue(timer.state.isPaused)
        XCTAssertFalse(timer.pause())
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
      timer.pause()
    }

    XCTAssertFalse(timer.state.isRunning)
    XCTAssertTrue(timer.start())
    XCTAssertFalse(timer.start())
    wait(for: [expectation], timeout: 30)
    XCTAssertTrue(timer.state.isPaused)
    XCTAssertTrue(timer.mode.isInfinite)

  }

  func testFireAndThenPause() {
    let expectation = self.expectation(description: "\(#function)\(#line)")
    var value = 0
    let timer = Scheduler(interval: .milliseconds(500), mode: .infinite) { _ in
      value += 1
    }

    timer.onStateChanged = { (_, state) in
      if state == .paused {
        expectation.fulfill()
        timer.pause()
      }
    }

    timer.fire(andThenPause: true)

    wait(for: [expectation], timeout: 30)
    XCTAssertEqual(value, 1)
    XCTAssertTrue(timer.state.isPaused)
    XCTAssertFalse(timer.state.isRunning)
  }

  func testFireOnce() {
    let expectation = self.expectation(description: "\(#function)\(#line)")
    let timer = Scheduler.once(after: .milliseconds(500), queue: DispatchQueue(label: "\(#function)\(#file)")) { _ in
      XCTAssertFalse(Thread.isMainThread)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 2)
    XCTAssertTrue(timer.state.isFinished)
    XCTAssertFalse(timer.state.isRunning)
  }

  func testFireEverySecond() {
    let expectation = self.expectation(description: "\(#function)\(#line)")
    var value = 0
    let count = 5
    let timer = Scheduler.every(.seconds(1), count: count, queue: .main) { timer in
      XCTAssertEqual(timer.remainingIterations, count-value)
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertTrue(timer.state.isRunning)
      XCTAssertTrue(timer.state.isExecuting)
      value += 1
      if value >= 5 {
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5)
    XCTAssertTrue(timer.state.isFinished)
    XCTAssertTrue(timer.mode.isRepeating)
    XCTAssertFalse(timer.state.isRunning)
    XCTAssertFalse(timer.mode.isInfinite)
  }

  func testAddAndRemoveObservers() {
    let timer = Scheduler(interval: .milliseconds(500)) { _ in } // 1
    let token1 = timer.addObserver { _ in } // 2
    timer.addObserver { _ in } // 3
    timer.addObserver { _ in } // 4

    XCTAssertEqual(timer.observers.count, 4)
    timer.removeObserver(withToken: token1)
    timer.removeObserver(withToken: UUID())
    XCTAssertEqual(timer.observers.count, 3)
    timer.removeAllObservers()
    XCTAssertTrue(timer.observers.isEmpty)

    XCTAssertTrue(timer.mode.isInfinite)
    XCTAssertTrue(timer.state.isPaused)
  }

  func testRemoveAllObserversAndPause() {
    let expectation = self.expectation(description: "\(#function)\(#line)")
    var value1 = 0
    var value2 = 0
    var value3 = 0

    let scheduler = Scheduler(interval: .milliseconds(250)) { _ in
      value1 += 1
    }

    scheduler.addObserver { timer in
      value2 += 1
      XCTAssertEqual(scheduler, timer)
    }

    scheduler.addObserver { timer in
      value3 += 1
      XCTAssertEqual(scheduler, timer)
    }

    scheduler.onStateChanged = { (_, state) in
      if state == .paused {
        expectation.fulfill()
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
      scheduler.removeAllObservers(thenStop: true)
    }

    scheduler.start()
    wait(for: [expectation], timeout: 5)
    XCTAssertTrue(value1 > 0 )
    XCTAssertTrue(value2 > 0 )
    XCTAssertTrue(value3 > 0 )
  }

  func testInitializeWithAllTheOperationAndDefaultParameters() {
    let expectation = self.expectation(description: "\(#function)\(#line)")
    let timer = Scheduler(interval: .nanoseconds(1_000), mode: .infinite, tolerance: .nanoseconds(0), queue: .main) { _ in
      XCTAssertTrue(Thread.isMainThread)
    }
    XCTAssertTrue(timer.mode.isInfinite)
    XCTAssertNil(timer.mode.countIterations)
    XCTAssertTrue(timer.start())
    XCTAssertFalse(timer.start())

    timer.onStateChanged = { (_, state) in
      if state == .paused {
        expectation.fulfill()
        XCTAssertTrue(timer.state.isPaused)
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
    let timer = Scheduler.every(.milliseconds(500), count: 10, queue: nil) { _ in }

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

  func testReset() {
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    let expectation2 = self.expectation(description: "\(#function)\(#line)")
    let expectation3 = self.expectation(description: "\(#function)\(#line)")
    let timer = Scheduler(interval: .seconds(1), mode: .infinite, queue: nil) { _ in }

    timer.onIntervalChanged = { (_, interval) in
      switch interval {
      case .seconds(let value) where value == 2:
        expectation1.fulfill()
      case .nanoseconds(let value) where value == 500:
        expectation2.fulfill()
      default:
        XCTFail("The scheduler should not have changed the interval in \(interval)")
      }
    }

    timer.start()
    timer.reset(.seconds(2), restart: false)
    XCTAssertTrue(timer.state.isPaused)
    timer.start()
    timer.reset(.nanoseconds(500), restart: true)

    wait(for: [expectation1, expectation2], timeout: 5)

    timer.addObserver { _ in
      expectation3.fulfill()
      timer.pause()
    }

    wait(for: [expectation3], timeout: 1)
  }

}
