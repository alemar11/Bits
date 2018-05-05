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

// If you must check for network availability, avoid calling the SCNetworkReachabilityCreateWithAddress method. Call the SCNetworkReachabilityCreateWithName method and pass it a hostname instead.
// // swiftlint:disable:next line_length
// https://developer.apple.com/library/content/documentation/NetworkingInternetWeb/Conceptual/NetworkingOverview/UnderstandingandPreparingfortheIPv6Transition/UnderstandingandPreparingfortheIPv6Transition.html#//apple_ref/doc/uid/TP40010220-CH213-SW25

#if os(iOS) || os(tvOS) || os(macOS)

import Foundation
import SystemConfiguration

/// The `Reachability` class listens for reachability changes of hosts and addresses for both WWAN and WiFi network interfaces.
final public class Reachability {

  /// Defines the various states of network reachability.
  ///
  /// - unknown:      It is unknown whether the network is reachable.
  /// - notReachable: The network is not reachable.
  /// - reachable:    The network is reachable.
  public enum NetworkStatus {
    case unknown
    case notReachable
    case reachable(Connection)
  }

  /// Defines the various connection types detected by reachability flags.
  ///
  /// - ethernetOrWiFi: The connection type is either over Ethernet or WiFi.
  /// - wwan:           The connection type is a WWAN connection.
  public enum Connection {
    case ethernetOrWiFi
    case wwan
  }

  // MARK: - Properties

  /// Whether the network is currently reachable.
  public var isReachable: Bool { return isReachableOnWWAN || isReachableOnEthernetOrWiFi }

  /// Whether the network is currently reachable over the WWAN interface (iOS).
  public var isReachableOnWWAN: Bool { return networkStatus == .reachable(.wwan) }

  /// Whether the network is currently reachable over Ethernet or WiFi interface.
  public var isReachableOnEthernetOrWiFi: Bool { return networkStatus == .reachable(.ethernetOrWiFi) }

  /// The current network reachability status.
  public var networkStatus: NetworkStatus {
    guard let flags = self.flags else { return .unknown }
    return networkReachabilityStatusForFlags(flags)
  }

  /// A closure executed when the network reachability status changes.
  public var listener: ((Reachability.NetworkStatus) -> Void)?

  /// The underlying `SCNetworkReachability` instance.
  private let networkReachability: SCNetworkReachability

  /// The underlying serial queue.
  private let reachabilitySerialQueue = DispatchQueue(label: "org.tinrobots.Reachability.serialQueue") //TODO

  /// Whether the `Reachability' is actively notifing.
  private var notifying: Bool = false

  /// Flags that indicate the reachability of a network.
  private var flags: SCNetworkReachabilityFlags? {
    var flags = SCNetworkReachabilityFlags(rawValue: 0)

    if withUnsafeMutablePointer(to: &flags, { SCNetworkReachabilityGetFlags(networkReachability, UnsafeMutablePointer($0)) }) == true {
      return flags
    } else {
      return nil
    }
  }

  /// Flags that indicate the reachability of a network during the previous notification.
  private var previousFlags: SCNetworkReachabilityFlags?

  // MARK: - Initializers

  /// Creates a `Reachability` instance that monitors the address 0.0.0.0.
  ///
  /// Reachability treats the 0.0.0.0 address as a special token that causes it to monitor the general routing
  /// status of the device, both IPv4 and IPv6.
  ///
  /// - returns: The new `Reachability` instance.
  public convenience init?() {
    var zeroAddress = sockaddr_in()
    zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
    zeroAddress.sin_family = sa_family_t(AF_INET)
    self.init(hostAddress: zeroAddress)
  }

