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

final class EventBusTests: XCTestCase {
  
  // MARK: - Add/Remove subscriptions
  
  func testThatRegistrationAreUnique() {
    let eventBus = EventBus(label: "\(#function)")
    eventBus.register(forEvent: FooMockable.self)
    eventBus.register(forEvent: FooMockable.self)
    eventBus.register(forEvent: BarMockable.self)
    XCTAssertEqual(eventBus.registeredEventTypes.count, 2)
    eventBus.register(forEvent: FooStubable.self)
    XCTAssertEqual(eventBus.registeredEventTypes.count, 3)
  }
  
  func testThatAddingSubscriptionsDoesNotChangeRegistrations() {
    let eventBus = EventBus(label: "\(#function)")
    let foo1 = FooMock()
    let foo2 = FooMock()
    eventBus.add(subscriber: foo1, for: FooMockable.self, queue: .main)
    eventBus.add(subscriber: foo2, for: FooMockable.self, queue: .main)
    
    XCTAssertEqual(eventBus.subscribedEventTypes.count, 1)
    XCTAssertTrue(eventBus.registeredEventTypes.isEmpty)
    XCTAssertEqual(eventBus.subscribers(for: FooMockable.self).count, 2)
  }
  
  func testThatAnEventBusCanBeQueriedToSeeIfItContainOneSubscriberForAnEvent() {
    let eventBus = EventBus(label: "\(#function)")
    let foo1 = FooBarMock()
    let foo2 = FooBarMock()
    eventBus.add(subscriber: foo1, for: FooMockable.self, queue: .main)
    eventBus.add(subscriber: foo2, for: BarMockable.self, queue: .main)
    
    XCTAssertEqual(eventBus.__subscribersCount(for: FooMockable.self), 1)
    XCTAssertEqual(eventBus.__subscribersCount(for: BarMockable.self), 1)
    
    XCTAssertTrue(eventBus.hasSubscriber(foo1, for: FooMockable.self))
    XCTAssertFalse(eventBus.hasSubscriber(foo2, for: FooMockable.self))
    
    XCTAssertFalse(eventBus.hasSubscriber(foo1, for: BarMockable.self))
    XCTAssertTrue(eventBus.hasSubscriber(foo2, for: BarMockable.self))
    
    XCTAssertEqual(eventBus.subscribedEventTypes.count, 2)
    XCTAssertTrue(eventBus.registeredEventTypes.isEmpty)
    
    XCTAssertEqual(eventBus.subscribers(for: FooMockable.self).count, 1)
    XCTAssertEqual(eventBus.subscribers(for: BarMockable.self).count, 1)
    
    XCTAssertTrue(eventBus.subscribers(for: FooMockable.self).first! === foo1)
    XCTAssertTrue(eventBus.subscribers(for: BarMockable.self).first! === foo2)
  }
  
  func testThatAddingAndRemovingSubscriptionsCorrectlyUpdatesSubscribedEventUpdates() {
    let eventBus = EventBus(label: "\(#function)")
    let foo1 = FooBarMock()
    let foo2 = FooBarMock()
    
    eventBus.add(subscriber: foo1, for: FooMockable.self, queue: .main)
    eventBus.add(subscriber: foo1, for: BarMockable.self, queue: .main)
    eventBus.add(subscriber: foo2, for: FooMockable.self, queue: .main)
    
    XCTAssertEqual(eventBus.subscribedEventTypes.count, 2)
    XCTAssertEqual(eventBus.subscribers(for: FooMockable.self).count, 2)
    XCTAssertEqual(eventBus.subscribers(for: BarMockable.self).count, 1)
    
    eventBus.remove(subscriber: foo2, for: BarMockable.self) // foo2 is not subscribed for BarMockable
    
    XCTAssertEqual(eventBus.subscribedEventTypes.count, 2)
    XCTAssertEqual(eventBus.subscribers(for: FooMockable.self).count, 2)
    XCTAssertEqual(eventBus.subscribers(for: BarMockable.self).count, 1)
    
    eventBus.remove(subscriber: foo1, for: FooMockable.self)
    eventBus.remove(subscriber: foo1, for: BarMockable.self)
    
    XCTAssertEqual(eventBus.subscribedEventTypes.count, 1)
    XCTAssertEqual(eventBus.subscribers(for: FooMockable.self).count, 1)
    XCTAssertEqual(eventBus.subscribers(for: BarMockable.self).count, 0)
    
    eventBus.remove(subscriber: foo2, for: FooMockable.self)
    
    XCTAssertTrue(eventBus.subscribedEventTypes.isEmpty)
    XCTAssertTrue(eventBus.subscribers(for: FooMockable.self).isEmpty)
    XCTAssertTrue(eventBus.subscribers(for: BarMockable.self).isEmpty)
  }
  
