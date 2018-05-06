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

class IdentifiableTests: XCTestCase {

    func testThatIdentifierValueHasTheSameValueOfTheIdentifiersKeyPath() {

      struct Person: Identifiable {
        static let identifierKeyPath = \Person.name
        var socialSecurityNumber: String
        var name: String
      }

      final class Book: Identifiable {

        

        static var identifierKeyPath: WritableKeyPath<Book, Int> = \Book.isbn

        var isbn: Int
        var title: String
        init(isbn: Int, title: String) {
          self.isbn = isbn
          self.title = title
        }
      }

      let person = Person(socialSecurityNumber: "123", name: "Robot")
      XCTAssertEqual(person.identifier, person.name)

      let book = Book(isbn: 123, title: "Bits")
      XCTAssertEqual(book.identifier, book.isbn)
    }

}
