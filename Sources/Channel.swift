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

/// An event bus object which provides an API to broadcast messages to its subscribers.
public class Channel<Value> {

  internal class Subscription {

    weak var object: AnyObject?
    private let queue: DispatchQueue?
    private let block: (Value) -> Void

    var isValid: Bool {
      return object != nil
    }

    init(object: AnyObject?, queue: DispatchQueue?, block: @escaping (Value) -> Void) {
      self.object = object
      self.queue = queue
      self.block = block
    }

    func notify(_ value: Value) {
      if let queue = queue {
        queue.async { [weak self] in
          guard let strongSelf = self else { return }

          if strongSelf.isValid {
            strongSelf.block(value)
          }
        }
      } else {
        if isValid {
          block(value)
        }
      }
    }

  }

  internal var subscriptions: Protected<[Subscription]> = Protected([])

  /// Creates a channel instance.
  public init() { }

  /// Subscribes given object to channel.
  ///
  /// - Parameters:
  ///   - object: Object to subscribe.
  ///   - queue: Queue for given block to be called in. If you pass nil, the block is run synchronously on the posting thread.
  ///   - block: Block to call upon broadcast.
  public func subscribe(_ object: AnyObject?, queue: DispatchQueue? = nil, block: @escaping (Value) -> Void) {
    let subscription = Subscription(object: object, queue: queue, block: block)

    subscriptions.write { list in
      list.append(subscription)
    }
  }

  /// Unsubscribes given object from channel.
  ///
  /// - Parameter object: Object to remove.
  public func unsubscribe(_ object: AnyObject?) {
    subscriptions.write { list in
      if let foundIndex = list.index(where: { $0.object === object }) {
        list.remove(at: foundIndex)
      }
    }
  }

  /// Broadcasts given value to subscribers.
  ///
  /// - Parameters:
  ///   - value: Value to broadcast.
  ///   - completion: Completion handler called after notifing all subscribers.
  public func broadcast(_ value: Value) {
    subscriptions.write(mode: .sync) { list in
      list = list.filter({ $0.isValid })
      list.forEach({ $0.notify(value) })
    }
  }
}
