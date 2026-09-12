import Foundation
import CoreLocation

@main
struct LiveCycling {
    static func main() async throws {
        let start = CLLocationCoordinate2D(latitude: 44.817059, longitude: -0.585746)
        let end = CLLocationCoordinate2D(latitude: 44.8378, longitude: -0.5792)
        let routes = try await BicycleDirections.shared.routes(from: start, to: end)
        precondition(!routes.isEmpty)
        for route in routes {
            precondition(route.distance > 2_000 && route.distance < 10_000)
            var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: route.polyline.pointCount)
            route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: coords.count))
            precondition(RouteSimulationMath.distance(coords.first!, start) < 150)
            precondition(RouteSimulationMath.distance(coords.last!, end) < 150)
        }
        print("PASS: live bicycle directions, valid geometry and both endpoints")
    }
}
