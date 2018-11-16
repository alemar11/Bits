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

#if canImport(UIKit)
import UIKit
typealias Responder = UIResponder

#elseif canImport(AppKit)
import AppKit

typealias Responder = NSResponder

extension Responder {
  /// The next responder after this one, or nil if it has none.
  var next : NSResponder? {
    set {
      nextResponder = newValue
    }
    get {
      return nextResponder
    }
  }
}
#endif

public protocol ResponderAction {
  associatedtype Responder
  func execute(responder: Responder)
}

public extension Responder {

  @discardableResult
  public func execute<A: ResponderAction>(action: A) -> A.Responder? {
    if let responder = find(action: action) {
      action.execute(responder: responder)
      return responder
    }
    return nil
  }

  public func find<A: ResponderAction>(action: A) -> A.Responder? {
    var responder: Responder? = self
    while responder != nil {
      if let responder = responder as? A.Responder {
        return responder
      }
      responder = responder?.next
    }
    return nil
  }

}