  func testThatASubscriberCanBeRemovedFromAllItsSubscriptionAltogether() {
    let eventBus = EventBus(label: "\(#function)")
    let foo1 = FooBarMock()
    eventBus.add(subscriber: foo1, for: FooMockable.self, queue: .main)
    eventBus.add(subscriber: foo1, for: BarMockable.self, queue: .main)
    eventBus.remove(subscriber: foo1)
    XCTAssertTrue(eventBus.subscribers(for: FooMockable.self).isEmpty)
    XCTAssertTrue(eventBus.subscribers(for: BarMockable.self).isEmpty)
  }
  
  func testThatAllTheSubscribersCanBeRemovedAltogether() {
    let eventBus = EventBus(label: "\(#function)")
    let foo1 = FooBarMock()
    let foo2 = FooBarMock()
    let foo3 = FooBarMock()
    let foo4 = FooBarMock()
    let foo5 = FooBarMock()
    
    eventBus.add(subscriber: foo1, for: FooMockable.self, queue: .main)
    eventBus.add(subscriber: foo1, for: BarMockable.self, queue: .main)
    eventBus.add(subscriber: foo2, for: FooMockable.self, queue: .main)
    eventBus.add(subscriber: foo2, for: BarMockable.self, queue: .main)
    eventBus.add(subscriber: foo3, for: FooMockable.self, queue: .main)
    eventBus.add(subscriber: foo3, for: BarMockable.self, queue: .main)
    eventBus.add(subscriber: foo4, for: FooMockable.self, queue: .main)
    eventBus.add(subscriber: foo4, for: BarMockable.self, queue: .main)
    eventBus.add(subscriber: foo5, for: FooMockable.self, queue: .main)
    eventBus.add(subscriber: foo5, for: BarMockable.self, queue: .main)
    eventBus.clear()
    
    XCTAssertTrue(eventBus.subscribedEventTypes.isEmpty)
    XCTAssertTrue(eventBus.subscribers(for: FooMockable.self).isEmpty)
    XCTAssertTrue(eventBus.subscribers(for: BarMockable.self).isEmpty)
  }
  
  // MARK: - Event notification to subscriptions
  
  func testThatNotificationIsSentToTheMainThread() {
    let expectation = self.expectation(description: "\(#function)\(#line)")
    let eventBus = EventBus(label: "\(#function)")
    let foo1 = FooBarMock { event in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual(event, .foo)
      expectation.fulfill()
    }
    eventBus.add(subscriber: foo1, for: FooMockable.self, queue: .main)
    let status = eventBus.notify(FooMockable.self) { $0.foo() }
    
    waitForExpectations(timeout: 2)
    XCTAssertEqual(status, 1)
  }
  
  func testThatNotificationIsSentToTheRightQueue() {
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    let expectation2 = self.expectation(description: "\(#function)\(#line)")
    let queue1 = DispatchQueue(label: "queue1")
    let queue2 = DispatchQueue(label: "queue2")
    let key = DispatchSpecificKey<Int>()
    queue1.setSpecific(key: key, value: 1)
    queue2.setSpecific(key: key, value: 2)
    
    let eventBus = EventBus(label: "\(#function)")
    
    let foo1 = FooBarMock { event in
      XCTAssertFalse(Thread.isMainThread)
      XCTAssertEqual(event, .foo)
      let value = DispatchQueue.getSpecific(key: key)
      XCTAssertEqual(value, 1)
      expectation1.fulfill()
    }
    
    let foo2 = FooBarMock { event in
      XCTAssertFalse(Thread.isMainThread)
      XCTAssertEqual(event, .foo)
      let value = DispatchQueue.getSpecific(key: key)
      XCTAssertEqual(value, 2)
      expectation2.fulfill()
    }
    
    eventBus.add(subscriber: foo1, for: FooMockable.self, queue: queue1)
    eventBus.add(subscriber: foo2, for: FooMockable.self, queue: queue2)
    let status = eventBus.notify(FooMockable.self) { $0.foo() }
    
    waitForExpectations(timeout: 2)
    XCTAssertEqual(status, 2)
  }
  
