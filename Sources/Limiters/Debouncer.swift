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

  private var workItem: DispatchWorkItem?
  private let underlyingQueue: DispatchQueue

  // MARK: - Initializers

  /// Debouncer
  ///
  /// - Parameters:
  ///   - limit: Amount of time that needs to be passed without the block being called.
  ///   - queue: The queue where the Debouncer calls its block.
  ///   - qos: The Quality Of Service of the Debouncer.
  public init(limit: Interval, qos: DispatchQoS = .default) {
    self.limit = limit.dispatchTimeInterval
    self.underlyingQueue = DispatchQueue(label: "\(identifier).\(type(of: self))", qos: qos)
  }

  // MARK: - Debouncer

  public func execute(_ block: @escaping () -> Void) {
    underlyingQueue.async { [weak self] in
      guard let self = self else {
        return
      }

      if let workItem = self.workItem {
        workItem.cancel()
        self.workItem = nil
      }

      let workItem = DispatchWorkItem(block: block)
      self.underlyingQueue.asyncAfter(deadline: .now() + self.limit, execute: workItem)

      self.workItem = workItem
    }
  }

  public func reset() {
    underlyingQueue.sync { [weak self] in
      if let workItem = self?.workItem {
        workItem.cancel()
        self?.workItem = nil
      }
    }
  }
}

//class Debouncer_timer {
//
//  public let limit: Interval
//  private let underlyingQueue: DispatchQueue
//  private weak var timer: Timer?
//
//  /// Debouncer
//  ///
//  /// - Parameters:
//  ///   - limit: Amount of time that needs to be passed without the block being called.
//  ///   - qos: The Quality Of Service of the Debouncer.
//  public init(limit: Interval, qos: DispatchQoS = .default) {
//    self.limit = limit
//    self.underlyingQueue = DispatchQueue(label: "\(identifier).\(type(of: self))", qos: qos)
//  }
//
//  public func execute(_ block: @escaping () -> Void) {
//    underlyingQueue.sync { [weak self] in
//      guard let self = self else {
//        return
//      }
//
//      self.timer?.invalidate()
//      let nextTimer = Timer.scheduledTimer(withTimeInterval: limit.timeInterval, repeats: false) { _ in block() }
//      self.timer = nextTimer
//    }
//  }
//
//  public func reset() {
//    underlyingQueue.sync {
//      timer?.invalidate()
//      timer = nil
//    }
//  }
//}

//public final class Debouncer_old {
//
//  // MARK: - Properties
//
//  public let limit: DispatchTimeInterval
//
//  private var workItem: DispatchWorkItem?
//  private let queue: DispatchQueue
//  private let underlyingQueue: DispatchQueue
//
//  // MARK: - Initializers
//
//  /// Debouncer
//  ///
//  /// - Parameters:
//  ///   - limit: Amount of time that needs to be passed without the block being called.
//  ///   - queue: The queue where the Debouncer calls its block.
//  ///   - qos: The Quality Of Service of the Debouncer.
//  public init(limit: Interval, queue: DispatchQueue = .main, qos: DispatchQoS = .default) {
//    self.limit = limit.dispatchTimeInterval
//    self.queue = queue
//    self.underlyingQueue = DispatchQueue(label: "\(identifier).\(type(of: self))", qos: qos)
//  }
//
//  // MARK: - Debouncer
//
//  public func execute(_ block: @escaping () -> Void) {
//    underlyingQueue.async { [weak self] in
//      guard let self = self else {
//        return
//      }
//
//      if let workItem = self.workItem {
//        workItem.cancel()
//        self.workItem = nil
//      }
//
//      let workItem = DispatchWorkItem(block: block)
//      self.queue.asyncAfter(deadline: .now() + self.limit, execute: workItem)
//
//      self.workItem = workItem
//    }
//  }
//
//  public func reset() {
//    underlyingQueue.async { [weak self] in
//      if let workItem = self?.workItem {
//        workItem.cancel()
//        self?.workItem = nil
//      }
//    }
//  }
//}
