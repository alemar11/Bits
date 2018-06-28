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

class ThrottlerTests: XCTestCase {

  func testThrottler() {
    var value = 0
    let block = { value += 1 }
    let throttler = TimedLimiter(limit: .seconds(1))
    let expectation = self.expectation(description: "\(#function)\(#line)")

    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
      if value == 1 {
        expectation.fulfill()
      } else {
        XCTFail("Failed to throttle, \(value) calls were not ignored instead of 1.")
      }
    }

    throttler.execute { block() }
    throttler.execute { block() }
    throttler.execute { block() }
    throttler.execute { block() }
    throttler.execute { block() }

    wait(for: [expectation], timeout: 2)
  }

  func testThrottlerHavingAllTheFuncationCallsCompelted() {
    var value = 0
    let block = { value += 1 }
    let repeats = 100
    let throttler = TimedLimiter(limit: .milliseconds(repeats))

    let scheduler = Scheduler(timeInterval: Double(0.350), repeats: repeats) {
      throttler.execute { block() }
    }

    scheduler.start()

    wait(for: [scheduler.completionExpectation], timeout: 60)
    XCTAssertEqual(value, repeats, "Only \(value) blocks have been called, expecting \(repeats) blocks.")
  }

  func testThrottlerHavingOneThirdOfTheFunctionCallsCompleted() {
    var value = 0
    let block = { value += 1 }
    let repeats = 100
    let throttler = TimedLimiter(limit: .milliseconds(800))

    let scheduler = Scheduler(timeInterval: Double(0.350), repeats: repeats) {
      throttler.execute { block() }
    }

    scheduler.start()

    wait(for: [scheduler.completionExpectation], timeout: 60)
    // 1/3 of the repeats should be done
    XCTAssertTrue(33...34 ~= value, "The test ended with \(value) block called; expected 33/34.")
  }
}

fileprivate class Scheduler {
  let timeInterval: TimeInterval
  var timer: Timer!
  let repeats: Int
  let completionExpectation = XCTestExpectation(description: "scheduler")
  let block: () -> Void

  private var _times = 0
  var times: Int {
    get { return _times }
    set {
      _times = newValue
      if _times >= repeats {
        completionExpectation.fulfill()
      }
    }
  }

  init(timeInterval: TimeInterval, repeats: Int = 100, block: @escaping () -> Void) {
    self.timeInterval = timeInterval
    self.repeats = repeats
    self.block = block
  }

  func start() {
    timer = Timer.scheduledTimer(timeInterval: timeInterval, target: self, selector: #selector(broadcast), userInfo: nil, repeats: false)
  }

  func stop() {
    timer.invalidate()
  }

  @objc
  func broadcast() {
    DispatchQueue(label: "\(#function)\(#line)").async { [weak self] in
      self?.block()
    }
    times += 1
    if times < repeats {  // set the next timer
      self.start()
    }

  }

}