  func testThatSubscriptionIsRemovedOnceTheCancellationTokenIsUsed() {
    let eventBus = EventBus(label: "\(#function)")
    var foo: FooMock? = FooMock()
    weak var weakFoo = foo
    let token = eventBus.add(subscriber: weakFoo!, for: FooMockable.self, queue: .main)
    foo = nil
    XCTAssertNil(foo)
    XCTAssertNil(weakFoo)
    XCTAssertTrue(eventBus.subscribers(for: FooMockable.self).isEmpty)
    XCTAssertEqual(eventBus.__subscribersCount(for: FooMockable.self), 1) // the subscriber has been deallocated BUT the subscription is still stored.
    
    token.cancel(completion: nil)
    XCTAssertEqual(eventBus.__subscribersCount(for: FooMockable.self), 0)
  }
  
  func testThatSubscriptionsAreRemovedDuringTheEventBusLifeCycleIfTheirAssociatedSubscribersGetDeallocated() {
    let eventBus = EventBus(label: "\(#function)")
    do {
      let foo: FooMock = FooMock()
      eventBus.add(subscriber: foo, for: FooMockable.self, queue: .main)
      XCTAssertEqual(eventBus.subscribers(for: FooMockable.self).count, 1)
      XCTAssertTrue(eventBus.subscribers(for: FooMockable.self).first! === foo)
    }
    
    XCTAssertTrue(eventBus.subscribers(for: FooMockable.self).isEmpty)
    XCTAssertEqual(eventBus.__subscribersCount(for: FooMockable.self), 1) // // the subscriber has been deallocated BUT the subscription is still stored.
    
    do {
      let foo: FooMock = FooMock()
      let token = eventBus.add(subscriber: foo, for: FooMockable.self, queue: .main)
      XCTAssertEqual(eventBus.subscribers(for: FooMockable.self).count, 1)
      XCTAssertTrue(eventBus.subscribers(for: FooMockable.self).first! === foo)
      token.cancel(completion: nil) // a cancel command removes both the subscriber and all the previous deallocated subscribers
    }
    
    XCTAssertTrue(eventBus.subscribers(for: FooMockable.self).isEmpty)
    XCTAssertEqual(eventBus.__subscribersCount(for: FooMockable.self), 0)
  }
  
  func testThatADeallocatedSubscriberDoesNotReceiveEvents() {
    let eventBus = EventBus(label: "\(#function)")
    let expectation = self.expectation(description: "\(#function)\(#line)")
    let unfulfilledExpectation = self.expectation(description: "\(#function)\(#line)")
    unfulfilledExpectation.isInverted = true
    eventBus.register(forEvent: FooMockable.self)
    do {
      let foo: FooMock = FooMock { event in
        unfulfilledExpectation.fulfill()
      }
      eventBus.add(subscriber: foo, for: FooMockable.self, queue: .main)
      XCTAssertEqual(eventBus.subscribers(for: FooMockable.self).count, 1)
      XCTAssertTrue(eventBus.subscribers(for: FooMockable.self).first! === foo)
    }
    
    eventBus.notify(FooMockable.self, completion: { expectation.fulfill() }) { $0.foo() }
    
    waitForExpectations(timeout: 2)
    XCTAssertTrue(eventBus.subscribers(for: FooMockable.self).isEmpty)
    XCTAssertEqual(eventBus.__subscribersCount(for: FooMockable.self), 0)
  }
  
