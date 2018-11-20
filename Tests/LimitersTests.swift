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

final class LimitersTests: XCTestCase {
  
  // MARK: - Throttler

  func testThrottlerHavingAllTheFunctionCallsCompleted() {
    var count = 0
    let expectation = self.expectation(description: "\(#file)\(#line)")
    let block = {
      count += 1
      if count == 4 {
        expectation.fulfill()
      }
    }

    let throttler = Throttler(limit: .milliseconds(500)) // Execute the function at most once every 500 milliseconds
    
    let scheduler = TestScheduler(timeInterval: Double(0.240), repeats: 10) { // 2400 milliseconds
      throttler.execute { block() }
    }
    
    scheduler.start()
    // 240 milliseconds are enough to run 4 function calls and, obviously, not 5
    wait(for: [expectation], timeout: 10)
    XCTAssertEqual(count, 4, "The throttler has run the function \(count) times instead of 4.")
  }

  // MARK: - Debouncer

  func testDebouncerHavingAllTheFunctionCallsLimitedExceptTheLastOne() {
    var count = 0
    let expectation = self.expectation(description: "\(#file)\(#line)")
    let block = {
      count += 1
      expectation.fulfill()
    }
    let throttler = Debouncer(limit: .milliseconds(800)) // Execute the function only if 800 milliseconds have passed without it being called.
    
    let scheduler = TestScheduler(timeInterval: Double(0.250), repeats: 10) {  // 2500 milliseconds
      throttler.execute { block() }
    }

    // The scheduler call the function every 250 milliseconds and the debouncer is set to 800 milliseconds: the debouncer will limit every call except the last one.
    scheduler.start()
    
    wait(for: [expectation], timeout: 5)
    XCTAssertEqual(count, 1, "The dobouncer should have cancelled all the function calls except the last one.")
  }
  
  func testDebouncerHavingAllTheFunctionCallsNotLimited() {
    let expectation = self.expectation(description: "\(#file)\(#line)")
    var value = 0
    let block = {
      value += 1
      if value >= 10 {
        expectation.fulfill()
      }
    }

    let throttler = Debouncer(limit: .milliseconds(100)) // Execute this function only if 100 milliseconds have passed without it being called.
    
    let scheduler = TestScheduler(timeInterval: Double(0.600), repeats: 10) { // 6000 milliseconds
      throttler.execute { block() }
    }

    // The scheduler call the function every 600 milliseconds and the debouncer is set to 100 milliseconds: the debouncer will not limit any calls.
    scheduler.start()
    
    wait(for: [expectation], timeout: 10)
    XCTAssertEqual(value, 10, "The debouncer has run the function \(value) times instead of 10.")
  }
  
  // MARK: - Max Limiter
  
  func testLimiterHavingTheMaxNumberOfFunctionCallsRun() {
    let expectation = self.expectation(description: "\(#file)\(#line)")
    let value = Atomic(0, lock: NSLock())
    let block = {
      value.write { $0 += 1 }

      if value.value >= 5 {
        expectation.fulfill()
      }
    }
    let limiter = MaxLimiter(limit: 5)
    
    let repeats = 30
    let scheduler = TestScheduler(timeInterval: Double(0.100), repeats: repeats) {
      limiter.execute { block() }
    }
    
    scheduler.start()
    
    wait(for: [expectation], timeout: 5)
    XCTAssertEqual(value.value, 5, "The Limiter has run the function \(value.value) times instead of 10.")
  }
  
}

fileprivate final class TestScheduler {
  private let timeInterval: TimeInterval
  private let repeats: Int
  private var timer: Timer!
  private let block: () -> Void
  private(set) var times = 0
  
  init(timeInterval: TimeInterval, repeats: Int = 100, block: @escaping () -> Void) {
    self.timeInterval = timeInterval
    self.repeats = repeats
    self.block = block
  }
  
  func start() {
    timer = Timer.scheduledTimer(timeInterval: timeInterval, target: self, selector: #selector(broadcast), userInfo: nil, repeats: true)
  }
  
  func stop() {
    timer.invalidate()
  }
  
  @objc
  func broadcast(timer: Timer) {
    block()
    
    times += 1

    if times == repeats {
      stop()
    }
  }
  
}
