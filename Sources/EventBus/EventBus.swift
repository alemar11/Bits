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

public final class EventBus: EventNotifiable {
  
  private typealias SubscriberSet = Set<EventBus.Subscription<AnyObject>>
  private typealias EventBusChained = EventNotifiable & AnyObject //TODO: used?
  
  /// The `EventBus` label used for debugging.
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
  
  private let dispatchQueue: DispatchQueue
  private var registered: Set<ObjectIdentifier> = []
  private var subscribed = [ObjectIdentifier: SubscriberSet]()
  private var chained = [ObjectIdentifier: NSHashTable<AnyObject>]()
  private let lock: NSLocking = UnfairLock()
  
  /// Creates an `EventBus` with a given configuration and dispatch queue.
  ///
  /// - Parameters:
  ///   - options: the event bus' options
  ///   - notificationQueue: the dispatch queue to notify subscribers on
  public init(label: String? = nil) {
    self.label = label
    self.dispatchQueue = DispatchQueue(label: "\(identifier).EventBus") //TODO qos
  }
  
  deinit {
    print("EventBus deinit")
  }
  
}

// MARK: - Update Subscriber

extension EventBus {
  
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
  
  public func register<T>(forEvent eventType: T.Type) {
    let identifier = ObjectIdentifier(eventType)
    registered.insert(identifier)
    knownTypes[identifier] = String(describing: eventType)
  }
  
}

extension EventBus {
  
  private func validateSubscriber<T>(_ subscriber: T) {
    precondition(Mirror(reflecting: subscriber).subjectType is AnyClass, "The subscriber \(String(describing: subscriber.self)) must be a class.")
  }
  
