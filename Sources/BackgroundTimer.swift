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
/// A timer based on a GCD timer.
final class BackgroundTimer {

  // MARK: - Typealias

  /// Handler typealias
  public typealias Handler = ((BackgroundTimer) -> Void)

  // MARK: - Properties

  /// Is timer a repeat timer
  public private(set) var mode: RunningMode

  /// Number of remaining repeats count
  public private(set) var remainingIterations: Int?

  // swiftlint:disable:next identifier_name
  private var _state = Atomic<State>(.idle, lock: NSRecursiveLock())

  /// Current state of the timer
  public private(set) var state: State {
    get {
      return _state.value
    }
    set {
      _state.swap(newValue)
      onStateChanged?(self, newValue)
    }
  }

  /// Callback called to intercept state's change of the timer
  public var onStateChanged: ((_ timer: BackgroundTimer, _ state: State) -> Void)?

  /// GCD event handler
  private let handler: Handler

  /// GCD timer
  private var timer = Atomic<DispatchSourceTimer?>(nil)

  /// GCD timer interval
  internal private(set) var interval: Interval

  /// GCD timer accuracy
  private var tolerance: DispatchTimeInterval

  /// GCD timer queue
  private var queue: DispatchQueue

  /// **Bits**
  ///
  /// Initializes a new `BackgroundTimer` instance.
  ///
  /// - Parameters:
  ///   - interval: interval of the timer
  ///   - mode: mode of the timer
  ///   - tolerance: tolerance of the timer, 0 is default.
  ///   - queue: queue in which the timer should be executed; if `nil` a new queue is created automatically.
  ///   - observer: observer
  public init(interval: Interval, mode: BackgroundTimer.RunningMode = .infinite, tolerance: DispatchTimeInterval = .nanoseconds(0), queue: DispatchQueue? = nil, handler: @escaping Handler) {
    self.mode = mode
    self.interval = interval
    self.tolerance = tolerance
    self.remainingIterations = mode.countIterations
    self.queue = queue ?? DispatchQueue(label: "\(identifier).BackgroundTimer", attributes: .concurrent)
    self.handler = handler
    self.timer.value = configureTimer()
  }

  deinit {
    destroyTimer()
  }

  // MARK: - Timer

  /// Configures a new GCD timer.
  private func configureTimer() -> DispatchSourceTimer {
    let timer = DispatchSource.makeTimerSource(queue: queue)
    let repeatInterval = interval.dispatchTimeInterval
    let deadline: DispatchTime = (DispatchTime.now() + repeatInterval)

    if mode.isRepeating {
      timer.schedule(deadline: deadline, repeating: repeatInterval, leeway: tolerance)
    } else {
      timer.schedule(deadline: deadline, leeway: tolerance)
    }

    timer.setEventHandler { [weak self] in
      guard let `self` = self else { return }

      self.fire()
    }

    return timer
  }

  /// Destroys the current CGD Timer
  private func destroyTimer() {
    timer.modify { timer in
      timer?.cancel()

      if state != .running {
        // If the timer is suspended, calling cancel without resuming triggers a crash.
        // This is documented here https://forums.developer.apple.com/thread/15902
        timer?.resume()
      }
      timer?.setEventHandler(handler: nil)
      return nil
    }
  }

  /// Called when the GCD timer is fired
  private func fire() {
    guard state == .running else { return }

    handler(self)

    switch mode {
    case .once:
      finish()

    case .finite:
      remainingIterations! -= 1
      if remainingIterations! == 0 {
        finish()
      }

    case .infinite:
      break
    }

  }

  // MARK: - Commands

  private let lock = NSRecursiveLock()

  /// **Bits**
  ///
  /// Starts the `BackgroundTimer`; if it is already running, it does nothing.
  @discardableResult
  public func start() -> Bool {
    let started = _state.with { currentState -> Bool in
      switch currentState {
      case .running:
        return false

      case .finished:
        timer.value?.resume()
        reset(interval: nil, restart: true)
        return true

      default:
        timer.value?.resume()
        state = .running
        return true
      }
    }

    return started
  }

  /// **Bits**
  ///
  /// Resets the state of the `BackgroundTimer`, optionally changing the fire interval.
  ///
  /// - Parameters:
  ///   - interval: new fire interval; pass `nil` to keep the latest interval set.
  ///   - restart: `true` to automatically restart the timer, `false` to keep it stopped after configuration.
  public func reset(interval i: Interval?, restart: Bool = true) {
    let isPaused = pause()

    _state.with { _ in
      // For finite counter we want to also reset the repeat count
      if case .finite(let count) = mode {
        remainingIterations = count
      }

      // Update the interval
      if let newInterval = i {
        interval = newInterval
      }

        // Create a new instance of timer configured
        destroyTimer()
        timer.swap(configureTimer())
        if !isPaused {
          state = .paused
        }

      if restart {
        timer.value?.resume()
        assert(state != .running)
        state = .running
      }

    }
  }

