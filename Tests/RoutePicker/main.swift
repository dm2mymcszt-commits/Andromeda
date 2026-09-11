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

// The isolated test executable reads/writes the exact suite and functions used
// by FavoritesView. Preserve anything pre-existing on the CI host.
let bookmarkDefaults = UserDefaults(suiteName: sharedUserDefaultsSuiteName)!
let savedBookmarks = bookmarkDefaults.object(forKey: "bookmarks")
defer {
    if let saved = savedBookmarks { bookmarkDefaults.set(saved, forKey: "bookmarks") }
    else { bookmarkDefaults.removeObject(forKey: "bookmarks") }
}
bookmarkDefaults.removeObject(forKey: "bookmarks")
assert(RouteFavoritePlaces.places(from: BookMarkRetrieve()).isEmpty)
assert(BookMarkSave(lat: 44.817059, long: -0.585746, name: "Café préféré"))
assert(BookMarkSave(lat: 39.9087, long: 116.3975, name: "Beijing"))
let favorites = RouteFavoritePlaces.places(from: BookMarkRetrieve())
assert(favorites.map(\.name) == ["Café préféré", "Beijing"])
assert(favorites[0].latitude == 44.817059 && favorites[0].longitude == -0.585746)
let china = favorites[1].coordinate
assert(abs(china.longitude - 116.3975) > 0.001, "Chinese favorites must enter map space")
let injected = CoordTransform.gcj02ToWgs84(china)
assert(CLLocation(latitude: injected.latitude, longitude: injected.longitude).distance(
    from: CLLocation(latitude: 39.9087, longitude: 116.3975)) < 3,
    "Picker selection must return to the original WGS-84 position when injected")
assert(RouteFavoritePlaces.matching(favorites, query: "  ").count == 2)
assert(RouteFavoritePlaces.matching(favorites, query: " CAFE ").first?.name == "Café préféré")
assert(RouteFavoritePlaces.matching(favorites, query: "beij").first?.name == "Beijing")
assert(RouteFavoritePlaces.matching(favorites, query: "44.817").isEmpty, "Filter by name, not coordinates")
let malformed: [[String: Any]] = [
    ["name": "Invalid", "lat": 91.0, "long": 0.0], ["name": "Missing"],
    ["name": " ", "lat": 0.0, "long": 0.0]
]
assert(RouteFavoritePlaces.places(from: malformed).map(\.name) == ["Favorite"])
assert(BookMarkSave(lat: 48.85, long: 2.35, name: "Added later"))
assert(RouteFavoritePlaces.places(from: BookMarkRetrieve()).last?.name == "Added later")
assert((BookMarkRetrieve()[1]["long"] as? Double) == 116.3975, "Reading must never rewrite saved coordinates")
print("PASS: shared favorites storage; fresh reload; name/accent filtering; invalid entries; WGS-84 and China selection round trip")
