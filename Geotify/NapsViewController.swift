//
//  NapsViewController.swift
//  Napper
//
//  Created by nd on 11/30/17.
//  Copyright © 2017 nd. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

struct PreferencesKeys {
  static let savedItems = "savedItems"
}

class GeotificationsViewController: UIViewController {
  
  @IBOutlet weak var mapView: MKMapView!
  
  var geotifications: [Geotification] = []
  
  //Setting up location manager and permissions.
  let locationManager = CLLocationManager()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    //***
    // set view controller as delegate of locationManager to receive the relevant delegate methods call
    locationManager.delegate = self
    // promt user a request for app to always acess to user location, this type of app, like uber 
    locationManager.requestAlwaysAuthorization()
    // save list of geos to geos array, also loads geo as annotations on the map view
    loadAllGeotifications()
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "addGeotification" {
      let navigationController = segue.destination as! UINavigationController
      let vc = navigationController.viewControllers.first as! AddGeotificationViewController
      vc.delegate = self
    }
  }
  
  //***
  //A method to dertermine if device support geofence like fuctionalies or not
  func startMonitoring(geotification: Geotification) {
    //Display error message if device is determined to not work
    if !CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
      showAlert(withTitle:"Error", message: "Napper will not work on this device!")
      return
    }
    // Check authorizationStatus if app has been granted permission to use userLocation
    if CLLocationManager.authorizationStatus() != .authorizedAlways {
      showAlert(withTitle:"Warning", message: "Your geotification is saved but will only be activated once you grant Napper permission to access the device location.")
    }
    //
    let region = self.region(withGeotification: geotification)
    // register CLCircularRegion with core location for monitoring
    locationManager.startMonitoring(for: region)
  }
  
  //***
  //A method to stop monitoring
  func stopMonitoring(geotification: Geotification) {
    for region in locationManager.monitoredRegions {
      guard let circularRegion = region as? CLCircularRegion, circularRegion.identifier == geotification.identifier else { continue }
      locationManager.stopMonitoring(for: circularRegion)
    }
  }
  
  //***
  //Registering Your Geofences
  func region(withGeotification geotification: Geotification) -> CLCircularRegion {
    // init CLCircularRegion with geofence location, the radius, identier: allow IOS to distiguish registered geofences of an app
    let region = CLCircularRegion(center: geotification.coordinate, radius: geotification.radius, identifier: geotification.identifier)
    // CLCircularRegion has two boolean properties .notifyOnEntry and .notifyOnExit
    //
    region.notifyOnEntry = (geotification.eventType == .onEntry)
    region.notifyOnExit = !region.notifyOnEntry
    return region
  }

  
  // MARK: Loading and saving functions
  func loadAllGeotifications() {
    geotifications = []
    guard let savedItems = UserDefaults.standard.array(forKey: PreferencesKeys.savedItems) else { return }
    for savedItem in savedItems {
      guard let geotification = NSKeyedUnarchiver.unarchiveObject(with: savedItem as! Data) as? Geotification else { continue }
      add(geotification: geotification)
    }
  }
  
  func saveAllGeotifications() {
    var items: [Data] = []
    for geotification in geotifications {
      let item = NSKeyedArchiver.archivedData(withRootObject: geotification)
      items.append(item)
    }
    UserDefaults.standard.set(items, forKey: PreferencesKeys.savedItems)
  }
  
  // MARK: Functions that update the model/associated views with geotification changes
  func add(geotification: Geotification) {
    geotifications.append(geotification)
    mapView.addAnnotation(geotification)
    addRadiusOverlay(forGeotification: geotification)
    updateGeotificationsCount()
  }
  
  func remove(geotification: Geotification) {
    if let indexInArray = geotifications.index(of: geotification) {
      geotifications.remove(at: indexInArray)
    }
    mapView.removeAnnotation(geotification)
    removeRadiusOverlay(forGeotification: geotification)
    updateGeotificationsCount()
  }
  
  func updateGeotificationsCount() {
    title = "Nap counts (\(geotifications.count))"
    //limit the number of geotifications user can set, disables the Add button in the navigation bar whenever the app reaches the limit.
    navigationItem.rightBarButtonItem?.isEnabled = (geotifications.count < 20)
  }
  
  // MARK: Map overlay functions
  func addRadiusOverlay(forGeotification geotification: Geotification) {
    mapView?.add(MKCircle(center: geotification.coordinate, radius: geotification.radius))
  }
  
  func removeRadiusOverlay(forGeotification geotification: Geotification) {
    // Find exactly one overlay which has the same coordinates & radius to remove
    guard let overlays = mapView?.overlays else { return }
    for overlay in overlays {
      guard let circleOverlay = overlay as? MKCircle else { continue }
      let coord = circleOverlay.coordinate
      if coord.latitude == geotification.coordinate.latitude && coord.longitude == geotification.coordinate.longitude && circleOverlay.radius == geotification.radius {
        mapView?.remove(circleOverlay)
        break
      }
    }

    
  }
  // MARK: Other mapview functions
  @IBAction func zoomToCurrentLocation(sender: AnyObject) {
    mapView.zoomToUserLocation()
  }
  
}

// MARK: AddGeotificationViewControllerDelegate
extension GeotificationsViewController: AddGeotificationsViewControllerDelegate {
  
  func addGeotificationViewController(controller: AddGeotificationViewController, didAddCoordinate coordinate: CLLocationCoordinate2D, radius: Double, identifier: String, note: String, eventType: EventType) {
    controller.dismiss(animated: true, completion: nil)
    // 1
    let clampedRadius = min(radius, locationManager.maximumRegionMonitoringDistance)
    let geotification = Geotification(coordinate: coordinate, radius: clampedRadius, identifier: identifier, note: note, eventType: eventType)
    add(geotification: geotification)
    // 2
    startMonitoring(geotification: geotification)
    saveAllGeotifications()
  }
}
//***
// extension of CLLocationManagerDelegate
//this methods will get user current location after user hit "allow" when prompted
extension GeotificationsViewController: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    mapView.showsUserLocation = (status == .authorizedAlways)
  }
  func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
    print("Monitoring failed for region with identifier: \(region!.identifier)")
  }
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("Location Manager failed with the following error: \(error)")
  }
}

// MARK: - MapView Delegate
extension GeotificationsViewController: MKMapViewDelegate {
  
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    let identifier = "myGeotification"
    if annotation is Geotification {
      var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView
      if annotationView == nil {
        annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        annotationView?.canShowCallout = true
        let removeButton = UIButton(type: .custom)
        removeButton.frame = CGRect(x: 0, y: 0, width: 23, height: 23)
        removeButton.setImage(UIImage(named: "DeleteGeotification")!, for: .normal)
        annotationView?.leftCalloutAccessoryView = removeButton
      } else {
        annotationView?.annotation = annotation
      }
      return annotationView
    }
    return nil
  }
  
  
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    if overlay is MKCircle {
      let circleRenderer = MKCircleRenderer(overlay: overlay)
      circleRenderer.lineWidth = 1.0
      circleRenderer.strokeColor = .purple
      circleRenderer.fillColor = UIColor.purple.withAlphaComponent(0.4)
      return circleRenderer
    }
    return MKOverlayRenderer(overlay: overlay)
  }
  
  func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
    // Delete geotification
    let geotification = view.annotation as! Geotification
    stopMonitoring(geotification: geotification)
    remove(geotification: geotification)
    saveAllGeotifications()
  }
  
}