  /// **Bits**
  ///
  /// Pauses a running `BackgroundTimer`; if it is already paused, it does nothing.
  @discardableResult
  public func pause() -> Bool {
    let paused = _state.with { [weak self] currentState -> Bool in
      guard currentState != .paused && currentState != .idle else { return false }

      self?.timer.value?.suspend()
      state = .paused
      return true
    }
    
    return paused
  }

  @discardableResult
  private func finish() -> Bool {
    let canBeFinished = _state.with { [weak self] currentState -> Bool in
      guard currentState != .finished else { return false }

      self?.timer.value?.suspend()
      state = .finished
      return true
    }

    return canBeFinished
  }
}

extension BackgroundTimer {

  // MARK: - Factory

  /// **Bits**
  ///
  /// Creates and starts a new `BackgroundTimer` that will call the `observer` once after the specified time.
  ///
  /// - Parameters:
  ///   - interval: interval delay for single fire
  ///   - queue: destination queue, if `nil` a new `DispatchQueue` is created automatically.
  ///   - observer: handler to call when timer fires.
  /// - Returns: timer instance
  @discardableResult
  public class func once(after interval: Interval, queue: DispatchQueue? = nil, _ handler: @escaping Handler) -> BackgroundTimer {
    let timer = BackgroundTimer(interval: interval, mode: .once, queue: queue, handler: handler)
    timer.start()
    return timer
  }

  /// **Bits**
  ///
  /// Creates and starts a `BackgroundTimer` that will fire every interval optionally by limiting the number of fires.
  ///
  /// - Parameters:
  ///   - interval: interval of fire
  ///   - count: a non `nil` and > 0  value to limit the number of fire, `nil` to set it as infinite.
  ///   - queue: destination queue, if `nil` a new `DispatchQueue` is created automatically.
  ///   - handler: handler to call on fire
  /// - Returns: timer
  @discardableResult
  public class func every(_ interval: Interval, count: Int? = nil, queue: DispatchQueue? = nil, _ handler: @escaping Handler) -> BackgroundTimer {
    let mode: RunningMode = (count != nil ? .finite(count!) : .infinite)
    let timer = BackgroundTimer(interval: interval, mode: mode, queue: queue, handler: handler)
    timer.start()
    return timer
  }
}

extension BackgroundTimer {

  // MARK: - BackgroundTimer RunningMode

  /// **Bits**
  ///
  /// `BackgroundTimer` running mode.
  ///
  /// - infinite: infinite number of repeats.
  /// - finite: finite number of repeats.
  /// - once: single repeat.
  public enum RunningMode {
    case infinite
    case finite(_: Int)
    case once

    /// **Bits**
    ///
    /// Is the `BackgroundTimer` a repeating timer?
    internal var isRepeating: Bool {
      guard case .once = self else { return true }

      return true
    }

    /// **Bits**
    ///
    /// Number of repeats, if applicable. Otherwise `nil`
    public var countIterations: Int? {
      switch self {
      case .finite(let counts): return counts
      default: return nil
      }
    }

    /// **Bits**
    ///
    /// Returns tue if the `BackgroundTimer` has an infinite number of repeats.
    public var isInfinite: Bool {
      guard case .infinite = self else { return false }
      return true
    }

  }
}

extension BackgroundTimer {

  // MARK: - BackgroundTimer State

  /// **Bits**
  ///
  /// State of the `BackgroundTimer`
  ///
  /// - idle: The `BackgroundTimer` is yet to be started.
  /// - paused: The `BackgroundTimer` is paused.
  /// - running: The `BackgroundTimer` is running.
  /// - finished: The `BackgroundTimer` lifetime is finished.
  public enum State: Equatable, CustomStringConvertible {
    case idle
    case paused
    case running
    case finished

    public static func == (lhs: State, rhs: State) -> Bool {
      switch (lhs, rhs) {
      case (.idle, .idle),
           (.paused, .paused),
           (.running, .running),
           (.finished, .finished):
        return true
      default:
        return false
      }
    }

    public var description: String {
      switch self {
      case .idle: return "idle"
      case .paused: return "paused"
      case .finished: return "finished"
      case .running: return "running"
      }
    }

  }
}
