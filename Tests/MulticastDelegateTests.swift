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

private protocol DispatcherDelegate: class {
  func didDispatch()
}

private final class Listener: DispatcherDelegate {
  var didDispatch_callsCount = 0
  let closure: () -> Void
  let limit: Int
  
  init(after: Int = 0, closure: (() -> Void)? = nil) {
    self.limit = after
    self.closure = closure ?? { }
  }
  
  func didDispatch() {
    didDispatch_callsCount += 1
    if didDispatch_callsCount >= limit {
      closure()
    }
  }
}

final class MulticastDelegateTests: XCTestCase {
  
  func testThatASingleDelegateIsInvokedCorrectly() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let expectation = self.expectation(description: "\(#function)\(#line)")
    let listener = Listener(after: 1) {
      expectation.fulfill()
    }
    
    delegates.add(listener)
    delegates.invoke { $0.didDispatch() }
    
    waitForExpectations(timeout: 2)
    XCTAssertEqual(listener.didDispatch_callsCount, 1)
  }
  
  func testThatTheSameDelegateCannotBeAddedMultipleTimes() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let expectation = self.expectation(description: "\(#function)\(#line)")
    let listener = Listener(after: 1) {
      expectation.fulfill()
    }
    
    delegates.add(listener)
    delegates.add(listener)
    delegates.add(listener)
    delegates.invoke { $0.didDispatch() }
    
    waitForExpectations(timeout: 2)
    XCTAssertEqual(delegates.numberOfDelegates(), 1)
    XCTAssertEqual(listener.didDispatch_callsCount, 1)
  }
  
  func testThatMultipleDelegatesAreInvokedCorrectly() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    let listener1 = Listener(after: 1) {
      expectation1.fulfill()
    }
    
    let expectation2 = self.expectation(description: "\(#function)\(#line)")
    let listener2 = Listener(after: 1) {
      expectation2.fulfill()
    }
    
    let expectation3 = self.expectation(description: "\(#function)\(#line)")
    let listener3 = Listener(after: 1) {
      expectation3.fulfill()
    }
    
    delegates.add(listener1)
    delegates.add(listener2)
    delegates.add(listener3)
    delegates.invoke { $0.didDispatch() }
    
    waitForExpectations(timeout: 2)
    
    XCTAssertEqual(listener1.didDispatch_callsCount, 1)
    XCTAssertEqual(listener2.didDispatch_callsCount, 1)
    XCTAssertEqual(listener3.didDispatch_callsCount, 1)
  }
  
  func testThatRemovedDelegatedAreNotInvoked() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    let listener1 = Listener(after: 3) {
      expectation1.fulfill()
    }
    
    let expectation2 = self.expectation(description: "\(#function)\(#line)")
    let listener2 = Listener(after: 2) {
      expectation2.fulfill()
    }
    
    let expectation3 = self.expectation(description: "\(#function)\(#line)")
    let listener3 = Listener(after: 1) {
      expectation3.fulfill()
    }
    
    delegates.add(listener1)
    delegates.add(listener2)
    delegates.add(listener3)
    delegates.invoke { $0.didDispatch() }
    delegates.remove(listener3)
    delegates.invoke { $0.didDispatch() }
    delegates.remove(listener2)
    delegates.invoke { $0.didDispatch() }
    
    waitForExpectations(timeout: 2)
    
    XCTAssertEqual(listener1.didDispatch_callsCount, 3)
    XCTAssertEqual(listener2.didDispatch_callsCount, 2)
    XCTAssertEqual(listener3.didDispatch_callsCount, 1)
  }
  
  func testThatDelegatesAreInvokedCorrectlyOnceAddedButNotInvokedAfterDeletion() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    let listener1 = Listener(after: 1) {
      expectation1.fulfill()
    }
    
    let expectation2 = self.expectation(description: "\(#function)\(#line)")
    let listener2 = Listener(after: 1) {
      expectation2.fulfill()
    }
    
    let expectation3 = self.expectation(description: "\(#function)\(#line)")
    let listener3 = Listener(after: 1) {
      expectation3.fulfill()
    }
    
    delegates.add(listener1)
    delegates.add(listener2)
    delegates.add(listener3)
    delegates.invoke { $0.didDispatch() }
    delegates.removeAllDelegates()
    delegates.invoke { $0.didDispatch() }
    
    waitForExpectations(timeout: 2)
    
    XCTAssertEqual(listener1.didDispatch_callsCount, 1)
    XCTAssertEqual(listener2.didDispatch_callsCount, 1)
    XCTAssertEqual(listener3.didDispatch_callsCount, 1)
  }
  
  func testThatAnAutoreleasedDelegateIsNotInvoked() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    let listener1 = Listener(after: 1) {
      expectation1.fulfill()
    }
    delegates.add(listener1)
    
    let queue = DispatchQueue(label: "\(#function)")
    autoreleasepool {
      let listener2 = Listener { XCTFail("A deallocated delegate shouldn't be called.") }
      delegates.add(listener2, on: queue)
    }
    
    delegates.invoke { $0.didDispatch() }
    
    waitForExpectations(timeout: 2)
    XCTAssertEqual(listener1.didDispatch_callsCount, 1)
  }
  
  
  func testThatAWeakReferencedDelegateIsNotInvokedOnceDeallocated() {
    let expectation = self.expectation(description: "\(#function)\(#line)")
    expectation.isInverted = true
    var listener: Listener? = Listener(after: 0) { expectation.fulfill() }
    weak var weakListener = listener
    let delegates = MulticastDelegate<DispatcherDelegate>()
    let queue = DispatchQueue(label: "\(#function)")
    delegates.add(listener!, on: queue)
    listener = nil
    delegates.invoke { $0.didDispatch() }
    
    waitForExpectations(timeout: 2)
    XCTAssertNil(weakListener)
  }
  
  func testThatMultipleAutoreleasedDelegatesAreNotInvoked() {
    let delegates = MulticastDelegate<DispatcherDelegate>()
    autoreleasepool {
      (0...9).forEach { _ in
        let listener = Listener()
        delegates.add(listener)
      }
    }
    
    XCTAssertEqual(delegates.numberOfDelegates(), 0)
    XCTAssertTrue(delegates.isEmpty)
  }
  
  func testThatEachDelegateIsInvokedOnTheRightQueue() {
    let queue1 = DispatchQueue(label: "queue1")
    let queue2 = DispatchQueue(label: "queue2")
    let key = DispatchSpecificKey<Int>()
    queue1.setSpecific(key: key, value: 1)
    queue2.setSpecific(key: key, value: 2)
    
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    expectation1.isInverted = true
    let listener1 = Listener(after: 1) {
      let value = DispatchQueue.getSpecific(key: key)
      XCTAssertEqual(value, 1)
      expectation1.fulfill()
    }
    
    let expectation2 = self.expectation(description: "\(#function)\(#line)")
    expectation2.isInverted = true
    let listener2 = Listener(after: 1) {
      let value = DispatchQueue.getSpecific(key: key)
      XCTAssertEqual(value, 1)
      expectation2.fulfill()
    }
    
    let delegates = MulticastDelegate<DispatcherDelegate>()
    
    delegates.add(listener1, on: queue1)
    delegates.add(listener2, on: queue1)
    
    waitForExpectations(timeout: 2)
  }
  
}

