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

import XCTest
@testable import Bits

import AVFoundation

private protocol DispatcherDelegate: class {
  func didDispatch()
}

private class Listener: DispatcherDelegate {
  var didDispatch_callsCount = 0

  func didDispatch() {
    didDispatch_callsCount += 1
  }
}

private class ExpectationListener: DispatcherDelegate {
  var failIfCalled = false

  func didDispatch() {
    if failIfCalled {
      XCTFail("The delegate shouldn't be called.")
    }
  }
}

final class MulticastDelegateTests: XCTestCase {

  func testCallingSingleDelegate() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let listener = Listener()

    delegates.addDelegate(listener)
    delegates.invoke { $0.didDispatch() }

    XCTAssertEqual(listener.didDispatch_callsCount, 1)
  }

  func testAddingTheSameDelegateMultipleTimes() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let listener1 = Listener()

    delegates.addDelegate(listener1)
    delegates.addDelegate(listener1)
    delegates.addDelegate(listener1)
    delegates.invoke { $0.didDispatch() }

    XCTAssertEqual(delegates.count, 1)
    XCTAssertEqual(listener1.didDispatch_callsCount, 1)
  }

  func testAddingDelegates() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let listener1 = Listener()
    let listener2 = Listener()
    let listener3 = Listener()

    delegates.addDelegate(listener1)
    delegates.addDelegate(listener2)
    delegates.addDelegate(listener3)
    delegates.invoke { $0.didDispatch() }

    XCTAssertEqual(listener1.didDispatch_callsCount, 1)
    XCTAssertEqual(listener2.didDispatch_callsCount, 1)
    XCTAssertEqual(listener3.didDispatch_callsCount, 1)
  }

  func testRemovingDelegates() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let listener1 = Listener()
    let listener2 = Listener()
    let listener3 = Listener()

    delegates.addDelegate(listener1)
    delegates.addDelegate(listener2)
    delegates.addDelegate(listener3)
    delegates.invoke { $0.didDispatch() }
    delegates.removeDelegate(listener3)
    delegates.invoke { $0.didDispatch() }
    delegates.removeDelegate(listener2)
    delegates.invoke { $0.didDispatch() }

    XCTAssertEqual(listener1.didDispatch_callsCount, 3)
    XCTAssertEqual(listener2.didDispatch_callsCount, 2)
    XCTAssertEqual(listener3.didDispatch_callsCount, 1)
  }

  func testRemovingAllDelegates() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let listener1 = Listener()
    let listener2 = Listener()
    let listener3 = Listener()

    delegates.addDelegate(listener1)
    delegates.addDelegate(listener2)
    delegates.addDelegate(listener3)
    delegates.invoke { $0.didDispatch() }
    delegates.removeAllDelegates()
    delegates.invoke { $0.didDispatch() }

    XCTAssertEqual(listener1.didDispatch_callsCount, 1)
    XCTAssertEqual(listener2.didDispatch_callsCount, 1)
    XCTAssertEqual(listener3.didDispatch_callsCount, 1)
  }

  func testKeepingWeakReferences() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let listener1 = Listener()
    delegates.addDelegate(listener1)

    autoreleasepool {
      let listener2 = Listener()
      delegates.addDelegate(listener2)
    }

    var numberOfCallsMade = 0
    delegates.invoke { _ in numberOfCallsMade += 1 }

    XCTAssertEqual(numberOfCallsMade, 1)
  }

  func testOperators() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let listener1 = Listener() as DispatcherDelegate
    let listener2 = Listener() as DispatcherDelegate
    let listener3 = Listener() as DispatcherDelegate
    delegates += listener1
    delegates += listener2
    delegates += listener3

    XCTAssertEqual(delegates.count, 3)
    XCTAssertTrue(delegates.containsDelegate(listener1))
    XCTAssertTrue(delegates.containsDelegate(listener2))
    XCTAssertTrue(delegates.containsDelegate(listener3))

    delegates -= listener1
    delegates -= listener2
    delegates -= listener3

    XCTAssertEqual(delegates.count, 0)
    XCTAssertFalse(delegates.containsDelegate(listener1))
    XCTAssertFalse(delegates.containsDelegate(listener2))
    XCTAssertFalse(delegates.containsDelegate(listener3))
  }

  func testWeakReference() {
    var listener: ExpectationListener? = ExpectationListener()
    listener?.failIfCalled = true
    weak var weakListener = listener
    let delegates = MulticastDelegate<DispatcherDelegate>()
    delegates.addDelegate(weakListener!)
    listener = nil
    delegates.invoke { $0.didDispatch() }
  }

  func testWeakReferences() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    autoreleasepool {
      (0...9).forEach { _ in
        let listener = Listener()
        delegates.addDelegate(listener)
      }
    }

    XCTAssertTrue(delegates.isEmpty)
  }

  func testStrongReferences() {
    let delegates = MulticastDelegate<DispatcherDelegate>(usingStrongReferences: true)
    autoreleasepool {
      (0...9).forEach { _ in
        let listener = Listener()
        delegates.addDelegate(listener)
      }
    }

    XCTAssertEqual(delegates.count, 10)
  }

