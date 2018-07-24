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

/**
 dispatch_time stops running when your computer goes to sleep. dispatch_walltime continues running. So if you want to do an action in one hour from now, but after 5 minutes your computer goes to sleep for 50 minutes, dispatch_walltime will execute an hour from now, 5 minutes after the computer wakes up. dispatch_time will execute after the computer is running for an hour, that is 55 minutes after it wakes up.
**/

import Foundation

fileprivate var AssociatedObjectDispatchSourceTimerKey: UInt8 = 0

extension DispatchSourceTimer {
  fileprivate var isSuspended: Bool {
    get {
      return objc_getAssociatedObject(self, &AssociatedObjectDispatchSourceTimerKey) as! Bool
    }
    set {
      objc_setAssociatedObject(self, &AssociatedObjectDispatchSourceTimerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
  }
}

public final class GCDTimer {

  // MARK: - Typealias

  /// Handler typealias
  public typealias Handler = ((GCDTimer) -> Void)

  // MARK: - Properties

  /// Is timer a repeat timer
  public private(set) var infinite: Bool

  /// Firing count.
  public private(set) var ticks = 0

  /// GCD event handler
  private let handler: Handler

  /// GCD timer
  private var timer: DispatchSourceTimer!

  /// GCD timer interval
  internal private(set) var interval: Interval

  /// GCD timer accuracy
  private var tolerance: DispatchTimeInterval

  /// GCD timer queue
  private var queue: DispatchQueue

  // MARK: - Initializers

  public init(interval: Interval, infinite: Bool = true, tolerance: DispatchTimeInterval = .nanoseconds(0), queue: DispatchQueue? = nil, handler: @escaping Handler) {
    self.interval = interval
    self.tolerance = tolerance
    self.infinite = infinite
    self.handler = handler
    self.queue = queue ?? DispatchQueue(label: "\(identifier).(\(type(of: GCDTimer.self))", attributes: .concurrent)
    self.timer = configureTimer()
    self.timer.isSuspended = true
  }

  deinit {
    invalidate()
  }

  private func invalidate() {
    timer.setEventHandler(handler: nil)
    timer.cancel()

    if timer.isSuspended {
      // If the timer is suspended, calling cancel without resuming triggers a crash.
      // This is documented here https://forums.developer.apple.com/thread/15902
      timer.resume()
    }
  }

  // MARK: - Timer

  /// Configures a new GCD timer.
  private func configureTimer() -> DispatchSourceTimer {
    let timer = DispatchSource.makeTimerSource(queue: queue)
    let repeatInterval = interval.dispatchTimeInterval
    let deadline: DispatchTime = (DispatchTime.now() + repeatInterval)

    if infinite {
      timer.schedule(deadline: deadline, repeating: repeatInterval, leeway: tolerance)
    } else {
      timer.schedule(deadline: deadline, leeway: tolerance)
    }

    timer.setEventHandler { [weak self] in
      guard let `self` = self else { return }

      self.fire()
    }

    timer.isSuspended = true
    ticks = 0
    return timer
  }

  /// **Bits**
  ///
  /// Starts the `GCDTimer`; if it is already running, it does nothing.
  public func resume() {
    if isSuspended {
      timer.resume()
      timer.isSuspended = false
    } else if isCancelled {
      timer = configureTimer()
      resume()
    }
  }

  /// **Bits**
  ///
  /// Suspends the `GCDTimer`.
  public func suspend() {
    if !isSuspended {
      timer.suspend()
      timer.isSuspended = true
    }
  }

  /// **Bits**
  ///
  /// Cancels the `GCDTimer`.
  public func cancel() {
    timer.cancel()
    timer.isSuspended = false
  }

  /// **Bits**
  ///
  /// Stops the `GCDTimer`; the timer will be reset.
  public func stop() {
    invalidate()
    timer = configureTimer()
  }

  private func fire() {
    ticks += 1
    handler(self)
  }

  /// **Bits**
  ///
  /// Returns `true` if the `GCDTimer` is cancelled.
  public var isCancelled: Bool {
    return timer.isCancelled
  }

  /// **Bits**
  ///
  /// Returns `true` if the `GCDTimer` is isSuspended.
  public var isSuspended: Bool {
    return timer.isSuspended
  }

}
