//
//  LocSimManager.swift
//  Andromeda
//
//  Developed by son3ra1n.
//

import Foundation
import CoreLocation

/// Creates the exact position and motion values of the simulated route model.
/// This describes Core Location data; it does not create a Core Motion activity
/// or control the activity/appearance that another app chooses to display.
enum RouteLocationSample {
    static func make(
        coordinate: CLLocationCoordinate2D,
        altitude: CLLocationDistance,
        course: CLLocationDirection,
        speed: CLLocationSpeed,
        timestamp: Date
    ) -> CLLocation {
        let validSpeed = speed.isFinite && speed >= 0
        let validCourse = course.isFinite && course >= 0 && course < 360
        return CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: validCourse ? course : -1,
            // The route model has an exact bearing while moving. At rest retain
            // the last numeric bearing, but do not describe it as a travel direction.
            courseAccuracy: validSpeed && speed > 0 && validCourse ? 0 : -1,
            speed: validSpeed ? speed : -1,
            // These are deterministic simulation values, not sensor estimates.
            // Negative accuracy means invalid to Core Location consumers.
            speedAccuracy: validSpeed ? 0 : -1,
            timestamp: timestamp
        )
    }
}

class LocSimManager {
    static let simManager = CLSimulationManager()
    
    /// Updates timezone
    static func post_required_timezone_update(){
        CFNotificationCenterPostNotificationWithOptions(CFNotificationCenterGetDarwinNotifyCenter(), .init("AutomaticTimeZoneUpdateNeeded" as CFString), nil, nil, kCFNotificationDeliverImmediately);
    }
    
    /// Starts a location simulation of specified argument "location"
    // TODO: save
    static func startLocSim(location: CLLocation) {
        simManager.stopLocationSimulation()
        simManager.clearSimulatedLocations()
        simManager.appendSimulatedLocation(location)
        simManager.flush()
        simManager.startLocationSimulation()
        post_required_timezone_update();
    }
    
    /// Stops location simulation
    static func stopLocSim(){
        simManager.stopLocationSimulation()
        simManager.clearSimulatedLocations()
        simManager.flush()
        post_required_timezone_update();
    }
}


struct EquatableCoordinate: Equatable {
    var coordinate: CLLocationCoordinate2D
    
    static func ==(lhs: EquatableCoordinate, rhs: EquatableCoordinate) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}


// https://stackoverflow.com/a/75703059

class LocationModel: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    @Published var authorisationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        self.locationManager.delegate = self
    }

    public func requestAuthorisation(always: Bool = false) {
        if always {
            self.locationManager.requestAlwaysAuthorization()
        } else {
            self.locationManager.requestWhenInUseAuthorization()
        }
    }
}

extension LocationModel: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.authorisationStatus = status
    }
}
