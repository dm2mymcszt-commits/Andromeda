import SwiftUI
import MapKit

// Separate simulator-only app using the production picker; never bundled in Andromeda.
struct EquatableCoordinate: Equatable {
    let coordinate: CLLocationCoordinate2D
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

@main struct RoutePickerPreview: App {
    private let places: RouteRecentPlaces = {
        let defaults = UserDefaults(suiteName: "RoutePickerPreview")!
        defaults.removePersistentDomain(forName: "RoutePickerPreview")
        let places = RouteRecentPlaces(defaults: defaults)
        places.remember(RoutePlace(name: "Gare de Lyon", address: "Place Louis-Armand, Paris",
                                  coordinate: CLLocationCoordinate2D(latitude: 48.8449, longitude: 2.3735)))
        places.remember(RoutePlace(name: "Jardin du Luxembourg", address: "Paris",
                                  coordinate: CLLocationCoordinate2D(latitude: 48.8462, longitude: 2.3372)))
        return places
    }()
    var body: some Scene {
        WindowGroup {
            RouteLocationPicker(title: "Destination", region: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 48.85, longitude: 2.35),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)),
                selectedCoordinate: nil, recents: places, select: { _ in })
                .preferredColorScheme(.dark)
        }
    }
}
