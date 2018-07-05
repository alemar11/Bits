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

// Credits:
// https://forums.swift.org/t/adding-result-to-the-standard-library/6932/206
// https://github.com/Alamofire/Alamofire/blob/master/Source/Result.swift
// https://github.com/antitypical/Result/blob/master/Result/AnyError.swift

/// **Bits**
///
/// Base type: a typed result.
public enum ResultType<T, E> {
  case success(T), failure(E)
}

extension ResultType {

  // MARK: Constructors

  /// **Bits**
  ///
  /// Constructs a success wrapping a `value`.
  public init(value: T) {
    self = .success(value)
  }

  /// **Bits**
  ///
  /// Constructs a failure wrapping an `error`.
  public init(error: E) {
    self = .failure(error)
  }

  /// **Bits**
  ///
  /// Returns the success value.
  public var success: T? {
    if case .success(let success) = self { return success }
    return nil
  }

  /// **Bits**
  ///
  /// Returns the error.
  public var failure: E? {
    if case .failure(let error) = self { return error }
    return nil
  }

  /// **Bits**
  ///
  /// Returns `true` if the result is successfull.
  public var isSuccess: Bool { return self.success != nil }

  /// **Bits**
  ///
  /// Returns `true` if the result is not successfull.
  public var isError: Bool { return self.failure != nil }
}

/// When E is an error type, you get `unwrap()`
public extension ResultType where E: Swift.Error {

  // Unwrap loses error information
  func unwrap() throws -> T {
    switch self {
    case .success(let value): return value
    case .failure(let error): throw error
    }
  }

}

// MARK: - CustomStringConvertible

extension ResultType: CustomStringConvertible {

  /// **Bits**
  ///
  /// The textual representation used when written to an output stream, which includes whether the result was a
  /// success or failure.
  public var description: String {
    switch self {
    case .success:
      return "Success"
    case .failure:
      return "Failure"
    }
  }

}

// MARK: - CustomDebugStringConvertible

extension ResultType: CustomDebugStringConvertible {

  /// The debug textual representation used when written to an output stream, which includes whether the result was a
  /// success or failure in addition to the value or error.
  public var debugDescription: String {
    switch self {
    case .success(let value):
      return "Success: \(value)"
    case .failure(let error):
      return "Failure: \(error)"
    }
  }

}

/// When E is exactly `Error`, you can build a result from a throwing function:
public extension ResultType where E == Swift.Error {

  // ResultType<T, Error> can be initiated from a throwing function
  init(_ block: () throws -> T) {
    do {
      self = try .success(block())
    } catch {
      self = .failure(error)
    }
  }

  public func unwrap() throws -> T {
    // This overload is necessary in order to avoid a compiler error "using 'Error' as a concrete type conforming to protocol 'Error' is not supported".
    switch self {
    case .success(let value): return value
    case .failure(let error): throw error
    }
  }

}

public extension Result {

  /// **Bits**
  ///
  /// Maps the result type to a new value
  ///
  /// - Parameter transform: A mapping closure.
  /// - Returns: A result containing the transformed value
  public func map<U>(_ transform: (T) -> U) -> ResultType<U, E> {
    switch self {
    case .success(let value):
      return .success(transform(value))
    case .failure(let error):
      return .failure(error)
    }
  }

  /// **Bits**
  ///
  /// Maps the result type to a new value.
  ///
  /// - Parameter transform: A mapping closure.
  /// - Returns: A result containing the transformed value
  public func flatMap<U>(transform: (T) -> ResultType<U, E>) -> ResultType<U, E> {
    switch self {
    case .success(let value):
      return transform(value)
    case .failure(let error):
      return .failure(error)
    }
  }
}

// MARK: - Result

/// **Bits**
///
/// Convenience typealias for untyped errors
public typealias Result<T> = ResultType<T, Error>
