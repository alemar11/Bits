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

class ThreadSafeTests: XCTestCase {

    func testExample() {

      let array = Protected([Int]())
      let iterations = 1000

      DispatchQueue.concurrentPerform(iterations: iterations) { index in
        //let last = array.read().last ?? 0
        array.write { $0.append(1) }
      }

      print(array.value)
      XCTAssertEqual(array.value.count, iterations)
    }

//https://mikeash.com/pyblog/friday-qa-2011-10-14-whats-new-in-gcd.html
  //https://gist.github.com/robertmryan/1cb3102112988a47926a82bc5ae5858e

//  func testExample2() {
//    let array = Protected([Int]())
//    let iterations = 1000
//
//    DispatchQueue.concurrentPerform(iterations: iterations) { index in
//      array.write(mode: .sync) { $0.append(1) }
//    }
//
//    XCTAssertEqual(array.read().count, iterations)
//  }

}
