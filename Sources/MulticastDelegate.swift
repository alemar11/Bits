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
///
/// - Attention: You cannot currently create weak references to instances of the following classes:
///
/// **macOS**
///
/// NSFontManager, NSFontPanel, NSTextView, NSFont, AVFoundation
///
/// **iOS**
///
/// AVFoundation
///
public final class MulticastDelegate<T> {
  private var delegates = [Weak]()

  /// Returns `true` if there are no delegates at all, `false` if there is at least one.
  public var isEmpty: Bool {
    removeDeallocatedDelegates()
    return delegates.isEmpty
  }

  /// Returns the number of delegates.
  public func numberOfDelegates() -> Int {
    removeDeallocatedDelegates()
    return delegates.count
  }

  /// Adds a delelgate.
  ///
  /// - Parameters:
  ///   - delegate: The delegate to be added.
  ///   - queue: The queue where the delegate should be called on.
  public func add(_ delegate: T, on queue: DispatchQueue = .main) {
    guard validate(delegate) else {
      fatalError("Multicast delegates do not support value types.")
    }

    guard !contains(delegate) else {
      return
    }

    let weakValue = Weak(value: delegate as AnyObject, queue: queue)
    delegates.append(weakValue)
  }

  /// Removes a previously-added delegate.
  ///
  /// - Parameter delegate: The delegate to be removed.
  public func remove(_ delegate: T) {
    if validate(delegate) {
      delegates.removeAll { $0 == delegate as AnyObject || $0.delegate == nil }
    }
  }

  /// Removes all the previously-added delegates.
  public func removeAllDelegates() {
    delegates.removeAll()
  }

  /// Invokes a closure on each delegate.
  ///
  /// - Parameter invocation: The closure to be invoked on each delegate.
  public func invoke(_ invocation: @escaping (T) -> Void) {
    var indices = IndexSet()
    for (index, delegate) in delegates.enumerated() {
      let queue = delegate.queue
      if let delegate = delegate.delegate as? T {
        queue.async {
          invocation(delegate)
        }
      } else {
        indices.insert(index)
      }
    }

    removeObjects(atIndices: indices)
  }

  /// Returns a Boolean value that indicates whether the multicast delegate contains a given delegate.
  ///
  /// - Parameter delegate: The given delegate to check if it's contained
  /// - Returns: `true` if the delegate is found or `false` otherwise
  public func contains(_ delegate: T) -> Bool {
    if validate(delegate) {
      return delegates.contains { $0 == delegate as AnyObject }
    }
    return false
  }

  private func removeDeallocatedDelegates() {
    delegates.removeAll { $0.delegate == nil }
  }

  private func removeObjects(atIndices indices: IndexSet) {
    let indexArray = Array(indices).sorted(by: >)
    for index in indexArray {
      delegates.remove(at: index)
    }
  }

  @inline(__always)
  private func validate(_ delegate: T) -> Bool {
    return Mirror(reflecting: delegate).subjectType is AnyClass
  }

  private final class Weak: Equatable {
    weak var delegate: AnyObject?
    let queue: DispatchQueue

    init(value: AnyObject, queue: DispatchQueue) {
      self.delegate = value
      self.queue = queue
    }

    static func == (lhs: Weak, rhs: Weak) -> Bool {
      return lhs.delegate === rhs.delegate
    }

    static func == (lhs: Weak, rhs: AnyObject) -> Bool {
      return lhs.delegate === rhs
    }
  }

}
