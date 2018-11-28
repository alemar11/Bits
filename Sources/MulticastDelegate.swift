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
    delegates.remove(delegate as AnyObject)
  }

  /// Removes all the previously-added delegates.
  public func removeAllDelegates() {
    delegates.removeAllObjects()
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

//extension MulticastDelegate: Sequence {
//  public func makeIterator() -> AnyIterator<T> {
//    var iterator = delegates.allObjects.makeIterator()
//
//    return AnyIterator {
//      while let next = iterator.next() {
//        if let delegate = next as? T {
//          return delegate
//        }
//      }
//      return nil
//    }
//  }
//}

// https://stackoverflow.com/questions/9146540/which-ios-classes-that-dont-support-zeroing-weak-references
// > NSATSTypesetter, NSFont, NSFontManager, NSFontPanel, NSImage, NSMenuView,
// > NSParagraphStyle, NSSimpleHorizontalTypesetter, NSTableCellView, NSTextView

// 10.8
// Starting in 10.8, instances of NSWindow, NSWindowController, and NSViewController can be pointed to by ARC weak references.

// 10.14
//NSColorSpace
//NSColorSpace now supports Objective-C weak references. NSColorSpace instances can now be stored in weak instance variables or collections.

open class GCDMulticastDelegate<T> {

  private var nodes = Set<Node<AnyObject>>()

  public init() { }

  deinit {
    removeAllDelegates()
  }

  public var isEmpty: Bool {
    return nodes.isEmpty
  }

  /// Returns the number of delegates.
  public var count: Int {
    return nodes.filter { $0.delegate != nil }.count
  }

  public func addDelegate(_ delegate: T, on queue: DispatchQueue) {
    let node = Node(delegate: delegate as AnyObject, queue: queue)
    nodes.insert(node)
  }

  public func invoke(invocation: @escaping (T) -> Void) {
    var deallocatedNodes = [Node<AnyObject>]()

    for node in self.nodes {
      if let delegate = node.delegate {
        invocation(delegate as! T)
      } else {
        deallocatedNodes.append(node)
      }
    }

    for deallocatedNode in deallocatedNodes {
      self.nodes.remove(deallocatedNode)
    }
  }

  public func removeDelegate(_ delegate: T) {
    while let index = nodes.index(where: { $0.delegate === delegate as AnyObject || $0.delegate == nil }) {
      nodes.remove(at: index)
    }
  }

  public func removeAllDelegates() {
    nodes.removeAll()
  }

  public func containsDelegate(_ delegate: T) -> Bool {
    return nodes.contains { $0.delegate === delegate as AnyObject }
  }

  // MARK: - Node

  fileprivate final class Node<T: AnyObject>: Hashable {
    let queue: DispatchQueue
    weak var delegate: T?

    init(delegate: T, queue: DispatchQueue) {
      self.delegate = delegate
      self.queue = queue
    }

    fileprivate static func == (lhs: Node, rhs: Node) -> Bool {
      return lhs.delegate === rhs.delegate
    }

    fileprivate static func == (lhs: Node, rhs: AnyObject) -> Bool {
      return lhs.delegate === rhs
    }

    fileprivate var hashValue: Int {
      guard let delegate = delegate else {
        return 0
      }
      return ObjectIdentifier(delegate).hashValue
    }
  }

}

//public protocol Delegate: class {
//  var delegateQueue: DispatchQueue? { get set }
//}
//
//public extension Delegate {
//  var delegateQueue: DispatchQueue? { return nil }
//}
//
//open class MulticastDelegate2<T> where T: Delegate {
//
//  /// The delegates hash table.
//  private let delegates: NSHashTable<AnyObject>
//
//  /// Returns `true` if there are no delegates at all, `false` if there is at least one.
//  public var isEmpty: Bool {
//    return delegates.allObjects.isEmpty
//  }
//
//  /// Returns the number of delegates.
//  public var count: Int {
//    return delegates.allObjects.count
//  }
//
//  /// Initializes a new `MulticastDelegate` specifying whether delegate references should be weak or strong.
//  ///
//  /// - Parameter usingStrongReferences: Whether delegates should be strongly referenced, false by default.
//  public init(usingStrongReferences: Bool = false) {
//    delegates = usingStrongReferences ? NSHashTable<AnyObject>() : NSHashTable<AnyObject>.weakObjects()
//  }
//
//  /// Adds a delelgate.
//  ///
//  /// - Parameter delegate: The delegate to be added.
//  public func addDelegate(_ delegate: T) {
//    validateDelegate(delegate)
//    delegates.add(delegate as AnyObject)
//  }
//
//  /// Removes a previously-added delegate.
//  ///
//  /// - Parameter delegate: The delegate to be removed.
//  public func removeDelegate(_ delegate: T) {
//    validateDelegate(delegate)
//    delegates.remove(delegate as AnyObject)
//  }
//
//  /// Removes all the previously-added delegates.
//  public func removeAllDelegates() {
//    delegates.removeAllObjects()
//  }
//
//  /// Invokes a closure on each delegate.
//  ///
//  /// - Parameter invocation: The closure to be invoked on each delegate.
//  public func invoke(invocation: @escaping (T) -> Void) {
//    delegates.allObjects.forEach { delegate in
//      // swiftlint:disable:next force_cast
//      let d = delegate as! T
//      if let queue = d.delegateQueue {
//        queue.async {
//          invocation(d)
//        }
//      } else {
//        invocation(d)
//      }
//    }
//  }
//
//  /// Returns a Boolean value that indicates whether the multicast delegate contains a given delegate.
//  ///
//  /// - Parameter delegate: The given delegate to check if it's contained
//  /// - Returns: `true` if the delegate is found or `false` otherwise
//  public func containsDelegate(_ delegate: T) -> Bool {
//    validateDelegate(delegate)
//    return delegates.contains(delegate as AnyObject)
//  }
//
//  private func validateDelegate<T>(_ delegate: T) {
//    precondition(Mirror(reflecting: delegate).subjectType is AnyClass, "The Delegate \(String(describing: delegate.self)) must be a class.")
//  }
//}
//
//public func += <T> (left: MulticastDelegate2<T>, right: T) {
//  left.addDelegate(right)
//}
//
//public func -= <T> (left: MulticastDelegate2<T>, right: T) {
//  left.removeDelegate(right)
//}

public final class MulticastDelegate3<T> {
  private var delegates = [Weak]()

  public var isEmpty: Bool {
    removeDeallocatedDelegates()
    return delegates.isEmpty
  }

  public func numberOfDelegates() -> Int {
    removeDeallocatedDelegates()
    return delegates.count
  }

  public func add(_ delegate: T, on queue: DispatchQueue = .main) {
    if Mirror(reflecting: delegate).subjectType is AnyClass {

//      guard delegates.index(of: weakValue) == nil else {
//        return
//      }
      guard !contains(delegate) else {
        return
      }

      let weakValue = Weak(value: delegate as AnyObject, queue: queue)
      delegates.append(weakValue)
    } else {
      fatalError("Multicast delegates do not support value types.")
    }
  }

  public func remove(_ delegate: T) {
    if Mirror(reflecting: delegate).subjectType is AnyClass {
      delegates.removeAll { $0 == delegate as AnyObject || $0.value == nil }
    }
  }

  public func removeAllDelegates() {
    delegates.removeAll()
  }

  public func invoke(_ invocation: @escaping (T) -> Void) {
    var indices = IndexSet()
    for (index, delegate) in delegates.enumerated() {
      let queue = delegate.queue
      if let delegate = delegate.value as? T {
        queue.async {
          invocation(delegate)
        }
      } else {
        indices.insert(index)
      }
    }

    removeObjects(atIndices: indices)
  }

  public func contains(_ delegate: T) -> Bool {
    if Mirror(reflecting: delegate).subjectType is AnyClass {
      return delegates.contains { $0 == delegate as AnyObject }
    }
    return false
  }

  private func removeDeallocatedDelegates() {
    delegates.removeAll { $0.value == nil }
  }

  private func removeObjects(atIndices indices: IndexSet) {
    let indexArray = Array(indices).sorted(by: >)
    for index in indexArray {
      delegates.remove(at: index)
    }
  }

  private final class Weak: Equatable {
    weak var value: AnyObject?
    let queue: DispatchQueue

    init(value: AnyObject, queue: DispatchQueue) {
      self.value = value
      self.queue = queue
    }

    static func == (lhs: Weak, rhs: Weak) -> Bool {
      return lhs.value === rhs.value
    }

    static func == (lhs: Weak, rhs: AnyObject) -> Bool {
      return lhs.value === rhs
    }
  }

}
