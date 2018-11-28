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
/// A thread safe event bus object that broadcasts event to its subscribers.
open class EventBus {

  // MARK: - Typealiases

  private typealias SubscriberSet = Set<EventBus.Subscription<AnyObject>>

  // MARK: - Properties

  /// The `EventBus` label.
  public let label: String?

  /// Internal queue
  private let lock = UnfairLock()

  /// Subscriptions.
  private var subscriptions = [ObjectIdentifier: SubscriberSet]()

  // MARK: - Initializers

  /// Creates an `EventBus` with a given configuration and dispatch queue.
  ///
  /// - Parameters:
  ///   - label: a label to identify the `EventBus`.
  public init(label: String) {
    self.label = label
  }

}

// MARK: - Public Methods

extension EventBus {

  @discardableResult
  public func add<T>(subscriber: T, for eventType: T.Type, queue: DispatchQueue) -> SubscriptionCancellable {
    lock.lock()
    defer { lock.unlock() }

    guard _validate(subscriber) else {
      fatalError("Multicast delegates do not support value types.")
    }

    let subscriberObject = subscriber as AnyObject
    let subscription = Subscription<AnyObject>(subscriber: subscriberObject, queue: queue, cancellationClosure: { [weak self, weak weakSbscriberObject = subscriberObject] completion in
      guard let self = self else {
        return
      }

      self.lock.lock()
      defer { self.lock.unlock() }
      if let subscriberObject = weakSbscriberObject {
        // swiftlint:disable:next force_cast
        self._remove(subscriber: subscriberObject as! T, for: eventType)
      } else {
        // the subscriber is already deallocated, so let's do some flushing for the given envent
        self._flushDeallocatedSubscribers(for: eventType)
      }

      completion?()
    })

    _updateSubscribers(for: eventType) { subscribed in
      subscribed.insert(subscription)
    }

    return subscription.token

  }

  /// Removes a subscriber from a given event type.
  public func remove<T>(subscriber: T, for eventType: T.Type) {
    lock.lock()
    defer { lock.unlock() }

     guard _validate(subscriber) else { return }

    _remove(subscriber: subscriber, for: eventType)
  }

  /// Removes a subscriber from all its subscriptions.
  public func remove<T>(subscriber: T) {
    lock.lock()
    defer { lock.unlock() }

    guard !_validate(subscriber) else { return }

    for (identifier, subscribed) in subscriptions {
      subscriptions[identifier] = self._update(set: subscribed) { subscribed in
        while let index = subscribed.index(where: { $0 == subscriber as AnyObject }) {
          subscribed.remove(at: index)
        }
      }
    }
  }

  /// Removes all the subscribers.
  public func clear() {
    lock.lock()
    defer { lock.unlock() }

    subscriptions.removeAll()
  }

  /// Returns all the subscriber for a given eventType.
  public func subscribers<T>(for eventType: T.Type) -> [AnyObject] {
    lock.lock()
    defer { lock.unlock() }

    return _subscribers(for: eventType)
  }

  /// Checks if the `EventBus` is subscribed for a particular eventType.
  public func isSubscribed<T>(for eventType: T.Type) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    // TODO: flush
    return subscriptions[ObjectIdentifier(eventType)] != nil

  }

  /// Checks if the `EventBus` has a given subscriber for a particular eventType.
  public func hasSubscriber<T>(_ subscriber: T, for eventType: T.Type) -> Bool {
    lock.lock()
    defer { lock.unlock() }

    guard _validate(subscriber) else { return false }

    let subscribers = _subscribers(for: eventType).filter { $0 === subscriber as AnyObject }
    assert((0...1) ~= subscribers.count, "EventBus has registered a subscriber \(subscribers.count) times for event \(eventType).")

    return subscribers.count > 0
  }

  @discardableResult
  public func notify<T>(_ eventType: T.Type, closure: @escaping (T) -> Void) -> Int {
    lock.lock()
    defer { lock.unlock() }

    var handledNotifications = 0
    let identifier = ObjectIdentifier(eventType)

    // Notify to direct subscribers
    if let subscriptions = subscriptions[identifier] {
      for subscription in subscriptions {
        // async
        subscription.notify(eventType: eventType, closure: closure) { }
      }
      handledNotifications += subscriptions.count
    }
    return handledNotifications
  }
}

// MARK: - Private Methods

extension EventBus {

  @inline(__always)
  private func _validate<T>(_ subscriber: T) -> Bool {
    return Mirror(reflecting: subscriber).subjectType is AnyClass
  }