  func testThatNotificationsAreSentAsynchronously() {
    let expectation1 = expectation(description: "\(#function)\(#line)")
    let expectation2 = expectation(description: "\(#function)\(#line)")
    let expectation3 = expectation(description: "\(#function)\(#line)")
    let expectation4 = expectation(description: "\(#function)\(#line)")
    
    let eventBus = EventBus(label: "\(#function)")
    let foo1 = FooBarMock { event in
      sleep(2)
      expectation1.fulfill()
    }
    
    let foo2 = FooBarMock { event in
      sleep(2)
      expectation2.fulfill()
    }
    
    let foo3 = FooBarMock { event in
      sleep(2)
      expectation3.fulfill()
    }
    
    let foo4 = FooBarMock { event in
      sleep(2)
      expectation4.fulfill()
    }
    
    eventBus.add(subscriber: foo1, for: FooMockable.self, queue: .global())
    eventBus.add(subscriber: foo2, for: FooMockable.self, queue: .global())
    eventBus.add(subscriber: foo3, for: FooMockable.self, queue: .global())
    eventBus.add(subscriber: foo4, for: FooMockable.self, queue: .global())
    
    let status = eventBus.notify(FooMockable.self) { $0.foo() }
    
    waitForExpectations(timeout: 3) // the execution is concurrent, the timeout should be less than the sum of each closure
    XCTAssertEqual(status, 4)
  }
  
  func testThatAnEventIsNotifiedOnlyToRelatedSubscribers() {
    let expectation = self.expectation(description: "\(#function)\(#line)")
    let fooMock = FooMock { _ in expectation.fulfill() }
    let eventBus = EventBus()
    
    eventBus.add(subscriber: fooMock, for: FooMockable.self, queue: .main)
    eventBus.notify(FooMockable.self) { subscriber in
      subscriber.foo()
    }
    
    waitForExpectations(timeout: 1.0)
  }
  
  func testThatTheRightEventIsNotifiedToRelatedSubscribers() {
    let expectation = self.expectation(description: "\(#function)\(#line)")
    
    let fooBarMock = FooBarMock { event in
      switch event {
      case .foo: expectation.fulfill()
      case _: XCTFail("Should not have called `BarMockable` on subscriber")
      }
    }
    
    let eventBus = EventBus()
    eventBus.add(subscriber: fooBarMock, for: FooMockable.self, queue: .global())
    eventBus.notify(FooMockable.self) { subscriber in
      subscriber.foo()
    }
    
    self.waitForExpectations(timeout: 1.0)
  }
  
  func testThatAnEventIsNotNotifiedToUnrelatedSubscribers() {
    let expectation = self.expectation(description: "\(#function)\(#line)")
    expectation.isInverted = true
    let fooMock = FooMock { _ in expectation.fulfill() }
    let eventBus = EventBus()
    
    eventBus.add(subscriber: fooMock, for: FooMockable.self, queue: .main)
    eventBus.notify(BarMockable.self) { subscriber in
      subscriber.bar()
    }
    
    waitForExpectations(timeout: 1.0)
  }
  
  // MARK: - Chained EventBus
  
  func testThatAnEventIsPropagatedToAnAttachedEventBusEvenIfTheAttachingEvenBusDoesNotHaveAnySubscriberToThatEvent() {
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    
    let fooMock1 = FooMock { _ in
      expectation1.fulfill()
    }
    let eventBus1 = EventBus()
    let eventBus2 = EventBus()
    eventBus2.add(subscriber: fooMock1, for: FooMockable.self, queue: .main)
    eventBus1.add(subscriber: eventBus2, for: FooMockable.self)
    eventBus1.notify(FooMockable.self) { subscriber in
      subscriber.foo()
    }
    
    waitForExpectations(timeout: 1.0)
  }
  
  func testThatARemovedAttachedEventBusCannotReceiveEvents() {
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    let expectation2 = self.expectation(description: "\(#function)\(#line)")
    expectation1.isInverted = true

    let fooMock1 = FooMock { _ in expectation1.fulfill() }
    let eventBus1 = EventBus()
    let eventBus2 = EventBus()

    eventBus1.add(subscriber: eventBus2, for: FooMockable.self)
    eventBus2.add(subscriber: fooMock1, for: FooMockable.self, queue: .main)

    XCTAssertEqual(eventBus1.subscribers(for: FooMockable.self).count, 1)
    XCTAssertTrue(eventBus1.hasSubscriber(eventBus2, for: FooMockable.self))
    
    eventBus1.remove(subscriber: eventBus2)
    XCTAssertEqual(eventBus1.subscribers(for: FooMockable.self).count, 0)
    XCTAssertFalse(eventBus1.hasSubscriber(eventBus2, for: FooMockable.self))

    eventBus1.notify(FooMockable.self, completion: { expectation2.fulfill() }, closure: { $0.foo() })

    waitForExpectations(timeout: 1.0)
  }
  
