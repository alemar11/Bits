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

public final class EventBus {

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

  fileprivate var knownTypes: [ObjectIdentifier: Any] = [:]

  private let dispatchQueue: DispatchQueue //TODO: check if it should serial or concurrent
  private var registered: Set<ObjectIdentifier> = []
  private var subscribed = [ObjectIdentifier: SubscriberSet]()
  typealias SubscriberSet = Set<EventBus.Subscriber<AnyObject>>


  /// Creates an `EventBus` with a given configuration and dispatch queue.
  ///
  /// - Parameters:
  ///   - options: the event bus' options
  ///   - notificationQueue: the dispatch queue to notify subscribers on
  public init(options: Options? = nil, label: String? = nil, queue: DispatchQueue = .global()) {
    self.options = options ?? Options()
    self.label = label
    self.dispatchQueue = queue
  }


}

// MARK: - Update Subscriber

extension EventBus {
  @inline(__always)
  fileprivate func updateSubscribers<T>(for eventType: T.Type, closure: (inout SubscriberSet) -> ()) {
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
  fileprivate func update(set: SubscriberSet, closure: (inout SubscriberSet) -> ()) -> SubscriberSet? {
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

  public func add<T>(subscriber: T, for eventType: T.Type, options: Options? = .none) {
//    self.warnIfNonClass(subscriber)
//    if options.contains(.warnUnknown) {
//      self.warnIfUnknown(eventType)
//    }
//    self.lock.with {

    let sub = Subscriber<AnyObject>(subscriber: subscriber as AnyObject, queue: dispatchQueue, cancellationClosure: { [weak self] completion in
      guard let self = self else { return }
      self.remove(subscriber: subscriber, for: eventType, options: options)
    })

      updateSubscribers(for: eventType) { subscribed in
        subscribed.insert(sub)
    }
  }


  /// Removes a subscriber from a given event type.
  public func remove<T>(subscriber: T, for eventType: T.Type, options: Options? = .none) {
//    self.warnIfNonClass(subscriber)
//    if options.contains(.warnUnknown) {
//      self.warnIfUnknown(eventType)
//    }
//    self.lock.with {
      updateSubscribers(for: eventType) { subscribed in
//        subscribed.remove(subscriber as AnyObject)
        while let index = subscribed.index(where: { $0 == subscriber as AnyObject }) {
          subscribed.remove(at: index)
        }
      }
//    }
  }

  /// Removes a subscriber from all its subscriptions.
  public func remove<T>(subscriber: T, options: Options? = .none) {
//    self.warnIfNonClass(subscriber)
//    self.lock.with {
      for (identifier, subscribed) in self.subscribed {
        self.subscribed[identifier] = self.update(set: subscribed) { subscribed in
          //subscribed.remove(subscriber as AnyObject)
          while let index = subscribed.index(where: { $0 == subscriber as AnyObject }) {
            subscribed.remove(at: index)
          }
        }
      }
//    }
  }

  public func removeAllSubscribers() {
    self.subscribed.removeAll()
//    self.lock.with {
//      self.subscribed = [:]
//    }
  }

//  internal func has<T: AnyObject>(subscriber: T, for eventType: T.Type, options: Options? = .none) -> Bool {
////    self.warnIfNonClass(subscriber)
////    if options.contains(.warnUnknown) {
////      self.warnIfUnknown(eventType)
////    }
////    return self.lock.with {
//      guard let subscribed = self.subscribed[ObjectIdentifier(eventType)] else {
//        return false
//      }
//    return subscribed.contains(subscriber as AnyObject)
////    }
//  }
}

extension EventBus {
  
  @discardableResult
  public func notify<T>(_ eventType: T.Type, options: Options? = .none, closure: @escaping (T) -> ()) -> Bool {
//    if options.contains(.warnUnknown) {
//      self.warnIfUnknown(eventType)
//    }
//    self.logEvent(eventType)
    //return self.lock.with {
      var handledNotifications = 0
      let identifier = ObjectIdentifier(eventType)

      // Notify to direct subscribers
      if let subscribers = subscribed[identifier] {
        for subscriber in subscribers.lazy.filter ({ $0.isValid }) {
          self.dispatchQueue.async {
          
            subscriber.notify(closure: closure)
            //closure(subscriber)
          }
        }
        handledNotifications += subscribers.count
      }

      // Notify to indirect subscribers
//      if let chains = self.chained[identifier] {
//        for chain in chains.lazy.compactMap({ $0.inner as? EventNotifiable }) {
//          handled += chain.notify(eventType, closure: closure) ? 1 : 0
//        }
//      }
//      if (handled == 0) && options.contains(.warnUnhandled) {
//        self.warnUnhandled(eventType)
//      }
      return handledNotifications > 0
    //}
  }
}

extension EventBus {

  /// A subscription token to cancel a subscription.
  public final class Token {
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

//    deinit {
//      cancel()
//    }
  }

  class Subscriber<T: AnyObject>: Hashable {
    internal var isValid: Bool { return underlyngObject != nil }
    internal let token: Token
    private let queue: DispatchQueue
    fileprivate weak var underlyngObject: T?

    init(subscriber: T, queue: DispatchQueue, cancellationClosure: @escaping ((() -> Void)?) -> Void) {
      self.underlyngObject = subscriber
      self.token = Token(cancellationClosure: cancellationClosure)
      self.queue = queue
    }

    fileprivate func notify(closure: @escaping (T) -> ()) {
        queue.async { [weak self] in
          guard let `self` = self else { return }

          if let underlyngObject = self.underlyngObject {
            //self.block(value, self.token)
            closure(underlyngObject)
          } else {
            self.token.cancel()
          }
        }
    }

    internal static func == (lhs: Subscriber, rhs: Subscriber) -> Bool {
      return lhs.underlyngObject === rhs.underlyngObject
    }

    internal static func == (lhs: Subscriber, rhs: AnyObject) -> Bool {
      return lhs.underlyngObject === rhs
    }

    internal var hashValue: Int {
      guard let underlyngObject = underlyngObject else {
        return 0
      }
      return ObjectIdentifier(underlyngObject).hashValue
    }
  }

}

extension EventBus {
  internal func subscribers<T>(for eventType: T.Type) -> [AnyObject] {
    let identifier = ObjectIdentifier(eventType)
    if let subscribed = self.subscribed[identifier] {
      return subscribed.filter { $0.isValid }.compactMap { $0.underlyngObject }
    }
    return []
  }

  internal var __subscribers: [ObjectIdentifier: SubscriberSet] {
    return subscribed
  }
}