  @inline(__always)
  private func _remove<T>(subscriber: T, for eventType: T.Type) {
    _updateSubscribers(for: eventType) { subscribed in
      // removes also all the deallocated subscribers
      while let index = subscribed.index(where: { ($0 == subscriber as AnyObject) || !$0.isValid }) {
        subscribed.remove(at: index)
      }
    }
  }

  @inline(__always)
  private func _flushDeallocatedSubscribers<T>(for eventType: T.Type) {
    _updateSubscribers(for: eventType) { subscribed in
      while let index = subscribed.index(where: { !$0.isValid }) {
        subscribed.remove(at: index)
      }
    }
  }

  @inline(__always)
  private func _subscribers<T>(for eventType: T.Type) -> [AnyObject] {
    let identifier = ObjectIdentifier(eventType)
    if let subscribed = subscriptions[identifier] {
      return subscribed.filter { $0.isValid }.compactMap { $0.underlyngSubscriber }
    }
    return []
  }

  @inline(__always)
  private func _updateSubscribers<T>(for eventType: T.Type, closure: (inout SubscriberSet) -> Void) {
    let identifier = ObjectIdentifier(eventType)
    let subscribed = subscriptions[identifier] ?? SubscriberSet()

    subscriptions[identifier] = _update(set: subscribed, closure: closure)
  }

  @inline(__always)
  private func _update(set: SubscriberSet, closure: (inout SubscriberSet) -> Void) -> SubscriberSet? {
    var mutableSet = set
    closure(&mutableSet)
    // Remove weak nil elements
    let filteredSet = mutableSet.filter { $0.isValid }
    return filteredSet.isEmpty ? nil : filteredSet
  }

}

// MARK: - Subscription

public protocol SubscriptionCancellable {
  /// Cancels the subscription associated with this token.
  ///
  /// - Parameter completion: The block executed after the cancellation has completed.
  func cancel(completion: (() -> Void)?)
}

extension EventBus {

  /// A subscription token to cancel a subscription.
  private final class Token: SubscriptionCancellable {
    private let cancellationClosure: ((() -> Void)?) -> Void

    fileprivate init(cancellationClosure: @escaping ((() -> Void)?) -> Void) {
      self.cancellationClosure = cancellationClosure
    }

    fileprivate func cancel(completion: (() -> Void)? = nil) {
      cancellationClosure(completion)
    }
  }

  /// Holds all the subscription components.
  private final class Subscription<T>: Hashable {
    internal var isValid: Bool { return underlyngSubscriber != nil }
    internal let token: SubscriptionCancellable
    private let queue: DispatchQueue
    fileprivate weak var underlyngSubscriber: AnyObject?

    init(subscriber: AnyObject, queue: DispatchQueue, cancellationClosure: @escaping ((() -> Void)?) -> Void) {
      self.underlyngSubscriber = subscriber as AnyObject
      self.token = Token(cancellationClosure: cancellationClosure)
      self.queue = queue
    }

    fileprivate func notify<T>(eventType: T.Type, closure: @escaping (T) -> Void, completion: @escaping () -> Void) {
      queue.async { [weak self] in
        guard let `self` = self else {
          return
        }

        if let underlyngObject = self.underlyngSubscriber {
          if let subscriber = underlyngObject as? T {
            closure(subscriber)
          }
          completion()
        } else {
          self.token.cancel(completion: completion)
        }
      }
    }

    fileprivate static func == (lhs: Subscription, rhs: Subscription) -> Bool {
      return lhs.underlyngSubscriber === rhs.underlyngSubscriber
    }

    fileprivate static func == (lhs: Subscription, rhs: AnyObject) -> Bool {
      return lhs.underlyngSubscriber === rhs
    }

    fileprivate var hashValue: Int {
      guard let underlyngObject = underlyngSubscriber else {
        return 0
      }
      return ObjectIdentifier(underlyngObject).hashValue
    }
  }

}

// MARK: - Tests

extension EventBus {

  /// For tests only, returns also all the deallocated but not yet removed subscriptions
  // swiftlint:disable:next identifier_name
  internal func __subscribersCount<T>(for eventType: T.Type) -> Int {
    lock.lock()
    defer { lock.unlock() }

    let identifier = ObjectIdentifier(eventType)
    if let subscribed = subscriptions[identifier] {
      return subscribed.count
    }
    return 0
  }

}
