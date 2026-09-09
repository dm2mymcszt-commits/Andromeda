import Foundation
import CoreLocation

@main
struct LocationSampleTests {
    static func main() {
        let coordinate = CLLocationCoordinate2D(latitude: 44.8179, longitude: -0.5544)
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let moving = RouteLocationSample.make(coordinate: coordinate, altitude: 17,
            course: 271.5, speed: 13.9, timestamp: timestamp)
        precondition(moving.coordinate.latitude == coordinate.latitude)
        precondition(moving.coordinate.longitude == coordinate.longitude)
        precondition(moving.altitude == 17 && moving.timestamp == timestamp)
        precondition(moving.speed == 13.9 && moving.speedAccuracy == 0)
        precondition(moving.course == 271.5 && moving.courseAccuracy == 0)

        let stationary = RouteLocationSample.make(coordinate: coordinate, altitude: 17,
            course: moving.course, speed: 0, timestamp: timestamp)
        precondition(stationary.speed == 0 && stationary.speedAccuracy == 0)
        precondition(stationary.course == moving.course && stationary.courseAccuracy < 0)

        let unknown = RouteLocationSample.make(coordinate: coordinate, altitude: 17,
            course: .nan, speed: .infinity, timestamp: timestamp)
        precondition(unknown.speed < 0 && unknown.speedAccuracy < 0)
        precondition(unknown.course < 0 && unknown.courseAccuracy < 0)

        let legacy = CLLocation(coordinate: coordinate, altitude: 17,
            horizontalAccuracy: 5, verticalAccuracy: 5,
            course: 271.5, speed: 13.9, timestamp: timestamp)
        // Record the framework's legacy defaults without assuming an undocumented
        // value, so the build log separates measured behavior from our hypothesis.
        print("Legacy initializer: speedAccuracy=\(legacy.speedAccuracy), courseAccuracy=\(legacy.courseAccuracy)")
        print("PASS: route location motion validity, exact simulated values, stationary direction, invalid inputs")
    }
}
