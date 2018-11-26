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

public protocol EventNotifiable {
  @discardableResult
  func notify<T>(_ eventType: T.Type, completion: (()-> Void)?, closure: @escaping (T) -> Void) -> Int
}

/// **Bits**
///
/// An event bus object that broadcasts event to its subscribers.
public final class EventBus: EventNotifiable {

  // MARK: - Typealiases

  private typealias SubscriberSet = Set<EventBus.Subscription<AnyObject>>

  // MARK: - Properties
  
  /// The `EventBus` label.
  public let label: String?
  
  /// The event types the `EventBus` is registered for.
  public var registeredEventTypes: [Any] {
    return self.registered.compactMap { self.knownTypes[$0] }
  }
  
  /// The event types the `EventBus` has subscribers for.
  public var subscribedEventTypes: [Any] {
    return self.subscribed.keys.compactMap { self.knownTypes[$0] }
  }
  
  fileprivate var knownTypes: [ObjectIdentifier: Any] = [:]

  /// Internal queue
  private let dispatchQueue: DispatchQueue
  /// Event registered by the `EventBus`.
  private var registered: Set<ObjectIdentifier> = []
  /// Subscriptions.
  private var subscribed = [ObjectIdentifier: SubscriberSet]()

  // MARK: - Initializers
  
  /// Creates an `EventBus` with a given configuration and dispatch queue.
  ///
  /// - Parameters:
  ///   - options: the event bus' options
  ///   - notificationQueue: the dispatch queue to notify subscribers on
  public init(label: String? = nil, qos: DispatchQoS = .default) {
    self.label = label
    self.dispatchQueue = DispatchQueue.init(label:  "\(identifier).EventBus", qos: qos)
  }
  
  deinit {
    print("EventBus deinit")
  }
  
}

// MARK: - Private Methods

extension EventBus {

  private func validateSubscriber<T>(_ subscriber: T) {
    precondition(Mirror(reflecting: subscriber).subjectType is AnyClass, "The subscriber \(String(describing: subscriber.self)) must be a class.")
  }

  @inline(__always)
  private func _subscribers<T>(for eventType: T.Type) -> [AnyObject] {
    let identifier = ObjectIdentifier(eventType)
    if let subscribed = self.subscribed[identifier] {
      return subscribed.filter { $0.isValid }.compactMap { $0.underlyngObject }
    }
    return []
  }
  
  @inline(__always)
  private func updateSubscribers<T>(for eventType: T.Type, closure: (inout SubscriberSet) -> Void) {
    let identifier = ObjectIdentifier(eventType)
    let subscribed = self.subscribed[identifier] ?? SubscriberSet()
    self.subscribed[identifier] = update(set: subscribed, closure: closure)
    self.knownTypes[identifier] = String(describing: eventType)
  }

  @inline(__always)
  private func update(set: SubscriberSet, closure: (inout SubscriberSet) -> Void) -> SubscriberSet? {
    var mutableSet = set
    closure(&mutableSet)
    // Remove weak nil elements
    let filteredSet = mutableSet.filter { $0.isValid }
    return filteredSet.isEmpty ? nil : filteredSet
  }

}

// MARK: - Register

extension EventBus {
  
  public func register<T>(forEvent eventType: T.Type) { //TODO useless?
    let identifier = ObjectIdentifier(eventType)
    registered.insert(identifier)
    knownTypes[identifier] = String(describing: eventType)
  }

  public func unregister<T>(forEvent eventType: T.Type) { //TODO useless?
    let identifier = ObjectIdentifier(eventType)
    registered.remove(identifier)
    knownTypes[identifier] = nil
  }
  
}

extension EventBus {

  @discardableResult
  public func add<T>(subscriber: T, for eventType: T.Type, queue: DispatchQueue) -> SubscriptionCancellable {
    return dispatchQueue.sync {
      validateSubscriber(subscriber)

      let subscriberObject = subscriber as AnyObject
      let subscription = Subscription<AnyObject>(subscriber: subscriberObject, queue: queue, cancellationClosure: { [weak self, weak weakSbscriberObject = subscriberObject] completion in
        guard let self = self else {
          return
        }

        if let subscriberObject = weakSbscriberObject {
          // swiftlint:disable:next force_cast
          self.remove(subscriber: subscriberObject as! T, for: eventType)
        } else {
          // the subscriber is already deallocated, so let's do some flushing for the given envent
          self.flushDeallocatedSubscribers(for: eventType)
        }
      })

      updateSubscribers(for: eventType) { subscribed in
        subscribed.insert(subscription)
      }

      return subscription.token

    }
  }
  
