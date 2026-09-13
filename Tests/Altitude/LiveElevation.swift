import Foundation
import CoreLocation

@main struct LiveElevation {
    static func main() async {
        let coordinate = CLLocationCoordinate2D(latitude: 44.817059, longitude: -0.585746)
        guard let meters = await ElevationLookup.fetch(coordinate), (-10...150).contains(meters) else {
            fatalError("Worldwide elevation endpoint did not return plausible terrain at the Talence fixture")
        }
        print("PASS: live WGS-84 terrain lookup, \(meters) m")
    }
}
