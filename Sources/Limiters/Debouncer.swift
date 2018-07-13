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
/// Enforces a function to not be called again until a certain amount of time has passed without it being called.
/// As in "execute this function only if 100 milliseconds have passed without it being called."
public final class Debouncer {

  // MARK: - Properties

  public let limit: DispatchTimeInterval
  public let queue: DispatchQueue

  private var workItem: DispatchWorkItem?
  private let underlyingQueue = DispatchQueue(label: "\(identifier).Debouncer")

  // MARK: - Initializers

  public init(limit: Interval, queue: DispatchQueue = .main) {
    self.limit = limit.dispatchTimeInterval
    self.queue = queue
  }

  // MARK: - Debouncer

  public func execute(_ block: @escaping () -> Void) {
    underlyingQueue.async { [weak self] in
      if let workItem = self?.workItem {
        workItem.cancel()
        self?.workItem = nil
      }

      guard
        let queue = self?.queue,
        let limit = self?.limit
        else { return }

      let workItem = DispatchWorkItem(block: block)
      queue.asyncAfter(deadline: .now() + limit, execute: workItem)

      self?.workItem = workItem
    }
  }

  public func reset() {
    underlyingQueue.async { [weak self] in
      if let workItem = self?.workItem {
        workItem.cancel()
        self?.workItem = nil
      }
    }
  }
}
