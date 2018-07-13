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

import Foundation

/// **Bits**
///
/// Enforces a maximum number of times a function can be called. As in "execute this function at most 10 times."
public final class MaxLimiter {

  // MARK: - Properties

  public let limit: UInt
  public private(set) var count: UInt = 0

  private let underlyingQueue = DispatchQueue(label: "\(identifier).Limiter")

  // MARK: - Initializers

  public init(limit: UInt) {
    self.limit = limit
  }

  // MARK: - Limiter

  @discardableResult
  public func execute(_ block: () -> Void) -> Bool {
    let executed = underlyingQueue.sync { () -> Bool in
      if count < limit {
        count += 1
        return true
      }
      return false
    }

    if executed {
      block()
    }

    return executed
  }

  public func reset() {
    underlyingQueue.sync {
      count = 0
    }
  }
}
