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

class BoxTests: XCTestCase {

  final class TestContainer<T: Any> {
    let box: Box<T>

    init(box: Box<T>) {
      self.box = box
    }
  }

  func testBoxedStruct() {
    struct User: Equatable {
      var name: String
      var age: Int
    }

    let user = User(name: "Robot", age: 30)
    let box = Box(user)
    let container1 = TestContainer<User>(box: box)
    let container2 = TestContainer<User>(box: box)

    XCTAssertEqual(container1.box.value.name, "Robot")
    XCTAssertEqual(container2.box.value.name, "Robot")
    XCTAssertEqual(container1.box, container2.box)

    box.value.name = "_Robot_"

    XCTAssertEqual(container1.box.value.name, "_Robot_")
    XCTAssertEqual(container2.box.value.name, "_Robot_")
    XCTAssertEqual(container1.box, container2.box)
    XCTAssertEqual(container1.box, container2.box)
  }

}

