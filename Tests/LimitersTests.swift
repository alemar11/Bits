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

final class ThrottlerTests: XCTestCase {
  
  // MARK: - Throttler
  
//  func testThrottler() {
//    var value = 0
//    let block = { value += 1 }
//    let throttler = Throttler(limit: .seconds(1))
//    let expectation = self.expectation(description: "\(#function)\(#line)")
//
//    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
//      if value == 1 {
//        expectation.fulfill()
//      } else {
//        XCTFail("Failed to throttle, \(value) calls were not ignored instead of 1.")
//      }
//    }
//
//    throttler.execute { block() }
//    throttler.execute { block() }
//    throttler.execute { block() }
//    throttler.execute { block() }
//    throttler.execute { block() }
//
//    wait(for: [expectation], timeout: 2)
//  }

  func testThrottlerHavingAllTheFunctionCallsCompleted() {
    let value = Atomic(0)
    let repeats = 10
    let expectation = self.expectation(description: "repeats completed")
    let block = {
      value.value += 1
      if value.value == repeats {
        expectation.fulfill()
      }
    }

    let throttler = Throttler(limit: .milliseconds(repeats))
    
    let scheduler = TestScheduler(timeInterval: Double(0.350), repeats: repeats) {
      throttler.execute { block() }
    }
    
    scheduler.start()
    
    wait(for: [expectation], timeout: 60)
    XCTAssertEqual(value.value, repeats, "Only \(value.value) blocks have been called, expecting \(repeats) blocks.")
  }
  
  func testThrottlerHavingOneThirdOfTheFunctionCallsCompleted() {
    let value = Atomic(0)
    let repeats = 10
    let expectation = self.expectation(description: "repeats completed")
    let block = {
      value.value += 1
      if value.value >= 4 {
        expectation.fulfill()
      }
    }

    let throttler = Throttler(limit: .milliseconds(800))
    
    let scheduler = TestScheduler(timeInterval: Double(0.300), repeats: repeats) {
      throttler.execute { block() }
    }
    
    scheduler.start()
    
    wait(for: [expectation], timeout: 5)
    XCTAssertEqual(value.value, 4)
  }
  
  // MARK: - Debouncer
  
  func testDebouncerHavingOnlyOneFunctionCallCompleted() {
    let expectation = self.expectation(description: "\(#file)\(#line)")
    let block = {
      expectation.fulfill()
    }
    let repeats = 10
    let throttler = Debouncer(limit: .milliseconds(800))
    
    let scheduler = TestScheduler(timeInterval: Double(0.200), repeats: repeats) {
      throttler.execute { block() }
    }
    
    scheduler.start()
    
    wait(for: [expectation], timeout: 5)
  }
  
  func testDebouncerHavingAllTheFunctionCallsCompleted() {
    let expectation = self.expectation(description: "\(#file)\(#line)") //TODO: fix this test
    let repeats = 10
    var value = 0
    let block = {
      value += 1
      if value >= repeats {
        expectation.fulfill()
      }
    }

    let throttler = Debouncer(limit: .milliseconds(400))
    
    let scheduler = TestScheduler(timeInterval: Double(0.500), repeats: repeats) {
      throttler.execute { block() }
    }
    
    scheduler.start()
    
    wait(for: [expectation], timeout: 6)
    print(value)
  }
  
  // MARK: - Max Limiter
  
  func testLimiter() { //TODO: rename this test
    let expectation = self.expectation(description: "\(#file)\(#line)")
    let value = Atomic(0)
    let block = {
      value.value += 1
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
  }
  
}

fileprivate final class TestScheduler {
  let timeInterval: TimeInterval
  let repeats: Int
  var timer: Timer!
  let block: () -> Void
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
      timer.invalidate()
    }
  }
  
}