  func testThatAnEventPropagatesCorrectlyToAChainedEventBus() {
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    let expectation2 = self.expectation(description: "\(#function)\(#line)")
    let fooMock1 = FooMock { _ in
      XCTAssertTrue(Thread.isMainThread)
      expectation1.fulfill()
    }
    let fooMock2 = FooMock { _ in
      XCTAssertTrue(Thread.isMainThread)
      expectation2.fulfill()
    }
    let eventBus1 = EventBus()
    let eventBus2 = EventBus()
    
    eventBus1.add(subscriber: fooMock1, for: FooMockable.self, queue: .main)
    eventBus2.add(subscriber: fooMock2, for: FooMockable.self, queue: .main)
    eventBus1.add(subscriber: eventBus2, for: FooMockable.self)
    
    eventBus1.notify(FooMockable.self) { subscriber in
      subscriber.foo()
    }
    
    waitForExpectations(timeout: 1.0)
  }
  
  func testThatAnEventDoesNotPropagateIfTheChainedEventBusHasBeenCancelled() {
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    let expectation2 = self.expectation(description: "\(#function)\(#line)")
    expectation2.isInverted = true
    let fooMock1 = FooMock { _ in expectation1.fulfill() }
    let fooMock2 = FooMock { _ in expectation2.fulfill() }
    let eventBus1 = EventBus()
    let eventBus2 = EventBus()
    
    eventBus1.add(subscriber: fooMock1, for: FooMockable.self, queue: .main)
    eventBus2.add(subscriber: fooMock2, for: FooMockable.self, queue: .main)
    let token = eventBus1.add(subscriber: eventBus2, for: FooMockable.self)
    token.cancel(completion: nil)
    eventBus1.notify(FooMockable.self) { subscriber in
      subscriber.foo()
    }
    
    waitForExpectations(timeout: 1.0)
  }
  
  
  func testThatAnEventDoesNotPropagateIfTheChainedEventBusGetsDeallocated() {
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    let expectation2 = self.expectation(description: "\(#function)\(#line)")
    expectation2.isInverted = true
    let fooMock1 = FooMock { _ in expectation1.fulfill() }
    let fooMock2 = FooMock { _ in expectation2.fulfill() }
    
    let eventBus1 = EventBus()
    eventBus1.add(subscriber: fooMock1, for: FooMockable.self, queue: .main)
    
    var eventBus2: EventBus? = EventBus()
    eventBus2!.add(subscriber: fooMock2, for: FooMockable.self, queue: .main)
    eventBus1.add(subscriber: eventBus2!, for: FooMockable.self)
    eventBus2 = nil
    
    eventBus1.notify(FooMockable.self) { subscriber in
      subscriber.foo()
    }
    
    waitForExpectations(timeout: 1.0)
  }
  
  func testThatAnEventPropagatesCorrectlyToMultiLevelChildrenEventBus() {
    let eventBus1 = EventBus(label: "eventBus1")
    let eventBus2 = EventBus(label: "eventBus2")
    let eventBus3 = EventBus(label: "eventBus3")
    let eventBus4 = EventBus(label: "eventBus4")
    
    /// EventBus 1
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    let expectation2 = self.expectation(description: "\(#function)\(#line)")
    let fooMock1 = FooMock { _ in expectation1.fulfill() }
    let fooMock2 = FooMock { _ in expectation2.fulfill() }
    
    eventBus1.add(subscriber: fooMock1, for: FooMockable.self, queue: .global())
    eventBus1.add(subscriber: fooMock2, for: FooMockable.self, queue: .main)
    //TODO: when attaching an eventbus check is its subscribers are different from the other eventbus ??
    
    /// EventBus 2
    let expectation3 = self.expectation(description: "\(#function)\(#line)")
    let expectation4 = self.expectation(description: "\(#function)\(#line)")
    let barMock1 = BarMock { _ in expectation3.fulfill() }
    let barMock2 = BarMock { _ in expectation4.fulfill() }
    eventBus2.add(subscriber: barMock1, for: BarMockable.self, queue: .main)
    eventBus2.add(subscriber: barMock2, for: BarMockable.self, queue: .global())
    
    /// EventBus 3
    let expectation5 = self.expectation(description: "\(#function)\(#line)")
    let expectation6 = self.expectation(description: "\(#function)\(#line)")
    let fooBarMock1 = FooBarMock { _ in expectation5.fulfill() }
    let fooBarMock2 = FooBarMock { _ in expectation6.fulfill() }
    
    eventBus3.add(subscriber: fooBarMock1, for: FooMockable.self, queue: .global())
    eventBus3.add(subscriber: fooBarMock2, for: BarMockable.self, queue: .main)
    
    /// EventBus 4
    let expectation7 = self.expectation(description: "\(#function)\(#line)")
    let fooBarMock3 = FooBarMock { _ in expectation7.fulfill() }
    eventBus4.add(subscriber: fooBarMock3, for: BarMockable.self, queue: .main)
    
    
    eventBus1.add(subscriber: eventBus2, for: BarMockable.self)
    eventBus1.add(subscriber: eventBus3, for: FooMockable.self)
    eventBus1.add(subscriber: eventBus3, for: BarMockable.self)
    
    eventBus2.add(subscriber: eventBus4, for: BarMockable.self)
    
    eventBus1.notify(BarMockable.self, completion: nil) { $0.bar() }
    eventBus1.notify(FooMockable.self, completion: nil) { $0.foo() }
    
    waitForExpectations(timeout: 3, handler: nil)
  }
  
