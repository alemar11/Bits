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
/// Enforces a maximum number of times a function can be called over time. As in "execute this function at most once every 100 milliseconds." (Throttling)
public final class Throttler {

  // MARK: - Properties

  public let limit: DispatchTimeInterval
  public private(set) var lastExecutedAt: DispatchTime?

  private let underlyingQueue = DispatchQueue(label: "\(identifier).Throttler")

  // MARK: - Initializers

  public init(limit: Interval) {
    self.limit = limit.dispatchTimeInterval
  }

  // MARK: - Throttler

  @discardableResult
  public func execute(_ block: () -> Void) -> Bool {
    let executed = underlyingQueue.sync { () -> Bool in
      let now = DispatchTime.now()
      var canBeExecuted = true

      if let lastExecutionTime = lastExecutedAt {
        let deadline = lastExecutionTime + limit
        canBeExecuted = now > deadline
      }

      if canBeExecuted {
        lastExecutedAt = now
      }

      return canBeExecuted
    }

    if executed {
      block()
    }

    return executed
  }

  public func reset() {
    underlyingQueue.sync {
      lastExecutedAt = nil
    }
  }
}