// TODO: add tests to verify that each delegate is called on is own queue
// TODO: add tests and description regarding classes that cannot be weakened


#if os(macOS) || os(iOS)

import AVFoundation

final class NotWeakableClassesTests: XCTestCase {
  
  /// https://developer.apple.com/library/archive/releasenotes/ObjectiveC/RN-TransitioningToARC/Introduction/Introduction.html#//apple_ref/doc/uid/TP40011226
  /// https://developer.apple.com/library/archive/releasenotes/ObjectiveC/RN-TransitioningToARC/Introduction/Introduction.html
  /// Which classes don’t support weak references?
  /// You cannot currently create weak references to instances of the following classes:
  /// NSATSTypesetter, NSColorSpace, NSFont, NSMenuView, NSParagraphStyle, NSSimpleHorizontalTypesetter, and NSTextView.
  /// Note: In addition, in OS X v10.7, you cannot create weak references to instances of NSFontManager, NSFontPanel, NSImage, NSTableCellView, NSViewController, NSWindow, and NSWindowController. In addition, in OS X v10.7 no classes in the AV Foundation framework support weak references.
  func testWeakReferenceMacOS() {
    /// Failing on macOS 10.14
    
    /// macOS
    ///
    /// NSFontManager, NSFontPanel, NSTextView, NSFont do NOT support Objective-C weak references.
    /// AVFoundation
    ///
    /// iOS
    ///
    /// AVFoundation
    
    #if os(macOS)
    
    //    var fontManager: NSFontManager? = NSFontManager()
    //    weak var weakFontManager = fontManager
    //    fontManager = nil
    //    XCTAssertNil(weakFontManager)
    
    //    var fontPanel: NSFontPanel? = NSFontPanel()
    //    weak var weakFontPanel = fontPanel
    //    fontPanel = nil
    //    XCTAssertNil(weakFontPanel)
    
    //    var textView: NSTextView? = NSTextView()
    //    weak var weakTextView = textView
    //    textView = nil
    //    XCTAssertNil(weakTextView)
    
    //    var font: NSFont? =  NSFont.menuFont(ofSize: 1.0)
    //    weak var weakFont = font
    //    font = nil
    //    XCTAssertNil(weakFont)
    
    #elseif os(iOS)
    
    //    var audioSession: AVAudioSession? = AVAudioSession()
    //    weak var weakAudioSession = audioSession
    //    audioSession = nil
    //    XCTAssertNil(weakAudioSession)
    
    #endif
    
    var audioPlayer: AVAudioPlayer? = AVAudioPlayer()
    weak var weakAudioPlayer = audioPlayer
    audioPlayer = nil
    XCTAssertNil(weakAudioPlayer)
    
    var player: AVPlayer? = AVPlayer()
    weak var weakPlayer = player
    player = nil
    XCTAssertNil(weakPlayer)
    
    #if os(macOS)
    
    /// Successful on macOS 10.14
    
    var font2: NSFont? = NSFont(name: "font", size: 1.0)  // It works using NSFont(name:size:)
    weak var weakFont2 = font2
    font2 = nil
    XCTAssertNil(weakFont2)
    
    var typeSetter: NSATSTypesetter? = NSATSTypesetter()
    weak var weakTypeSetter = typeSetter
    typeSetter = nil
    XCTAssertNil(weakTypeSetter)
    
    var image: NSImage? = NSImage()
    weak var weakImage = image
    image = nil
    XCTAssertNil(weakImage)
    
    var paragraphStyle: NSParagraphStyle? = NSParagraphStyle()
    weak var weakParagraphStyle = paragraphStyle
    paragraphStyle = nil
    XCTAssertNil(weakParagraphStyle)
    
    var tableViewCell: NSTableCellView? = NSTableCellView()
    weak var weakTableViewCell = tableViewCell
    tableViewCell = nil
    XCTAssertNil(weakTableViewCell)
    
    // 10.8 supports
    
    var window: NSWindow? = NSWindow()
    weak var weakWindow = window
    window = nil
    XCTAssertNil(weakWindow)
    
    var windowController: NSWindowController? = NSWindowController()
    weak var weakWindowController = windowController
    windowController = nil
    XCTAssertNil(weakWindowController)
    
    var viewController: NSViewController? = NSViewController()
    weak var weakViewController = viewController
    viewController = nil
    XCTAssertNil(weakViewController)
    
    // 10.14 - NSColorSpace now supports Objective-C weak references.
    
    if #available(macOS 10.14, *) {
      var colorSpace: NSColorSpace? = NSColorSpace()
      weak var weakColorSpace = colorSpace
      colorSpace = nil
      XCTAssertNil(weakColorSpace)
    }
    
    #endif
  }
  
}

#endif
