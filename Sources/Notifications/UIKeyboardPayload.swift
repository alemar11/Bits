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

#if canImport(UIKit) && os(iOS)

import UIKit

extension Notification {
  /// **Bits**
  ///
  /// UIKeyboard Notification Payload.
  public struct UIKeyboardPayload: NotificationPayload {
    /// Identifies whether the keyboard belongs to the current app.
    public let isLocal: Bool

    /// Identifies the start frame of the keyboard in screen coordinates.
    public let startFrame: CGRect

    /// Identifies the end frame of the keyboard in screen coordinates.
    public let endFrame: CGRect

    /// Defines how the keyboard will be animated onto or off the screen.
    public let animationCurve: UIView.AnimationCurve

    /// Identifies the duration of the keyboard animation in seconds.
    public let animationDuration: TimeInterval

    public init?(userInfo: [AnyHashable: Any]) {
      if
        let isLocal = userInfo[UIResponder.keyboardIsLocalUserInfoKey] as? Bool,
        let startFrame = userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? CGRect,
        let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
        let rawAnimationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UIView.AnimationCurve.RawValue,
        let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval
      {
        self.isLocal = isLocal
        self.startFrame = startFrame
        self.endFrame = endFrame
        self.animationCurve = UIView.AnimationCurve(rawValue: rawAnimationCurve)!
        self.animationDuration = animationDuration
      } else {
        return nil
      }
    }

    public init?(notification: Notification) {
      guard let userInfo = notification.userInfo else { return nil }

      self.init(userInfo: userInfo)
    }
  }
}

extension Notification.UIKeyboardPayload {
  public var userInfo: [AnyHashable: Any] {
    var userInfo = [AnyHashable: Any]()

    userInfo[UIResponder.keyboardIsLocalUserInfoKey] = isLocal
    userInfo[UIResponder.keyboardFrameBeginUserInfoKey] = startFrame
    userInfo[UIResponder.keyboardFrameEndUserInfoKey] = endFrame
    userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] = animationCurve.rawValue
    userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] = animationDuration

    return userInfo
  }
}

#endif