  func testThatAnEventCannotBePropagatedFromAChildEventUpToItsFather() {
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    expectation1.isInverted = true
    let expectation2 = self.expectation(description: "\(#function)\(#line)")
    let eventBus1 = EventBus(label: "eventBus1")
    let eventBus2 = EventBus(label: "eventBus2")
    
    let barMock1 = BarMock { _ in expectation1.fulfill() }
    let barMock2 = BarMock { _ in expectation2.fulfill() }
    
    eventBus1.add(subscriber: barMock1, for: BarMockable.self, queue: .main)
    eventBus2.add(subscriber: barMock2, for: BarMockable.self, queue: .global())
    eventBus1.add(subscriber: eventBus2, for: BarMockable.self)
    
    eventBus2.notify(BarMockable.self, completion: nil) { $0.bar() }
    waitForExpectations(timeout: 2, handler: nil)
  }
  
  func testThatAllTheEventsAreNotifiedCorrecltyIfSentConcurrentlyFromDifferentQueues() {
    let expectation1 = self.expectation(description: "\(#function)\(#line)")
    let expectation2 = self.expectation(description: "\(#function)\(#line)")
    let eventBus1 = EventBus(label: "eventBus1")
    let eventBus2 = EventBus(label: "eventBus2")
    let iterations = 20
    
    var count1 = 0
    let foo1 = FooMock { _ in
      count1 += 1
      if count1 >= iterations {
        expectation1.fulfill()
      }
    }
    
    var count2 = 0
    let foo2 = FooMock { _ in
      count2 += 1
      if count2 >= iterations * 2 {
        expectation2.fulfill()
      }
    }
    
    eventBus1.add(subscriber: foo1, for: FooMockable.self, queue: .main)
    eventBus2.add(subscriber: foo2, for: FooMockable.self, queue: .main)
    
    eventBus1.add(subscriber: eventBus2, for: FooMockable.self)
    
    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      eventBus1.notify(FooMockable.self) { $0.foo() }
      eventBus2.notify(FooMockable.self) { $0.foo() }
    }
    waitForExpectations(timeout: 2, handler: nil)
  }
  
}

// MARK: - Mocks and Stubs

fileprivate protocol FooStubable {}
fileprivate protocol BarStubable {}

fileprivate class FooStub: FooStubable {}
fileprivate class BarStub: BarStubable {}
fileprivate class FooBarStub: FooStubable, BarStubable {}

enum MockEvent {
  case foo, bar
}

fileprivate protocol FooMockable { func foo() }
fileprivate protocol BarMockable { func bar() }

fileprivate class Mock {
  fileprivate let closure: (MockEvent) -> ()
  
  init(closure: ((MockEvent) -> ())? = nil) {
    self.closure = closure ?? { _ in }
  }
}

fileprivate struct InvalidFooStub: FooStubable {}

fileprivate class FooMock: Mock, FooMockable {
  func foo() { self.closure(.foo) }
}

fileprivate class BarMock: Mock, BarMockable {
  func bar() { self.closure(.bar) }
}

fileprivate class FooBarMock: Mock, FooMockable, BarMockable {
  func foo() { self.closure(.foo) }
  func bar() { self.closure(.bar) }
}

