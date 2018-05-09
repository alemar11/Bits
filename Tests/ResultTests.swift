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

class ResultTests: XCTestCase {

  let error = NSError(domain: "org.tinrobots", code: 100, userInfo: nil)

  // MARK: - Is Success Tests

  func testThatIsSuccessPropertyReturnsTrueForSuccessCase() {
    // Given, When
    let result = Result<String>.success("success")

    // Then
    XCTAssertTrue(result.isSuccess, "It should be true for success case.")
  }

  func testThatIsSuccessPropertyReturnsFalseForFailureCase() {
    // Given, When
    let result = Result<String>.failure(error)

    // Then
    XCTAssertFalse(result.isSuccess, "It should be false for failure case.")
  }

  // MARK: - Is Failure Tests
  func testThatIsFailurePropertyReturnsFalseForSuccessCase() {
    // Given, When
    let result = Result<String>.success("success")

    // Then
    XCTAssertFalse(result.isError, "It should be false for success case.")
  }

  func testThatIsFailurePropertyReturnsTrueForFailureCase() {
    // Given, When
    let result = Result<String>.failure(error)

    // Then
    XCTAssertTrue(result.isError, "It should be true for failure case.")
  }

  // MARK: - Success Tests

  func testThatValuePropertyReturnsValueForSuccessCase() {
    // Given, When
    let result = Result<String>.success("success")

    // Then
    XCTAssertEqual(result.success ?? "", "success", "It should match expected value.")
  }

  func testThatValuePropertyReturnsNilForFailureCase() {
    // Given, When
    let result = Result<String>.failure(error)

    // Then
    XCTAssertNil(result.success, "It should be nil for failure case.")
  }

  // MARK: - Failure Tests

  func testThatErrorPropertyReturnsNilForSuccessCase() {
    // Given, When
    let result = Result<String>.success("success")

    // Then
    XCTAssertNil(result.failure, "It should be nil for success case.")
  }

  func testThatErrorPropertyReturnsErrorForFailureCase() {
    // Given, When
    let result = Result<String>.failure(error)

    // Then
    XCTAssertNotNil(result.failure, "It should not be nil for failure case.")
  }

  // MARK: - Description Tests
  func testThatDescriptionStringMatchesExpectedValueForSuccessCase() {
    // Given, When
    let result = Result<String>.success("success")

    // Then
    XCTAssertEqual(result.description, "Success", "result description should match expected value for success case.")
  }

  func testThatDescriptionStringMatchesExpectedValueForFailureCase() {
    // Given, When
    let result = Result<String>.failure(error)

    // Then
    XCTAssertEqual(result.description, "Failure", "result description should match expected value for failure case.")
  }

  // MARK: - Debug Description Tests
  func testThatDebugDescriptionStringMatchesExpectedValueForSuccessCase() {
    // Given, When
    let result = Result<String>.success("success value")

    // Then
    XCTAssertEqual(
      result.debugDescription,
      "Success: success value",
      "Debug description should match expected value for success case."
    )
  }

  func testThatDebugDescriptionStringMatchesExpectedValueForFailureCase() {
    // Given, When
    let result = Result<String>.failure(error)

    // Then
    XCTAssertEqual(
      result.debugDescription,
      "Failure: \(error)",
      "Debug description should match expected value for failure case."
    )
  }

  // MARK: - Initializer Tests

  func testThatInitializerFromThrowingClosureStoresResultAsASuccess() {
    // Given
    let value = "success value"

    // When
    let result1 = Result(value: value)
    let result2 = Result<String>{ value }

    // Then
    for result in [result1, result2] {
      XCTAssertTrue(result.isSuccess)
      XCTAssertEqual(result.success, value)
    }
  }

  func testThatInitializerFromThrowingClosureCatchesErrorAsAFailure() {
    // Given
    struct ResultError: Error {}

    // When
    let result1 = Result<Any>(error: ResultError())
    let result2 = Result<Any>{ throw ResultError() }

    // Then
    for result in [result1, result2] {
      XCTAssertTrue(result.isError)
      XCTAssertTrue(result.failure! is ResultError)
    }
  }

  // MARK: - Unwrap Tests
  func testThatUnwrapReturnsSuccessValue() {
    // Given
    let result = Result<String>.success("success value")

    // When
    let unwrappedValue = try? result.unwrap()

    // Then
    XCTAssertEqual(unwrappedValue, "success value")
  }

  func testThatUnwrapThrowsFailureError() {
    // Given
    struct ResultError: Error {}

    // When
    let result = Result<String>.failure(ResultError())

    // Then
    do {
      _ = try result.unwrap()
      XCTFail("It should throw the failure error.")
    } catch {
      XCTAssertTrue(error is ResultError)
    }
  }

}