  /// Creates a `Reachability` instance for a specified host name.
  public convenience init?(hostName: String) {
    guard hostName.contains("://") == false else {
      assertionFailure("Reachability only wants the host: including the scheme will cause it to not work.")
      return nil
    }

    guard let reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, hostName) else { return nil }
    self.init(reachability: reachability)
  }

  /// Creates a `Reachability` instance for a specified host address.
  public convenience init?(hostAddress: sockaddr_in) {
    var address = hostAddress

    guard let defaultRouteReachability = withUnsafePointer(to: &address, {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, $0)
      }
    }) else {
      return nil
    }

    self.init(reachability: defaultRouteReachability)
  }

  private init(reachability: SCNetworkReachability) {
    self.networkReachability = reachability
    self.previousFlags = SCNetworkReachabilityFlags()
  }

  deinit {
    stopListening()
  }

  // MARK: - Notifications

  /// Starts notifing network reachability changes.
  @discardableResult
  public func startNotifier() -> Bool {

    guard !notifying else { return false }

    var context = SCNetworkReachabilityContext()
    context.info = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

    guard SCNetworkReachabilitySetCallback(networkReachability, callback, &context) == true else {
      stopListening()
      return false
    }

    guard SCNetworkReachabilitySetDispatchQueue(networkReachability, reachabilitySerialQueue) == true else {
      stopListening()
      return false }

    reachabilitySerialQueue.async {
      self.previousFlags = SCNetworkReachabilityFlags()
      self.notify(self.flags ?? SCNetworkReachabilityFlags())
    }

    notifying = true
    return notifying
  }

  /// Stops notifing network reachability changes.
  public func stopNotifier() {
    if notifying {
      stopListening()
      notifying = false
    }
  }

  fileprivate func notify(_ flags: SCNetworkReachabilityFlags) {
    guard previousFlags != flags else { return }

    self.listener?(self.networkStatus)
    previousFlags = flags
  }

  private func stopListening() {
    SCNetworkReachabilitySetCallback(networkReachability, nil, nil)
    SCNetworkReachabilitySetDispatchQueue(networkReachability, nil)
    previousFlags = nil
  }

  // MARK: - Private - Network Reachability Status

  private func networkReachabilityStatusForFlags(_ flags: SCNetworkReachabilityFlags) -> NetworkStatus {
    guard isNetworkReachable(with: flags) else { return .notReachable }

    var networkStatus: NetworkStatus = .reachable(.ethernetOrWiFi)

    #if os(iOS)
    if flags.contains(.isWWAN) { networkStatus = .reachable(.wwan) }
    #endif

    return networkStatus
  }

  private func isNetworkReachable(with flags: SCNetworkReachabilityFlags) -> Bool {
    let isReachable = flags.contains(.reachable)
    let needsConnection = flags.contains(.connectionRequired)
    let canConnectAutomatically = flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic)
    let canConnectWithoutUserInteraction = canConnectAutomatically && !flags.contains(.interventionRequired)

    return isReachable && (!needsConnection || canConnectWithoutUserInteraction)
  }

}

/// Callback used by `SCNetworkReachabilitySetCallback(target:callout:context:)
private func callback(reachability: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?) {
  if let currentInfo = info {
    let infoObject = Unmanaged<AnyObject>.fromOpaque(currentInfo).takeUnretainedValue()
    if let networkReachability = infoObject as? Reachability {
      networkReachability.notify(flags)
    }
  }
}

extension Reachability {

  /// Creates a `Reachability` instance that monitors the address 0.0.0.0.
  ///
  /// Reachability treats the 0.0.0.0 address as a special token that causes it to monitor the general routing
  /// status of the device, both IPv4 and IPv6.
  ///
  /// - returns: A new `Reachability` instance.
  public static func makeReachabilityForInternetConnection() -> Reachability? {
    var zeroAddress = sockaddr_in()
    zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
    zeroAddress.sin_family = sa_family_t(AF_INET)

    return Reachability(hostAddress: zeroAddress)
  }

  /// Creates a `Reachability` instance that monitors IN_LINKLOCALNETNUM (that is, 169.254.0.0).
  ///
  /// - returns: A new `Reachability` instance.
  ///
  /// - Note: Only apps that have a specific requirement should be monitoring IN_LINKLOCALNETNUM.
  /// For the overwhelming majority of apps, monitoring this address is unnecessary and potentially harmful.
  public static func makeReachabilityForLocalWiFi() -> Reachability? {
    var localWifiAddress = sockaddr_in()
    localWifiAddress.sin_len = UInt8(MemoryLayout.size(ofValue: localWifiAddress))
    localWifiAddress.sin_family = sa_family_t(AF_INET)
    localWifiAddress.sin_addr.s_addr = 0xA9FE0000 // IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0 (0xA9FE0000).
    return Reachability(hostAddress: localWifiAddress)
  }

}

extension Reachability.NetworkStatus: CustomStringConvertible {

  public var description: String {
    switch self {
    case .notReachable:
      return "Not reachable"
    case .unknown:
      return "Unknown"
    case .reachable(let connction):
      return connction.description
    }
  }

}

extension Reachability.NetworkStatus: Equatable {}

/// Returns whether the two network status values are equal.
///
/// - parameter lhs: The left-hand side value to compare.
/// - parameter rhs: The right-hand side value to compare.
///
/// - returns: `true` if the two values are equal, `false` otherwise.
public func == (lhs: Reachability.NetworkStatus, rhs: Reachability.NetworkStatus) -> Bool {
  switch (lhs, rhs) {
  case (.unknown, .unknown):
    return true
  case (.notReachable, .notReachable):
    return true
  case let (.reachable(lhsConnection), .reachable(rhsConnection)):
    return lhsConnection == rhsConnection
  default:
    return false
  }

}

extension Reachability.Connection: CustomStringConvertible {

  public var description: String {
    switch self {
    case .ethernetOrWiFi:
      return "Ethernet or WiFi"
    case .wwan:
      return "Cellular"
    }
  }

}

#endif
