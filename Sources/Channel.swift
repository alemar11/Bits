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
/// An event bus object which provides an API to broadcast messages to its subscribers.
public final class Channel<Value> {

  // MARK: - Properties
  /// An internal queue for concurrent readings and exclusive writing.
  private let queue: DispatchQueue

  /// A list of all the subscriptions.
  private var _subscriptions = [Subscription]()

  /// A list of all the subscriptions.
  internal var subscriptions: [Subscription] {
    return queue.sync(flags: .barrier) {
      return _subscriptions
    }
  }

  // MARK: - Initializers
  /// **Bits**
  ///
  /// Creates a subscription instance.
  public init() {
    self.queue = DispatchQueue(label: "\(identifier).\(type(of: self))", qos: .default, attributes: .concurrent)
  }

  // MARK: - Subscription
  /// **Bits**
  ///
  /// Subscribes a given object.
  ///
  /// - Parameters:
  ///   - object: Object to subscribe.
  ///   - queue: Queue for given block to be called in. If you pass nil, the block is run synchronously on the posting thread.
  ///   - completion: A block called once the object is subscribed with a token to cancel the subscription is passed.
  ///   - block: Block to call upon broadcast with a token to cancel the subscription.
  /// - Note: A *nil* queue can cause a **race condition** if there are more than one posting threads; in that case solving the race issue is up to the developer (i.e. using a lock or another queue).
  public func subscribe(_ object: AnyObject?, queue dispatchQueue: DispatchQueue? = nil, completion: ((Token) -> Void)? = nil, block: @escaping (Value, Token) -> Void) {
    let token = Token { [weak self, weak object = object] completion in
      self?.unsubscribe(object, completion: {
        completion?()
      })
    }

    let subscription = Subscription(object: object, queue: dispatchQueue, token: token, block: block)

    queue.async(flags: .barrier, execute: { [weak self] in
      self?._subscriptions.append(subscription)
      completion?(token)
    })

  }

  /// **Bits**
  ///
  /// Unsubscribes given object.
  ///
  /// - Parameters:
  ///   - object: Object to remove.
  ///   - completion: A block called once the object is unsubscribe.
  public func unsubscribe(_ object: AnyObject?, completion: (() -> Void)? = nil) {
    queue.async(flags: .barrier, execute: { [weak self] in
      guard let `self` = self else { return }

      if let foundIndex = self._subscriptions.index(where: { $0.object === object }) {
        self._subscriptions.remove(at: foundIndex)
      }
      completion?()
    })
  }

  /// **Bits**
  ///
  /// Broadcasts given value to subscribers.
  ///
  /// - Parameters:
  ///   - value: Value to broadcast.
  ///   - completion: Completion handler called after notifing all subscribers.
  public func broadcast(_ value: Value) {
    flushCancelledSubscribers()

    queue.sync { [weak self] in
      guard let `self` = self else { return }

      self._subscriptions.forEach { $0.notify(value) }
    }
  }

  /// Asynchronously flushes all the invalid (no more active) subscribers.
  internal func flushCancelledSubscribers() {
    queue.async(flags: .barrier, execute: { [weak self] in
      guard let `self` = self else { return }

      self._subscriptions = self._subscriptions.filter { $0.isValid } //TODO: swift 4.2, removeAll(where:)
    })
  }
}

extension Channel {

  /// **Bits**
  ///
  /// A subscription token to cancel a subscription.
  public struct Token {
    private let cancellationClosure: ((() -> Void)?) -> Void

    fileprivate init(cancellationClosure: @escaping ((() -> Void)?) -> Void) {
      self.cancellationClosure = cancellationClosure
    }

    /// **Bits**
    ///
    /// Cancels the subscription associated with this token.
    ///
    /// - Parameter completion: The block executed after the cancellation has completed.
    public func cancel(completion: (() -> Void)? = nil) {
      cancellationClosure(completion)
    }
  }

  // MARK: - Subscription
  /// **Bits**
  ///
  /// A subscription.
  internal final class Subscription {

    internal weak var object: AnyObject?
    internal let uuid = UUID()
    internal var isValid: Bool { return object != nil }
    internal let token: Token
    private let queue: DispatchQueue?
    private let block: (Value, Token) -> Void

    internal init(object: AnyObject?, queue: DispatchQueue?, token: Token, block: @escaping (Value, Token) -> Void) {
      self.object = object
      self.queue = queue
      self.token = token
      self.block = block
    }

    fileprivate func notify(_ value: Value) {
      if let queue = queue {
        queue.async { [weak self] in
          guard let `self` = self else { return }

          if self.isValid {
            self.block(value, self.token)
          }
        }
      } else {
        if isValid {
          block(value, token)
        }
      }
    }

  }

}
