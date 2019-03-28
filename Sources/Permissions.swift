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

// MARK: - Permission

public typealias PermissionCallback = (PermissionStatus) -> Void

public protocol Permission {
  func request(completionHandler: @escaping PermissionCallback)
  var status: PermissionStatus { get }
}

public enum PermissionStatus: String {
  case authorized = "Authorized"
  case provisional = "Provisional"
  case denied = "Denied"
  case notDetermined = "Not Determined"
  case notAvailable = "Not Available"
  case restricted = "Restricted"
}

extension PermissionStatus: CustomStringConvertible {
  public var description: String {
    return rawValue
  }
}

#if canImport(UIKit) && canImport(AVFoundation)

// MARK: - Microphone

import AVFoundation

public class MicrophonePermission: Permission {
  private let audioSession: AVAudioSession

  public init(audioSession: AVAudioSession = .sharedInstance()) {
    self.audioSession = audioSession
  }

  public var status: PermissionStatus {
    switch audioSession.recordPermission {
    case .denied: return .denied
    case .undetermined: return .notDetermined
    case .granted: return .authorized
    @unknown default:
      fatalError("not implemented")
    }
  }

  public func request(completionHandler: @escaping PermissionCallback) {
    audioSession.requestRecordPermission { (granted) in
      if granted {
        return completionHandler(.authorized)
      }
      return completionHandler(.denied)
    }
  }
}

// MARK: - Camera

public class CameraPermission: Permission {
  public init() { }

  public var status: PermissionStatus {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .notDetermined: return .notDetermined
    case .denied: return .denied
    case .restricted: return .restricted
    case .authorized: return .authorized
    @unknown default:
      fatalError("not implemented")
    }
  }

  public func request(completionHandler: @escaping PermissionCallback) {
    AVCaptureDevice.requestAccess(for: .video) { (authorized) in
      if authorized {
        return completionHandler(.authorized)
      }
      return completionHandler(.denied)
    }
  }
}

#endif

#if canImport(UserNotifications)

// MARK: - UserNotifications

import UserNotifications

@available(macOS 10.14, *)
public class UNUserNotificationPermission: Permission {
  private let notificationCenter: UNUserNotificationCenter
  public var authorizationStatus: UNAuthorizationStatus = .notDetermined

  public init(notificationCenter: UNUserNotificationCenter = .current()) {
    self.notificationCenter = notificationCenter
  }

  public var status: PermissionStatus {
    let semaphore = DispatchSemaphore(value: 0)
    var status: UNAuthorizationStatus = .notDetermined
    UNUserNotificationCenter.current().getNotificationSettings { (settings) in
      status = settings.authorizationStatus
      semaphore.signal()
    }
    _ = semaphore.wait(timeout: .distantFuture)

    switch status {
    case .notDetermined: return .notDetermined
    case .denied: return .denied
    case .authorized: return .authorized
    case .provisional: return .provisional
    @unknown default:
      fatalError("not implemented")
    }
  }

  public func request(completionHandler: @escaping PermissionCallback) {
    request(options: [.badge, .sound, .alert, .carPlay], completionHandler: completionHandler)
  }

  public func request(options: UNAuthorizationOptions = [], completionHandler: @escaping PermissionCallback) {
    notificationCenter.requestAuthorization(options: options) { (granted, error) in
      guard error == nil else {
        return completionHandler(.notDetermined)
      }

      if granted {
        return completionHandler(.authorized)
      }

      return completionHandler(.denied)
    }
  }
}

#endif

// MARK: - Contacts

import Contacts

public class ContactsPermission: Permission {
  public init() { }

  public var status: PermissionStatus {
    switch Contacts.CNContactStore.authorizationStatus(for: CNEntityType.contacts) {
    case .authorized: return .authorized
    case .denied: return .denied
    case .restricted: return .restricted
    case .notDetermined: return .notDetermined
    @unknown default:
      fatalError("not implemented")
    }
  }

  public func request(completionHandler: @escaping PermissionCallback) {
    Contacts.CNContactStore().requestAccess(for: CNEntityType.contacts, completionHandler: { granted, error in
      guard error == nil else {
        return completionHandler(.notDetermined)
      }

      if granted {
        return completionHandler(.authorized)
      }

      return completionHandler(.denied)
    })
  }
}

#if canImport(Photos)

// MARK: - Photo Library

import Photos

public class PhotoPermission: Permission {
  public init() { }

  public var status: PermissionStatus {
    let status = PHPhotoLibrary.authorizationStatus()

    switch status {
    case .authorized: return .authorized
    case .denied: return .denied
    case .restricted: return .restricted
    case .notDetermined: return .notDetermined
    @unknown default:
      fatalError("not implemented")
    }
  }

