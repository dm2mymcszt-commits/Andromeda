import Foundation
import MapKit

let suite = "RoutePickerTests.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let store = RouteRecentPlaces(defaults: defaults)
assert(store.places.isEmpty)
for index in 0..<15 {
    store.remember(RoutePlace(name: "Place \(index)", coordinate:
        CLLocationCoordinate2D(latitude: 48 + Double(index) * 0.001, longitude: 2)))
}
assert(store.places.count == 12 && store.places.first?.name == "Place 14")
store.remember(RoutePlace(name: "Renamed place", coordinate: store.places[3].coordinate))
assert(store.places.count == 12 && store.places.first?.name == "Renamed place")
let restored = RouteRecentPlaces(defaults: defaults)
assert(restored.places.map(\.id) == store.places.map(\.id))
restored.remove(restored.places[0])
assert(RouteRecentPlaces(defaults: defaults).places.count == 11)
restored.remember(RoutePlace(name: "Invalid", coordinate: CLLocationCoordinate2D(latitude: 100, longitude: 2)))
assert(restored.places.count == 11)
defaults.set(Data("broken data".utf8), forKey: "routeRecentPlaces.v1")
assert(RouteRecentPlaces(defaults: defaults).places.isEmpty)
print("PASS: recent-place limit, ordering, deduplication, persistence, removal, invalid coordinates, corrupt data")
