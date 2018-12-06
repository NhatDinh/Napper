//
//  AppDelegate.swift
//  Napper
//
//  Created by nd on 11/30/17.
//  Copyright © 2017 nd. All rights reserved.
//


import UIKit
import CoreLocation


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  
  var window: UIWindow?
  let locationManager = CLLocationManager()
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
    locationManager.delegate = self
    locationManager.requestAlwaysAuthorization()
    //prompts the user for permission to enable notifications for this app. Inaddition, clear out all notifications
    application.registerUserNotificationSettings(UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil))
    UIApplication.shared.cancelAllLocalNotifications()
    return true
  }
  
  //alert
  func handleEvent(forRegion region: CLRegion!) {
    // Show an alert if application is active
    if UIApplication.shared.applicationState == .active {
      guard let message = note(fromRegionIdentifier: region.identifier) else { return }
      window?.rootViewController?.showAlert(withTitle: nil, message: message)
    } else {
      // Otherwise present a local notification
      let notification = UILocalNotification()
      notification.alertBody = note(fromRegionIdentifier: region.identifier)
      notification.soundName = "Default"
      UIApplication.shared.presentLocalNotificationNow(notification)
    }
  }
}

extension AppDelegate: CLLocationManagerDelegate {
  //***
  //when device enter a CLregion, fire a statement
  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    if region is CLCircularRegion {
      handleEvent(forRegion: region)
    }
  }
  
  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    if region is CLCircularRegion {
      handleEvent(forRegion: region)
    }
  }
  func note(fromRegionIdentifier identifier: String) -> String? {
    let savedItems = UserDefaults.standard.array(forKey: PreferencesKeys.savedItems) as? [NSData]
    let geotifications = savedItems?.map { NSKeyedUnarchiver.unarchiveObject(with: $0 as Data) as? Geotification }
    let index = geotifications?.index { $0?.identifier == identifier }
    return index != nil ? geotifications?[index!]?.note : nil
  }
}