  public func request(completionHandler: @escaping PermissionCallback) {
    PHPhotoLibrary.requestAuthorization { status in
      switch status {
      case .authorized: completionHandler(.authorized)
      case .denied: completionHandler(.denied)
      case .restricted: completionHandler(.restricted)
      case .notDetermined: completionHandler(.notDetermined)
      @unknown default:
        fatalError("not implemented")
      }
    }
  }
}

#endif

#if canImport(CoreLocation)

// MARK: - Location

import CoreLocation

@available(macOS 10.14, *)
public class LocationPermission: NSObject, Permission {
  public lazy var locationManager: CLLocationManager = {
    let locationManager = CLLocationManager()
    locationManager.delegate = self
    return locationManager
  }()

  public var status: PermissionStatus {
    guard CLLocationManager.locationServicesEnabled() else { return .notDetermined }

    let status = CLLocationManager.authorizationStatus()

    switch status {
    case .authorizedAlways: return .authorized
      #if os(iOS) || os(tvOS) || os(watchOS)
    case .authorizedWhenInUse: return .authorized
      #endif
    case .denied: return .denied
    case .restricted: return .restricted
    case .notDetermined: return .notDetermined
    @unknown default:
      fatalError("not implemented")
    }
  }

  private var callback: PermissionCallback?

  public func request(completionHandler: @escaping PermissionCallback) {
    #if os(iOS) || os(tvOS) || os(watchOS)
    locationManager.requestAlwaysAuthorization()
    #else
    locationManager.requestLocation()
    #endif
    callback = completionHandler
  }

  #if os(iOS) || os(tvOS) || os(watchOS)
  public func requestWhenInUse(completionHandler: @escaping PermissionCallback) {
    locationManager.requestWhenInUseAuthorization()
    callback = completionHandler
  }
  #endif
}

@available(macOS 10.14, *)
extension LocationPermission: CLLocationManagerDelegate {
  public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    guard let callback = callback else { return }

    switch status {
    case .authorizedAlways: callback(.authorized)
      #if os(iOS) || os(tvOS) || os(watchOS)
    case .authorizedWhenInUse: callback(.authorized)
      #endif
    case .denied: callback(.denied)
    case .restricted: callback(.restricted)
    case .notDetermined: callback(.notDetermined)
    @unknown default:
      fatalError("not implemented")
    }
  }
}

#endif

#if canImport(Calendar)

// MARK: - Calendar

import EventKit

public class CalendarPermission: Permission {
  public init() { }

  public var status: PermissionStatus {
    let status = EKEventStore.authorizationStatus(for: .event)

    switch status {
    case .authorized: return .authorized
    case .denied: return .denied
    case .restricted: return .restricted
    case .notDetermined: return .notDetermined
    }
  }

  public func request(completionHandler: @escaping PermissionCallback) {
    EKEventStore().requestAccess(to: .event) { granted, error in
      completionHandler(error == nil ? (granted ? .authorized : .denied) : .notDetermined)
    }
  }
}

#endif

// MARK: - Bluetooth

#if canImport(CoreBluetooth)

import CoreBluetooth

public class BluetoothPermission: Permission {
  public init() { }

  public var status: PermissionStatus {
    let status = CBPeripheralManager.authorizationStatus()

    switch status {
    case .authorized: return .authorized
    case .denied: return .denied
    case .restricted: return .restricted
    case .notDetermined: return .notDetermined
    @unknown default:
      fatalError("not implemented")
    }
  }

  public func request(completionHandler: @escaping PermissionCallback) {
    fatalError("not implemented")
  }
}

#endif

#if canImport(LocalAuthentication)

// MARK: - Biometry

import LocalAuthentication

public class BiometryPermission: Permission {
  public init() { }

  public var status: PermissionStatus {
    var error: NSError?
    let status = LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

    switch status {
    case true: return .authorized
    case false: return .denied
    }
  }

  public func request(completionHandler: @escaping PermissionCallback) {
    LAContext().evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "TODO_PROVIDE_REASON") { (granted, error) in
      completionHandler(error == nil ? (granted ? .authorized : .denied) : .notDetermined)
    }
  }
}

#endif

// MARK: - Health

#if canImport(HealthKit)

import HealthKit

public class HealthPermission: Permission {
  public init() { }

  public var status: PermissionStatus {
    let status = HKHealthStore.isHealthDataAvailable()

    switch status {
    case true: return .authorized
    case false: return .denied
    }
  }

  public func request(completionHandler: @escaping PermissionCallback) {
    HKHealthStore().requestAuthorization(toShare: [], read: []) { (granted, error) in
      completionHandler(error == nil ? (granted ? .authorized : .denied) : .notDetermined)
    }
  }
}

#endif
