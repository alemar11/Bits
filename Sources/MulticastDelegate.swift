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
/// `MulticastDelegate` lets you easily create a thread safe "multicast delegate" for a given protocol or class.
open class MulticastDelegate<T> {

  /// The delegates hash table.
  private let delegates: NSHashTable<AnyObject>

  /// Returns `true` if there are no delegates at all, `false` if there is at least one.
  public var isEmpty: Bool {
    return delegates.allObjects.isEmpty
  }

  /// Returns the number of delegates.
  public var count: Int {
    return delegates.allObjects.count
  }

  /// Initializes a new `MulticastDelegate` specifying whether delegate references should be weak or strong.
  ///
  /// - Parameter usingStrongReferences: Whether delegates should be strongly referenced, false by default.
  public init(usingStrongReferences: Bool = false) {
    delegates = usingStrongReferences ? NSHashTable<AnyObject>() : NSHashTable<AnyObject>.weakObjects()
  }

  /// Adds a delelgate.
  ///
  /// - Parameter delegate: The delegate to be added.
  public func addDelegate(_ delegate: T) {
    validateDelegate(delegate)
    delegates.add(delegate as AnyObject)
  }

  /// Removes a previously-added delegate.
  ///
  /// - Parameter delegate: The delegate to be removed.
  public func removeDelegate(_ delegate: T) {
    validateDelegate(delegate)
    for oneDelegate in delegates.allObjects.reversed() where oneDelegate === delegate as AnyObject {
      delegates.remove(oneDelegate)
    }
  }

  /// Invokes a closure on each delegate.
  ///
  /// - Parameter invocation: The closure to be invoked on each delegate.
  public func invoke(invocation: @escaping (T) -> Void) {
    delegates.allObjects.forEach { delegate in
      // swiftlint:disable:next force_cast
      invocation(delegate as! T)
    }
  }

  /// Returns a Boolean value that indicates whether the multicast delegate contains a given delegate.
  ///
  /// - Parameter delegate: The given delegate to check if it's contained
  /// - Returns: `true` if the delegate is found or `false` otherwise
  public func containsDelegate(_ delegate: T) -> Bool {
    validateDelegate(delegate)
    return delegates.contains(delegate as AnyObject)
  }

  private func validateDelegate<T>(_ delegate: T) {
    precondition(Mirror(reflecting: delegate).subjectType is AnyClass, "The Delegate \(String(describing: delegate.self)) must be a class.")
  }
}

public func += <T> (left: MulticastDelegate<T>, right: T) {
  left.addDelegate(right)
}

public func -= <T> (left: MulticastDelegate<T>, right: T) {
  left.removeDelegate(right)
}
