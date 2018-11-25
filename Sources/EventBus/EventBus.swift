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

public struct Options: OptionSet {
  /// See protocol `OptionSet`
  public let rawValue: Int
  
  /// See protocol `OptionSet`
  public init(rawValue: Int) {
    self.rawValue = rawValue
  }
}

public final class EventBus: EventNotifiable {
  
  private typealias SubscriberSet = Set<EventBus.Subscription<AnyObject>>
  private typealias EventBusChained = EventNotifiable & AnyObject //TODO: used?
  
  /// The `EventBus` label used for debugging.
  public let label: String?
  
  /// The `EventBus` configuration options.
  public let options: Options
  
  /// The event types the `EventBus` is registered for.
  public var registeredEventTypes: [Any] {
    return self.registered.compactMap { self.knownTypes[$0] }
  }
  
  /// The event types the `EventBus` has subscribers for.
  public var subscribedEventTypes: [Any] {
    return self.subscribed.keys.compactMap { self.knownTypes[$0] }
  }
  
  internal var onNotified: (() -> Void)? = .none //TODO
  
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
  public init(options: Options? = nil, label: String? = nil) {
    self.options = options ?? Options()
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
  
  //  @inline(__always)
  //  fileprivate func updateChains<T>(for eventType: T.Type, closure: (inout NSHashTable<AnyObject>) -> ()) {
  //    let identifier = ObjectIdentifier(eventType)
  //    let chained = self.chained[identifier] ?? []
  //    self.chained[identifier] = self.update(set: chained, closure: closure)
  //    self.knownTypes[identifier] = String(describing: eventType)
  //  }
  
  @inline(__always)
  private func update(set: SubscriberSet, closure: (inout SubscriberSet) -> Void) -> SubscriberSet? {
    var mutableSet = set
    closure(&mutableSet)
    // Remove weak nil elements
    let filteredSet = mutableSet.filter { $0.isValid }
    return filteredSet.isEmpty ? nil : filteredSet
  }
  
  @inline(__always)
  private func update2(set: NSHashTable<AnyObject>, closure: (inout NSHashTable<AnyObject>) -> Void) -> NSHashTable<AnyObject>? {
    var mutableSet = set
    closure(&mutableSet)
    // Remove weak nil elements
    return mutableSet.allObjects.isEmpty ? nil : mutableSet //TODO check is weak object are removed
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
  public func add<T>(subscriber: T, for eventType: T.Type, queue: DispatchQueue, options: Options? = .none) -> SubscriptionCancellable {
    lock.lock()
    defer { lock.unlock() }
    
    validateSubscriber(subscriber)
    
    //    self.warnIfNonClass(subscriber)
    //    if options.contains(.warnUnknown) {
    //      self.warnIfUnknown(eventType)
    //    }
    //    self.lock.with {
    
    let subscriberObject = subscriber as AnyObject
    let subscription = Subscription<AnyObject>(subscriber: subscriberObject, queue: queue, cancellationClosure: { [weak self, weak subscriberObject = subscriberObject] completion in
      guard let self = self else {
        return
      }
      
      if let sub = subscriberObject {
        // swiftlint:disable:next force_cast
        self.remove(subscriber: sub as! T, for: eventType, options: options)
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
  public func remove<T>(subscriber: T, for eventType: T.Type, options: Options? = .none) {
    lock.lock()
    defer { lock.unlock() }
    
    validateSubscriber(subscriber)
    //    self.warnIfNonClass(subscriber)
    //    if options.contains(.warnUnknown) {
    //      self.warnIfUnknown(eventType)
    //    }
    
    updateSubscribers(for: eventType) { subscribed in
      // removes also all the deallocated subscribers
      while let index = subscribed.index(where: { ($0 == subscriber as AnyObject) || !$0.isValid }) {
        print("🚩🚩 removed subscription")
        subscribed.remove(at: index)
      }
    }
  }
  
  private func flushDeallocatedSubscribers<T>(for eventType: T.Type, options: Options? = .none) {
    updateSubscribers(for: eventType) { subscribed in
      while let index = subscribed.index(where: { !$0.isValid }) {
        print("🚩🚩 flushed subscriptions")
        subscribed.remove(at: index)
      }
    }
  }
  
  /// Removes a subscriber from all its subscriptions.
  public func remove<T>(subscriber: T, options: Options? = .none) {
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
    
    self.subscribed.removeAll()
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
  internal func hasSubscriber<T>(_ subscriber: T, for eventType: T.Type, options: Options? = .none) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    
    validateSubscriber(subscriber)
    //    if options.contains(.warnUnknown) {
    //      self.warnIfUnknown(eventType)
    //    }
    let subscribers = self.subscribers(for: eventType).filter { $0 === subscriber as AnyObject }
    assert((0...1) ~= subscribers.count, "EventBus has subscribed \(subscribers.count) times the same subscriber.")
    
    return subscribers.count > 0
  }
}

extension EventBus {
  
  @discardableResult
  public func notify<T>(_ eventType: T.Type, options: Options? = .none, closure: @escaping (T) -> Void) -> Bool { //TODO: add a completion for tests?
    lock.lock()
    defer { lock.unlock() }
    
    //    if options.contains(.warnUnknown) {
    //      self.warnIfUnknown(eventType)
    //    }
    //    self.logEvent(eventType)
    var handledNotifications = 0
    let identifier = ObjectIdentifier(eventType)
    let group = DispatchGroup()
    
    // Notify to direct subscribers
    if let subscriptions = subscribed[identifier] {
      for subscription in subscriptions { ///.lazy.filter ({ $0.isValid }) {
        group.enter()
        // async
        subscription.notify(closure: closure) {
          group.leave()
        }
      }
      handledNotifications += subscriptions.count
    }
    
    // Notify to indirect subscribers
    if let chains = self.chained[identifier] {
      for chain in chains.allObjects.lazy.compactMap({ $0 as? EventNotifiable }) {
        let status = chain.notify(eventType, options: nil, closure: closure)
        handledNotifications += status ? 1 : 0
      }
    }
    
    //          if (handled == 0) && options.contains(.warnUnhandled) {
    //            self.warnUnhandled(eventType)
    //          }
    
    ////_ = group.wait(timeout: .distantFuture)
    group.notify(queue: dispatchQueue) { [weak self] in
      self?.onNotified?()
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
  
  private final class Subscription<T>: Hashable {
    internal var isValid: Bool { return underlyngObject != nil }
    internal let token: SubscriptionCancellable
    private let queue: DispatchQueue
    fileprivate weak var underlyngObject: AnyObject?
    
    init(subscriber: AnyObject, queue: DispatchQueue, cancellationClosure: @escaping ((() -> Void)?) -> Void) {
      self.underlyngObject = subscriber as AnyObject
      self.token = Token(cancellationClosure: cancellationClosure)
      self.queue = queue
    }
    
    fileprivate func notify<T>(closure: @escaping (T) -> Void, completion: @escaping () -> Void) {
      queue.async { [weak self] in
        guard let `self` = self else {
          return
        }
        
        if let underlyngObject = self.underlyngObject {
          // swiftlint:disable:next force_cast
          closure(underlyngObject as! T)
        } else {
          self.token.cancel(completion: nil)
        }
        
        completion()
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

public protocol EventBusType { }

public protocol EventNotifiable: EventBusType {
  @discardableResult
  func notify<T>(_ eventType: T.Type, options: Options?, closure: @escaping (T) -> Void) -> Bool //TODO: options?
}

public protocol EventBusChainable: EventBusType {
  func attach<T>(chain: EventNotifiable & AnyObject, for eventType: T.Type)
  func detach<T>(chain: EventNotifiable & AnyObject, for eventType: T.Type)
  func detach(chain: EventNotifiable & AnyObject)
  func detachAllChains()
}

extension EventBus: EventBusChainable {
  //@inline(__always)
  fileprivate func updateChains<T>(for eventType: T.Type, closure: (inout NSHashTable<AnyObject>) -> ()) {
    let identifier = ObjectIdentifier(eventType)
    let chained = self.chained[identifier] ?? NSHashTable()
    self.chained[identifier] = self.update2(set: chained, closure: closure)
    self.knownTypes[identifier] = String(describing: eventType)
  }
  
  public func attach<T>(chain: EventNotifiable & AnyObject, for eventType: T.Type) {
    return self.attach(chain: chain, for: eventType, options: self.options)
  }
  
  public func attach<T>(chain: EventNotifiable & AnyObject, for eventType: T.Type, options: Options) {
    lock.lock()
    defer { lock.unlock() }
    //    if options.contains(.warnUnknown) {
    //      self.warnIfUnknown(eventType)
    //    }
    self.updateChains(for: eventType) { chained in
      chained.add(chain)
      //chained.insert(WeakBox(chain as AnyObject))
    }
  }
  
  public func detach<T>(chain: EventNotifiable & AnyObject, for eventType: T.Type) {
    return self.detach(chain: chain, for: eventType, options: self.options)
  }
  
  public func detach<T>(chain: EventNotifiable & AnyObject, for eventType: T.Type, options: Options) {
    //    if options.contains(.warnUnknown) {
    //      self.warnIfUnknown(eventType)
    //    }
    
    lock.lock()
    defer { lock.unlock() }
    self.updateChains(for: eventType) { chained in
      chained.remove(chain)
    }
    
  }
  
  public func detach(chain: EventNotifiable & AnyObject) {
    lock.lock()
    defer { lock.unlock() }
    
    for (identifier, chained) in self.chained {
      self.chained[identifier] = self.update2(set: chained) { chained in
        chained.remove(chain)
      }
    }
  }
  
  public func detachAllChains() {
    lock.lock()
    defer { lock.unlock() }
    self.chained.removeAll()
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
