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
  func check(completionHandler: @escaping PermissionCallback)
  func request(completionHandler: @escaping PermissionCallback)
}

public enum PermissionStatus: String {
  case authorized = "Authorized"
  case provisional = "Provisional"
  case denied = "Denied"
  case notDetermined = "Not Determined"
  case notAvailable = "Not Available"
}

extension PermissionStatus: CustomStringConvertible {

  public var description: String {
    return rawValue
  }
}

#if canImport(AVFoundation) && canImport(UIKit)

import AVFoundation

// MARK: - Microphone

public class MicrophonePermission: Permission {
  private let audioSession: AVAudioSession

  public init(audioSession: AVAudioSession = .sharedInstance()) {
    self.audioSession = audioSession
  }

  public func check(completionHandler: @escaping PermissionCallback) {
    switch audioSession.recordPermission {
    case AVAudioSession.RecordPermission.denied:
      return completionHandler(.denied)

    case AVAudioSession.RecordPermission.undetermined:
      return completionHandler(.notDetermined)

    case AVAudioSession.RecordPermission.granted:
      return completionHandler(.authorized)
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

  public func check(completionHandler: @escaping PermissionCallback) {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .notDetermined:
      return completionHandler(.notDetermined)

    case .restricted, .denied:
      return completionHandler(.denied)

    case .authorized:
      return completionHandler(.authorized)
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

import UserNotifications

// MARK: - UserNotifications

@available(OSX 10.14, *)
public class UNUserNotificationPermission: Permission {
  private let notificationCenter: UNUserNotificationCenter
  public var authorizationStatus: UNAuthorizationStatus = .notDetermined

  public init(notificationCenter: UNUserNotificationCenter = .current()) {
    self.notificationCenter = notificationCenter
  }

  public func check(completionHandler: @escaping PermissionCallback) {
    notificationCenter.getNotificationSettings { (settings) in
      UNUserNotificationCenter.current().getNotificationSettings { (settings) in
        switch settings.authorizationStatus {
        case .notDetermined:
          return completionHandler(.notDetermined)

        case .denied:
          return completionHandler(.denied)

        case .authorized:
          return completionHandler(.authorized)

        case .provisional:
          completionHandler(.provisional)
        }
      }
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

import Contacts

// MARK: - Contacts

public class ContactsPermission: Permission {

  public func check(completionHandler: @escaping PermissionCallback) {
    switch Contacts.CNContactStore.authorizationStatus(for: CNEntityType.contacts) {
    case .authorized:
      return completionHandler(.authorized)
    case .denied, .restricted:
      return completionHandler(.denied)
    case .notDetermined:
      return completionHandler(.notDetermined)
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

#if canImport(UIKit)

import UIKit

// MARK: - Utils

@available(iOSApplicationExtension, unavailable)
public func unregisterForRemoteNotifications() {
  UIApplication.shared.unregisterForRemoteNotifications()
}

@available(iOSApplicationExtension, unavailable)
public func registerForRemoteNotifications() {
  UIApplication.shared.registerForRemoteNotifications()
}

@available(iOSApplicationExtension, unavailable)
public func openSettings() {
  if let appSettings = URL(string: UIApplication.openSettingsURLString) {
    UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
  }
}

#endif


