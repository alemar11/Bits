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
import SystemConfiguration
@testable import Bits

final class ReachabilityTests: XCTestCase {
  
  // MARK: - Tests - Initialization
  
  func testThatReachabilityCanBeInitializedWithAnHostName() {
    // Given, When
    let reachability = Reachability(hostName: "localhost")
    
    // Then
    XCTAssertNotNil(reachability)
  }
  
  func testThatReachabilityCanBeInitializedWithAddress0000() {
    // Given, When
    let reachability = Reachability()
    
    // Then
    XCTAssertNotNil(reachability)
  }
  
  func testThatReachabilityWithHostNameIsReachableOnWiFi() {
    // Given, When
    let reachability = Reachability(hostName: "localhost")
    
    // Then
    XCTAssertEqual(reachability?.networkStatus, .reachable(.ethernetOrWiFi))
    XCTAssertEqual(reachability?.isReachable, true)
    XCTAssertEqual(reachability?.isReachableOnWWAN, false)
    XCTAssertEqual(reachability?.isReachableOnEthernetOrWiFi, true)
  }
  
  func testThatReachabilityWithHostNameStartsWithReachableStatus() {
    // Given, When
    let reachability = Reachability(hostName: "localhost")
    
    // Then
    XCTAssertEqual(reachability?.networkStatus, .reachable(.ethernetOrWiFi))
    XCTAssertEqual(reachability?.isReachable, true)
    XCTAssertEqual(reachability?.isReachableOnWWAN, false)
    XCTAssertEqual(reachability?.isReachableOnEthernetOrWiFi, true)
  }
  
  func testThatReachabilityWithAddresStartsWithReachableStatus() {
    // Given, When
    let reachability = Reachability()
    
    // Then
    XCTAssertEqual(reachability?.networkStatus, .reachable(.ethernetOrWiFi))
    XCTAssertEqual(reachability?.isReachable, true)
    XCTAssertEqual(reachability?.isReachableOnWWAN, false)
    XCTAssertEqual(reachability?.isReachableOnEthernetOrWiFi, true)
  }
  
  func testThatReachabilityCanBeDeinitialized() {
    do {
      // Given
      var manager: Reachability? = Reachability(hostName: "localhost")
      
      // When
      manager = nil
      
      // Then
      XCTAssertNil(manager)
    }
    
    do {
      
      // Given
      var manager: Reachability? = Reachability()
      
      // When
      manager = nil
      
      // Then
      XCTAssertNil(manager)}
  }
  
  // MARK: - Tests - Listener
  func testThatReachabilityWithHostNameIsNotifiedWhenStartListeningIsCalled() {
    // Given
    guard let reachability = Reachability(hostName: "store.apple.com") else {
      XCTFail("reachability should NOT be nil")
      return
    }
    
    let expectation = self.expectation(description: "The closure should be executed.")
    var networkStatus: Reachability.NetworkStatus?
    
    reachability.listener = { status in
      guard networkStatus == nil else { return }
      networkStatus = status
      expectation.fulfill()
    }
    
    // When
    reachability.startNotifier()
    waitForExpectations(timeout: 30, handler: nil)
    
    // Then
    XCTAssertEqual(networkStatus, .reachable(.ethernetOrWiFi))
  }
  
  func testThatReachabilityWithAddressIsNotifiedWhenStartListeningIsCalled() {
    // Given
    let reachability = Reachability()
    let expectation = self.expectation(description: "The closure should be executed.")
    
    var networkStatus: Reachability.NetworkStatus?
    
    reachability?.listener = { status in
      networkStatus = status
      expectation.fulfill()
    }
    
    // When
    reachability?.startNotifier() //TODO better name
    waitForExpectations(timeout: 30, handler: nil)
    
    // Then
    XCTAssertEqual(networkStatus, .reachable(.ethernetOrWiFi))
  }
  
  // MARK: - Tests - Network Reachability Status
  
  func testThatReachabilityReturnsNotReachableStatusWhenReachableFlagIsAbsent() {
    // Given
    let reachability = Reachability()
    let flags: SCNetworkReachabilityFlags = [.connectionOnDemand]
    
    // When
    let networkStatus = reachability?.networkReachabilityStatusForFlags(flags)
    
    // Then
    XCTAssertEqual(networkStatus, .notReachable)
  }
  
  func testThatReachabilityReturnsNotReachableStatusWhenConnectionIsRequired() {
    // Given
    let reachability = Reachability()
    let flags: SCNetworkReachabilityFlags = [.reachable, .connectionRequired]
    
    // When
    let networkStatus = reachability?.networkReachabilityStatusForFlags(flags)
    
    // Then
    XCTAssertEqual(networkStatus, .notReachable)
  }
  
  func testThatReachabilityReturnsNotReachableStatusWhenInterventionIsRequired() {
    // Given
    let reachability = Reachability()
    let flags: SCNetworkReachabilityFlags = [.reachable, .connectionRequired, .interventionRequired]
    
    // When
    let networkStatus = reachability?.networkReachabilityStatusForFlags(flags)
    
    // Then
    XCTAssertEqual(networkStatus, .notReachable)
  }
  
  func testThatReachabilityReturnsReachableOnWiFiStatusWhenConnectionIsNotRequired() {
    // Given
    let reachability = Reachability()
    let flags: SCNetworkReachabilityFlags = [.reachable]
    
    // When
    let networkStatus = reachability?.networkReachabilityStatusForFlags(flags)
    
    // Then
    XCTAssertEqual(networkStatus, .reachable(.ethernetOrWiFi))
  }
  
  func testThatReachabilityReturnsReachableOnWiFiStatusWhenConnectionIsOnDemand() {
    // Given
    let reachability = Reachability()
    let flags: SCNetworkReachabilityFlags = [.reachable, .connectionRequired, .connectionOnDemand]
    
    // When
    let networkStatus = reachability?.networkReachabilityStatusForFlags(flags)
    
    // Then
    XCTAssertEqual(networkStatus, .reachable(.ethernetOrWiFi))
  }
  
  func testThatReachabilityReturnsReachableOnWiFiStatusWhenConnectionIsOnTraffic() {
    // Given
    let reachability = Reachability()
    let flags: SCNetworkReachabilityFlags = [.reachable, .connectionRequired, .connectionOnTraffic]
    
    // When
    let networkStatus = reachability?.networkReachabilityStatusForFlags(flags)
    
    // Then
    XCTAssertEqual(networkStatus, .reachable(.ethernetOrWiFi))
  }
  
  #if os(iOS)
  
  func testThatReachabilityReturnsReachableOnWWANStatusWhenIsWWAN() {
    // Given
    let reachability = Reachability()
    let flags: SCNetworkReachabilityFlags = [.reachable, .isWWAN]
    
    // When
    let networkStatus = reachability?.networkReachabilityStatusForFlags(flags)
    
    // Then
    XCTAssertEqual(networkStatus, .reachable(.wwan))
  }
  
  func testThatReachabilityReturnsNotReachableOnWWANStatusWhenIsWWANAndConnectionIsRequired() {
    // Given
    let reachability = Reachability()
    let flags: SCNetworkReachabilityFlags = [.reachable, .isWWAN, .connectionRequired]
    
    // When
    let networkStatus = reachability?.networkReachabilityStatusForFlags(flags)
    
    // Then
    XCTAssertEqual(networkStatus, .notReachable)
  }
  
  #endif
  
}