  /// Removes a subscriber from a given event type.
  public func remove<T>(subscriber: T, for eventType: T.Type) {
    dispatchQueue.sync {
      validateSubscriber(subscriber)
      updateSubscribers(for: eventType) { subscribed in
        // removes also all the deallocated subscribers
        while let index = subscribed.index(where: { ($0 == subscriber as AnyObject) || !$0.isValid }) {
          subscribed.remove(at: index)
        }
      }
    }
  }
  
  private func flushDeallocatedSubscribers<T>(for eventType: T.Type) {
    updateSubscribers(for: eventType) { subscribed in
      while let index = subscribed.index(where: { !$0.isValid }) {
        subscribed.remove(at: index)
      }
    }
  }
  
  /// Removes a subscriber from all its subscriptions.
  public func remove<T>(subscriber: T) {
    dispatchQueue.sync {
      validateSubscriber(subscriber)

      for (identifier, subscribed) in self.subscribed {
        self.subscribed[identifier] = self.update(set: subscribed) { subscribed in
          while let index = subscribed.index(where: { $0 == subscriber as AnyObject }) {
            subscribed.remove(at: index)
          }
        }
      }
    }
  }
  
  public func removeAllSubscribers() {
    dispatchQueue.sync {
      self.subscribed.removeAll() //TODO differentiate between Subscription and EventNotifiable?
    }
  }
  
  /// Returns all the subscriber for a given eventType.
  public func subscribers<T>(for eventType: T.Type) -> [AnyObject] {
    return dispatchQueue.sync {
      return _subscribers(for: eventType)
    }
  }
  
  /// Checks if the `EventBus` has a given subscriber for a particular eventType.
  public func hasSubscriber<T>(_ subscriber: T, for eventType: T.Type) -> Bool {
    return dispatchQueue.sync {
      validateSubscriber(subscriber)
      let subscribers = _subscribers(for: eventType).filter { $0 === subscriber as AnyObject }
      assert((0...1) ~= subscribers.count, "EventBus has subscribed \(subscribers.count) times the same subscriber.")

      return subscribers.count > 0
    }
  }
}

extension EventBus {
  
  @discardableResult
  public func notify<T>(_ eventType: T.Type, completion: (()-> Void)? = .none, closure: @escaping (T) -> Void) -> Int {
    return dispatchQueue.sync {
      var handledNotifications = 0
      let identifier = ObjectIdentifier(eventType)
      let group = DispatchGroup()

      // Notify to direct subscribers
      if let subscriptions = subscribed[identifier] {
        for subscription in subscriptions { ///.lazy.filter ({ $0.isValid }) {
          group.enter()
          // async
          subscription.notify(eventType: eventType, closure: closure) {
            group.leave()
          }
        }
        handledNotifications += subscriptions.count
      }

      group.notify(queue: dispatchQueue) {
        completion?()
      }

      return handledNotifications
    }
  }
}

// MARK: - Tests

extension EventBus {
  
  /// For tests only, returns also all the deallocated but not yet removed subscriptions
  // swiftlint:disable:next identifier_name
  internal func __subscribersCount<T>(for eventType: T.Type) -> Int {
    return dispatchQueue.sync {
      let identifier = ObjectIdentifier(eventType)
      if let subscribed = self.subscribed[identifier] {
        return subscribed.count
      }
      return 0
    }
  }
  
}

// MARK: - Subscription

public protocol SubscriptionCancellable {
  func cancel(completion: (() -> Void)?)
}


extension EventBus {
  
  /// A subscription token to cancel a subscription.
  private final class Token: SubscriptionCancellable {
    private let cancellationClosure: ((() -> Void)?) -> Void
    
    fileprivate init(cancellationClosure: @escaping ((() -> Void)?) -> Void) {
      self.cancellationClosure = cancellationClosure
    }
    
    /// Cancels the subscription associated with this token.
    ///
    /// - Parameter completion: The block executed after the cancellation has completed.
    public func cancel(completion: (() -> Void)? = nil) {
      cancellationClosure(completion)
    }
  }
  
  private final class Subscription<T>: Hashable, SubscriptionType {
    internal var isValid: Bool { return underlyngObject != nil }
    internal let token: SubscriptionCancellable
    private let queue: DispatchQueue
    fileprivate weak var underlyngObject: AnyObject?
    
