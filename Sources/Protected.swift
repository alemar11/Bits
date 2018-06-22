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

/// A value register to read/write with locking.
/// https://en.wikipedia.org/wiki/Readers%E2%80%93writer_lock
final public class Protected<Value> {

  /// Tansaction modes.
  ///
  /// - sync: Read/write synchronously.
  /// - async: Read/write asynchronously using barrier.
  public enum TransactionMode {
    case sync
    case async
  }

  private lazy var queue = DispatchQueue(label: "org.tinrobots.Bits", attributes: .concurrent)

  private var _value: Value

  /// Current value.
  public var value: Value {
    get {
      return queue.sync { _value }
    }
    set {
      queue.async(flags: .barrier) { [weak self] in
        self?._value = newValue
      }
    }
  }

  /// Creates a protected instance.
  ///
  /// - Parameter value: Value to wrap.
  public init(_ value: Value) {
    _value = value
  }

  /// Calls given block synchronously with the current value while locking.
  ///
  /// - Parameter block: Read block.
  public func read(_ block: (Value) -> Void) {
    queue.sync {
      block(_value)
    }
  }

  public func read() -> Value {
    return queue.sync { _value }
//    var value: Value!
//    queue.sync {
//      value = _value
//    }
//    return value
  }

  /// Calls given block with a reference (inout) to the current value while locking.
  ///
  /// - Parameters:
  ///   - mode: Write mode. `async` by default.
  ///   - block: Read/write block.
  public func write(mode: TransactionMode = .async, _ block: @escaping (inout Value) -> Void) {
    let execution: () -> Void = { [weak self] in
      guard let strongSelf = self else { return }

      block(&strongSelf._value)
    }

    switch mode {
    case .async:
      queue.async(flags: .barrier, execute: execution)
    case .sync:
      queue.sync(execute: execution)
    }
  }
}