  @discardableResult
  public func add<T>(subscriber: T, for eventType: T.Type, queue: DispatchQueue) -> SubscriptionCancellable {
    lock.lock()
    defer { lock.unlock() }
    
    validateSubscriber(subscriber)

    let subscriberObject = subscriber as AnyObject
    let subscription = Subscription<AnyObject>(subscriber: subscriberObject, queue: queue, cancellationClosure: { [weak self, weak subscriberObject = subscriberObject] completion in
      guard let self = self else {
        return
      }
      
      if let sub = subscriberObject {
        // swiftlint:disable:next force_cast
        self.remove(subscriber: sub as! T, for: eventType)
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
  
  /// Removes a subscriber from a given event type.
  public func remove<T>(subscriber: T, for eventType: T.Type) {
    lock.lock()
    defer { lock.unlock() }
    
    validateSubscriber(subscriber)
    //self.warnIfUnknown(eventType)
    
    updateSubscribers(for: eventType) { subscribed in
      // removes also all the deallocated subscribers
      while let index = subscribed.index(where: { ($0 == subscriber as AnyObject) || !$0.isValid }) {
        subscribed.remove(at: index)
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
    lock.lock()
    defer { lock.unlock() }
    
    validateSubscriber(subscriber)
    //    self.warnIfNonClass(subscriber)
    
    for (identifier, subscribed) in self.subscribed {
      self.subscribed[identifier] = self.update(set: subscribed) { subscribed in
        while let index = subscribed.index(where: { $0 == subscriber as AnyObject }) {
          subscribed.remove(at: index)
        }
      }
    }
  }
  
  public func removeAllSubscribers() {
    lock.lock()
    defer { lock.unlock() }
    
    self.subscribed.removeAll() //TODO differentiate between Subscription and EventNotifiable?
  }
  
  /// Returns all the subscriber for a given eventType.
  internal func subscribers<T>(for eventType: T.Type) -> [AnyObject] {
    let identifier = ObjectIdentifier(eventType)
    if let subscribed = self.subscribed[identifier] {
      return subscribed.filter { $0.isValid }.compactMap { $0.underlyngObject }
    }
    return []
  }
  
  /// Checks if the `EventBus` has a given subscriber for a particular eventType.
  internal func hasSubscriber<T>(_ subscriber: T, for eventType: T.Type) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    
    validateSubscriber(subscriber)
    //      self.warnIfUnknown(eventType)
    let subscribers = self.subscribers(for: eventType).filter { $0 === subscriber as AnyObject }
    assert((0...1) ~= subscribers.count, "EventBus has subscribed \(subscribers.count) times the same subscriber.")
    
    return subscribers.count > 0
  }
}

extension EventBus {
  
  @discardableResult
  public func notify<T>(_ eventType: T.Type, completion: (()-> Void)? = .none, closure: @escaping (T) -> Void) -> Bool { //TODO: add a completion for tests?
    lock.lock()
    defer { lock.unlock() }
    //      self.warnIfUnknown(eventType)
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
    
    // Notify to indirect subscribers
    if let chains = self.chained[identifier] {
      for chain in chains.allObjects.compactMap({ $0 as? EventNotifiable }) {
        group.enter()
        let status = chain.notify(eventType, completion: {
          group.leave()
        }, closure: closure)
        handledNotifications += status ? 1 : 0
      }
    }
    
    //          if (handled == 0) && options.contains(.warnUnhandled) {
    //            self.warnUnhandled(eventType)
    //          }
    
    group.notify(queue: dispatchQueue) {
      completion?()
    }
    
    return handledNotifications > 0
  }
}

extension EventBus {
  
  /// For tests only, returns also all the deallocated but not yet removed subscriptions
  // swiftlint:disable:next identifier_name
  internal func __subscribersCount<T>(for eventType: T.Type) -> Int { //TODO: name
    let identifier = ObjectIdentifier(eventType)
    if let subscribed = self.subscribed[identifier] {
      return subscribed.count
    }
    return 0
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
          } else if let bus = underlyngObject as? EventNotifiable {
            bus.notify(eventType, completion: { completion() }, closure: closure)
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

public protocol SubscriptionType {
  func notify<T>(eventType: T.Type, closure: @escaping (T) -> Void, completion: @escaping () -> Void)
}

extension EventBus: SubscriptionType {
  public func notify<T>(eventType: T.Type, closure: @escaping (T) -> Void, completion: @escaping () -> Void) {
    self.notify(eventType, completion: completion, closure: closure)
  }
}

public protocol EventNotifiable {
  @discardableResult
  func notify<T>(_ eventType: T.Type, completion: (()-> Void)?, closure: @escaping (T) -> Void) -> Bool
}

public protocol EventBusChainable {
  @discardableResult
  func attach<T>(chain: EventNotifiable & AnyObject, for eventType: T.Type, queue: DispatchQueue) -> SubscriptionCancellable
  func detach<T>(chain: EventNotifiable & AnyObject, for eventType: T.Type)
  func detach(chain: EventNotifiable & AnyObject)
  func detachAllChains()
}

extension EventBus: EventBusChainable {
  @discardableResult
  public func attach<T>(chain: EventNotifiable & AnyObject, for eventType: T.Type, queue: DispatchQueue = .global()) -> SubscriptionCancellable {
    assert(chain !== self, "Trying to attach an EventBus to itself.")
    lock.lock()
    defer { lock.unlock() }
    
    let subscription = Subscription<AnyObject>(subscriber: chain, queue: queue, cancellationClosure: { [weak self, weak weakChain = chain] completion in
      guard let self = self else {
        return
      }
      
      if let sub = weakChain {
        self.detach(chain: sub, for: eventType)
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
  
  public func detach<T>(chain: EventNotifiable & AnyObject, for eventType: T.Type) {
    assert(chain !== self, "Trying to detach an EventBus from itself.")
    lock.lock()
    defer { lock.unlock() }
    //      self.warnIfUnknown(eventType)
    
    updateSubscribers(for: eventType) { subscribed in
      // removes also all the deallocated subscribers
      while let index = subscribed.index(where: { ($0 == chain) || !$0.isValid }) {
        subscribed.remove(at: index)
      }
    }
  }
  
  public func detach(chain: EventNotifiable & AnyObject) {
    assert(chain !== self, "Trying to detach an EventBus from itself.")
    lock.lock()
    defer { lock.unlock() }
    
    for (identifier, subscribed) in self.subscribed {
      self.subscribed[identifier] = self.update(set: subscribed) { subscribed in
        while let index = subscribed.index(where: { $0 == chain }) {
          subscribed.remove(at: index)
        }
      }
    }
  }
  
  public func detachAllChains() {
    lock.lock()
    defer { lock.unlock() }
    assertionFailure("TO BE IMPLEMENTED")
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