    init(subscriber: AnyObject, queue: DispatchQueue, cancellationClosure: @escaping ((() -> Void)?) -> Void) {
      self.underlyngObject = subscriber as AnyObject
      self.token = Token(cancellationClosure: cancellationClosure)
      self.queue = queue
    }
    
    fileprivate func notify<T>(eventType: T.Type, closure: @escaping (T) -> Void, completion: @escaping () -> Void) {
      queue.async { [weak self] in
        guard let `self` = self else {
          return
        }
        
        if let underlyngObject = self.underlyngObject {
          if let subscriber = underlyngObject as? T {
            closure(subscriber)
            completion()
          } else if let notifier = underlyngObject as? EventNotifiable {
            notifier.notify(eventType, completion: { completion() }, closure: closure)
          }
        } else {
          self.token.cancel(completion: nil)
          completion()
        }
      }
    }
    
    fileprivate static func == (lhs: Subscription, rhs: Subscription) -> Bool {
      return lhs.underlyngObject === rhs.underlyngObject
    }
    
    fileprivate static func == (lhs: Subscription, rhs: AnyObject) -> Bool {
      return lhs.underlyngObject === rhs
    }
    
    fileprivate var hashValue: Int {
      guard let underlyngObject = underlyngObject else {
        return 0
      }
      return ObjectIdentifier(underlyngObject).hashValue
    }
  }
  
}

// MARK: - Chain

private protocol SubscriptionType {
  func notify<T>(eventType: T.Type, closure: @escaping (T) -> Void, completion: @escaping () -> Void)
}

extension EventBus: SubscriptionType {
  public func notify<T>(eventType: T.Type, closure: @escaping (T) -> Void, completion: @escaping () -> Void) {
    self.notify(eventType, completion: completion, closure: closure)
  }
}

extension EventBus {
  @discardableResult
  public func attach<T>(chain: EventNotifiable & AnyObject, for eventType: T.Type) -> SubscriptionCancellable {
    assert(chain !== self, "Trying to attach an EventBus to itself.")
    return dispatchQueue.sync {

      let subscription = Subscription<AnyObject>(subscriber: chain, queue: dispatchQueue, cancellationClosure: { [weak self, weak weakChain = chain] completion in
        guard let self = self else {
          return
        }

        if let chain = weakChain {
          self.detach(chain: chain, for: eventType)
        } else {
          // the subscriber is already deallocated, so let's do some flushing for the given envent
          self.flushDeallocatedSubscribers(for: eventType)
        }
      })

      updateSubscribers(for: eventType) { subscribed in
        subscribed.insert(subscription)
      }

      return subscription.token
    }
  }

  public func detach<T>(chain: EventNotifiable & AnyObject, for eventType: T.Type) {
    assert(chain !== self, "Trying to detach an EventBus from itself.")
    dispatchQueue.sync {
      updateSubscribers(for: eventType) { subscribed in
        // removes also all the deallocated subscribers
        while let index = subscribed.index(where: { ($0 == chain) || !$0.isValid }) {
          subscribed.remove(at: index)
        }
      }
    }
  }
  
  public func detach(chain: EventNotifiable & AnyObject) {
    assert(chain !== self, "Trying to detach an EventBus from itself.")
    dispatchQueue.sync {
      for (identifier, subscribed) in self.subscribed {
        self.subscribed[identifier] = self.update(set: subscribed) { subscribed in
          while let index = subscribed.index(where: { $0 == chain }) {
            subscribed.remove(at: index)
          }
        }
      }
    }
  }
  
  public func detachAllChains() {
    dispatchQueue.sync {
      assertionFailure("TO BE IMPLEMENTED")
    }
  }
  //
  //  internal func has<T>(chain: EventNotifiable, for eventType: T.Type) -> Bool {
  //    return self.has(chain: chain, for: eventType, options: self.options)
  //  }
  
  //  internal func has<T>(chain: EventNotifiable, for eventType: T.Type, options: Options) -> Bool {
  //    if options.contains(.warnUnknown) {
  //      self.warnIfUnknown(eventType)
  //    }
  //    return self.lock.with {
  //      guard let chained = self.chained[ObjectIdentifier(eventType)] else {
  //        return false
  //      }
  //      return chained.contains { $0 == (chain as AnyObject) }
  //    }
  //  }
}
