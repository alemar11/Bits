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
/// A scheduler based on a GCD timer.
final class Scheduler: Equatable {

  // MARK: - Typealias

  /// Handler typealias
  public typealias Observer = ((Scheduler) -> Void)

  /// Token assigned to the observer
  public typealias Token = UUID

  // MARK: - Properties

  /// Is timer a repeat timer
  public private(set) var mode: RunningMode

  /// Number of remaining repeats count
  public private(set) var remainingIterations: Int?

  /// Current state of the timer
  public private(set) var state: State = .paused {
    didSet {
      onStateChanged?(self, state)
    }
  }

  /// Callback called to intercept state's change of the timer
  public var onStateChanged: ((_ timer: Scheduler, _ state: State) -> Void)?

  /// Callback called to intercept the interval change of the timer
  internal var onIntervalChanged: ((_ timer: Scheduler, _ inteval: Interval) -> Void)?

  /// Schduler observers
  private(set) internal var observers = [Token: Observer]()

  /// GCD timer
  private var timer: DispatchSourceTimer?

  /// GCD timer interval
  private(set) internal var interval: Interval {
    didSet {
      onIntervalChanged?(self, interval)
    }
  }

  /// GCD timer accuracy
  private var tolerance: DispatchTimeInterval

  /// GCD timer queue
  private var queue: DispatchQueue

  /// **Bits**
  ///
  /// Initializes a new `Scheduler` instance.
  ///
  /// - Parameters:
  ///   - interval: interval of the timer
  ///   - mode: mode of the timer
  ///   - tolerance: tolerance of the timer, 0 is default.
  ///   - queue: queue in which the timer should be executed; if `nil` a new queue is created automatically.
  ///   - observer: observer
  public init(interval: Interval, mode: RunningMode = .infinite, tolerance: DispatchTimeInterval = .nanoseconds(0), queue: DispatchQueue? = nil, observer: @escaping Observer) {
    self.mode = mode
    self.interval = interval
    self.tolerance = tolerance
    self.remainingIterations = mode.countIterations
    self.queue = queue ?? DispatchQueue(label: "\(identifier).Scheduler")
    self.timer = configureTimer()
    self.addObserver(observer)
  }

  /// **Bits**
  ///
  /// Adds a new observer to the `Scheduler`.
  ///
  /// - Parameter callback: callback to call for fire events.
  /// - Returns: The token used to remove the observer from the scheduler
  @discardableResult
  public func addObserver(_ observer: @escaping Observer) -> Token {
    let new = UUID()
    observers[new] = observer
    return new
  }

  /// **Bits**
  ///
  /// Removes an observer from the the `Scheduler`.
  ///
  /// - Parameter token: token of the observer to remove
  public func removeObserver(withToken token: Token) {
    observers.removeValue(forKey: token)
  }

  /// **Bits**
  ///
  /// Removes all the observers of the `Scheduler`.
  ///
  /// - Parameter stopTimer: `true` to also stop timer by calling `pause()` function.
  public func removeAllObservers(thenStop stopTimer: Bool = false) {
    observers.removeAll()

    if stopTimer {
      pause()
    }
  }

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
    timer?.setEventHandler(handler: nil)
    timer?.cancel()