//  #if os(macOS)
//
//  //import AVFoundation
//  /// https://developer.apple.com/library/archive/releasenotes/ObjectiveC/RN-TransitioningToARC/Introduction/Introduction.html#//apple_ref/doc/uid/TP40011226
//  /// https://developer.apple.com/library/archive/releasenotes/ObjectiveC/RN-TransitioningToARC/Introduction/Introduction.html
//  /// Which classes don’t support weak references?
//  /// You cannot currently create weak references to instances of the following classes:
//  /// NSATSTypesetter, NSColorSpace, NSFont, NSMenuView, NSParagraphStyle, NSSimpleHorizontalTypesetter, and NSTextView.
//  /// Note: In addition, in OS X v10.7, you cannot create weak references to instances of NSFontManager, NSFontPanel, NSImage, NSTableCellView, NSViewController, NSWindow, and NSWindowController. In addition, in OS X v10.7 no classes in the AV Foundation framework support weak references.
//  func testWeakReferenceMacOS() {
//    /// Failing
//
//    /// As of macOS 10.14
//    /// NSFontManager, NSFontPanel, NSTextView, NSFont do NOT support Objective-C weak references.
//
////    var fontManager: NSFontManager? = NSFontManager()
////    weak var weakFontManager = fontManager
////    fontManager = nil
////    XCTAssertNil(weakFontManager)
//
////    var fontPanel: NSFontPanel? = NSFontPanel()
////    weak var weakFontPanel = fontPanel
////    fontPanel = nil
////    XCTAssertNil(weakFontPanel)
//
////    var textView: NSTextView? = NSTextView()
////    weak var weakTextView = textView
////    textView = nil
////    XCTAssertNil(weakTextView)
//
////    var font: NSFont? =  NSFont.menuFont(ofSize: 1.0)
////    weak var weakFont = font
////    font = nil
////    XCTAssertNil(weakFont)
//
////    var audioSession: AVAudioSession? = AVAudioSession()
////    weak var weakAudioSession = audioSession
////    audioSession = nil
////    XCTAssertNil(weakAudioSession)
//
//    var audioPlayer: AVAudioPlayer? = AVAudioPlayer()
//    weak var weakAudioPlayer = audioPlayer
//    audioPlayer = nil
//    XCTAssertNil(weakAudioPlayer)
//
//    var player: AVPlayer? = AVPlayer()
//    weak var weakPlayer = player
//    player = nil
//    XCTAssertNil(weakPlayer)
//
//    /// Successful
//
//    // It works using NSFont(name:size:)
//    var font2: NSFont? = NSFont(name: "font", size: 1.0)
//    weak var weakFont2 = font2
//    font2 = nil
//    XCTAssertNil(weakFont2)
//
//    var typeSetter: NSATSTypesetter? = NSATSTypesetter()
//    weak var weakTypeSetter = typeSetter
//    typeSetter = nil
//    XCTAssertNil(weakTypeSetter)
//
//    var image: NSImage? = NSImage()
//    weak var weakImage = image
//    image = nil
//    XCTAssertNil(weakImage)
//
//    var paragraphStyle: NSParagraphStyle? = NSParagraphStyle()
//    weak var weakParagraphStyle = paragraphStyle
//    paragraphStyle = nil
//    XCTAssertNil(weakParagraphStyle)
//
//    var tableViewCell: NSTableCellView? = NSTableCellView()
//    weak var weakTableViewCell = tableViewCell
//    tableViewCell = nil
//    XCTAssertNil(weakTableViewCell)
//
//    // 10.8 supports
//
//    var window: NSWindow? = NSWindow()
//    weak var weakWindow = window
//    window = nil
//    XCTAssertNil(weakWindow)
//
//    var windowController: NSWindowController? = NSWindowController()
//    weak var weakWindowController = windowController
//    windowController = nil
//    XCTAssertNil(weakWindowController)
//
//    var viewController: NSViewController? = NSViewController()
//    weak var weakViewController = viewController
//    viewController = nil
//    XCTAssertNil(weakViewController)
//
//    // 10.14 - NSColorSpace now supports Objective-C weak references.
//    var colorSpace: NSColorSpace? = NSColorSpace()
//    weak var weakColorSpace = colorSpace
//    colorSpace = nil
//    XCTAssertNil(weakColorSpace)
//  }
//  #endif

}