    if state == .paused || state == .finished {
      // If the timer is suspended, calling cancel without resuming triggers a crash.
      // This is documented here https://forums.developer.apple.com/thread/15902
      timer?.resume()
    }
  }

  /// **Bits**
  ///
  /// Creates and starts a new `Scheduler` that will call the `observer` once after the specified time.
  ///
  /// - Parameters:
  ///   - interval: interval delay for single fire
  ///   - queue: destination queue, if `nil` a new `DispatchQueue` is created automatically.
  ///   - observer: handler to call when timer fires.
  /// - Returns: timer instance
  @discardableResult
  public class func once(after interval: Interval, queue: DispatchQueue? = nil, _ observer: @escaping Observer) -> Scheduler {
    let timer = Scheduler(interval: interval, mode: .once, queue: queue, observer: observer)
    timer.start()
    return timer
  }

  /// **Bits**
  ///
  /// Creates and starts a `Scheduler` that will fire every interval optionally by limiting the number of fires.
  ///
  /// - Parameters:
  ///   - interval: interval of fire
  ///   - count: a non `nil` and > 0  value to limit the number of fire, `nil` to set it as infinite.
  ///   - queue: destination queue, if `nil` a new `DispatchQueue` is created automatically.
  ///   - handler: handler to call on fire
  /// - Returns: timer
  @discardableResult
  public class func every(_ interval: Interval, count: Int? = nil, queue: DispatchQueue? = nil, _ handler: @escaping Observer) -> Scheduler {
    let mode: RunningMode = (count != nil ? .finite(count!) : .infinite)
    let timer = Scheduler(interval: interval, mode: mode, queue: queue, observer: handler)
    timer.start()
    return timer
  }

  /// **Bits**
  ///
  /// Forces a fire.
  ///
  /// - Parameter pause: `true` to pause after fire, `false` to continue the regular firing schedule.
  public func fire(andThenPause pause: Bool = false) {
    fire()

    if pause == true {
      self.pause()
    }
  }

  /// **Bits**
  ///
  /// Resets the state of the `Scheduler`, optionally changing the fire interval.
  ///
  /// - Parameters:
  ///   - interval: new fire interval; pass `nil` to keep the latest interval set.
  ///   - restart: `true` to automatically restart the timer, `false` to keep it stopped after configuration.
  public func reset(_ interval: Interval?, restart: Bool = true) {
    if state.isRunning {
      setPause(from: state)
    }

    // For finite counter we want to also reset the repeat count
    if case .finite(let count) = mode {
      remainingIterations = count
    }

    // Update the interval
    if let newInterval = interval {
      self.interval = newInterval
    }

    // Create a new instance of timer configured
    destroyTimer()
    timer = configureTimer()
    state = .paused

    if restart {
      timer?.resume()
      state = .running
    }
  }

  /// **Bits**
  ///
  /// Starts the `Scheduler`; if it is already running, it does nothing.
  @discardableResult
  public func start() -> Bool {
    guard state.isRunning == false else { return false }

    // If timer has not finished its lifetime, restart it from the current state.
    guard state.isFinished == true else {
      state = .running
      timer?.resume()
      return true
    }

    // Otherwise reset the state based upon the mode and start it again.
    reset(nil, restart: true)

    return true
  }

  /// **Bits**
  ///
  /// Pauses a running `Scheduler`; if is paused, it does nothing.
  @discardableResult
  public func pause() -> Bool {
    guard state != .paused && state != .finished else { return false }

    return setPause(from: state)
  }

  /// **Bits**
  ///
  /// Pauses a running `Scheduler` optionally changing the state with regard to the current state.
  ///
  /// - Parameters:
  ///   - from: the state which the timer should only be paused if it is the current state
  ///   - to: the new state to change to if the timer is paused
  /// - Returns: `true` if timer is paused
  @discardableResult
  private func setPause(from currentState: State, to newState: State = .paused) -> Bool {
    guard state == currentState else { return false }

    timer?.suspend()
    state = newState

    return true
  }

  /// Called when the GCD timer is fired
  private func fire() {
    state = .executing

    // dispatch to observers
    observers.values.forEach { $0(self) }

    // manage lifetime
    switch mode {
    case .once:
      // once timer's lifetime is finished after the first fire
      // you can reset it by calling `reset()` function.
      setPause(from: .executing, to: .finished)
    case .finite:
      // for finite intervals we decrement the left iterations count...
      remainingIterations! -= 1
      if remainingIterations! == 0 {
        // ...if left count is zero we just pause the timer and stop
        setPause(from: .executing, to: .finished)
      }
    case .infinite:
      // infinite timer does nothing special on the state machine
      break
    }

  }

  deinit {
    observers.removeAll()
    destroyTimer()
  }

  public static func == (lhs: Scheduler, rhs: Scheduler) -> Bool {
    return lhs === rhs
  }
}

extension Scheduler {

  // MARK: - Scheduler RunningMode

  /// **Bits**
  ///
  /// `Scheduler` running mode.
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
    /// Is the `Scheduler` a repeating timer?
    internal var isRepeating: Bool {
      switch self {
      case .once: return false
      default:  return true
      }
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
    /// Returns tue if the `Scheduler` has an infinite number of repeats.
    public var isInfinite: Bool {
      guard case .infinite = self else { return false }
      return true
    }

  }
}

extension Scheduler {

  // MARK: - Scheduler State

  /// **Bits**
  ///
  /// State of the `Scheduler`
  ///
  /// - paused: idle (never started yet or paused)
  /// - running: The `Scheduler` is running
  /// - executing: The observers are being executed
  /// - finished: The `Scheduler` lifetime is finished
  public enum State: Equatable, CustomStringConvertible {
    case paused
    case running
    case executing
    case finished

    public static func == (lhs: State, rhs: State) -> Bool {
      switch (lhs, rhs) {
      case (.paused, .paused),
           (.running, .running),
           (.executing, .executing),
           (.finished, .finished):
        return true
      default:
        return false
      }
    }

    /// **Bits**
    ///
    /// Returns `true` if the `Scheduler` is currently running, including when the observers are being executed.
    public var isRunning: Bool {
      guard self == .running || self == .executing else { return false }
      return true
    }

    /// **Bits**
    ///
    /// Returns `true` if the `Scheduler` is currently paused.
    public var isPaused: Bool {
      return self == .paused
    }

    /// **Bits**
    ///
    /// Returns `true` if the observers are being executed.
    public var isExecuting: Bool {
      guard case .executing = self else { return false }
      return true
    }

    /// **Bits**
    ///
    /// Has the `Scheduler` finished its lifetime?
    ///
    /// Returns always `false` for infinite `Scheduler`.
    ///
    /// Returns `true` after the first fire for the `.once` mode `Scheduler`,
    /// and when `.remainingIterations` is zero for an `.finite` mode `Scheduler`.
    public var isFinished: Bool {
      guard case .finished = self else { return false }
      return true
    }

    public var description: String {
      switch self {
      case .paused: return "idle/paused"
      case .finished: return "finished"
      case .running: return "running"
      case .executing: return "executing"
      }
    }

  }
}
