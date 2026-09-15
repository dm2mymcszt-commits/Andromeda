import Foundation
import CoreLocation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
let container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
let inbox = SharedPlaceInbox(container: container)
defer { try? FileManager.default.removeItem(at: container) }
let wgs = CLLocationCoordinate2D(latitude: 39.9087, longitude: 116.3975)
let map = CoordTransform.wgs84ToGcj02(wgs)
let place = RoutePlace(name: "Shared favorite", address: "Test address", coordinate: map)
var requests: [SharedPlaceRequest] = []
for action in SharedPlaceAction.allCases {
    let request = SharedPlaceRequest(place: place, action: action)
    try inbox.enqueue(request)
    requests.append(request)
    require(abs(request.latitude - wgs.latitude) < 0.00003 && abs(request.longitude - wgs.longitude) < 0.00003, "Inbox must store WGS-84")
}
let reopened = SharedPlaceInbox(container: container)
require(reopened.pending().count == 4, "All actions survive reopening")
require(Set(reopened.pending().map(\.action)) == Set(SharedPlaceAction.allCases), "Shared actions lost")
for request in reopened.pending() {
    let converted = request.place!.coordinate
    require(abs(converted.latitude - map.latitude) < 0.00003 && abs(converted.longitude - map.longitude) < 0.00003, "Map-space round trip changed the place")
}
try reopened.remove(requests[1])
require(reopened.pending().count == 3 && !reopened.pending().contains(where: { $0.id == requests[1].id }), "Cancel removes only its own action")
try Data("malformed".utf8).write(to: inbox.directory!.appendingPathComponent("bad.json"))
require(reopened.pending().count == 3, "Malformed payload must not hide valid queued places")
let draft = RouteDraft()
draft.accept(requests[1])
draft.accept(requests[2])
require(draft.start?.name == place.name && draft.destination?.name == place.name && draft.needsRecalculation, "Separate Start and Destination shares must preserve both endpoints")
let previousStart = draft.start?.id
draft.accept(requests[0])
require(draft.start?.id == previousStart, "A Go request must not edit the route draft")
let resolvedCurrent = RoutePlace(name: "Current Location", coordinate: CLLocationCoordinate2D(latitude: 44.8, longitude: -0.6))
draft.start = resolvedCurrent
draft.destination = place
require(draft.swapEndpoints(), "Resolved endpoints can swap")
require(draft.destination?.id == resolvedCurrent.id && draft.destination?.latitude == 44.8 && draft.start?.id == place.id,
        "Swap must preserve the resolved current-location coordinates and both names")
require(draft.swapEndpoints() && draft.start?.id == resolvedCurrent.id && draft.destination?.id == place.id, "Swap twice restores endpoints")
draft.start = nil
require(!draft.swapEndpoints() && draft.destination?.id == place.id, "Unresolved current location cannot swap")
let suite = "andromeda.share.tests." + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
try SharedPlaceInbox.saveFavorite(place, defaults: defaults)
let favorites = RouteFavoritePlaces.places(from: defaults.array(forKey: "bookmarks") as! [[String: Any]])
require(favorites.count == 1 && favorites[0].name == place.name, "Shared favorite must use existing bookmark storage")
require(abs(favorites[0].latitude - map.latitude) < 0.00003 && abs(favorites[0].longitude - map.longitude) < 0.00003, "Shared favorite must convert exactly once")
print("PASS: four share actions, durable inbox, cancellation, invalid payloads, independent endpoints and WGS-84 Favorites")
for autoStart in [false, true] {
    draft.prepareFromMap(start: resolvedCurrent, destination: place, autoStart: autoStart)
    require(draft.needsRecalculation && draft.start?.id == resolvedCurrent.id && draft.destination?.id == place.id,
            "Long press must fill both Navigation endpoints")
    require(draft.takeAutomaticPreparation() == autoStart && draft.takeAutomaticPreparation() == nil,
            "Opening Navigation must calculate once, and never repeat auto-start after reopening")
}
draft.prepareFromMap(start: resolvedCurrent, destination: place, autoStart: true)
draft.accept(requests[2])
require(draft.takeAutomaticPreparation() == nil, "A later shared endpoint must invalidate earlier auto-start intent")

for (input, expected) in [
    ("https://maps.app.goo.gl/abc", SharedPlaceSource.googleMaps),
    ("Place name https://goo.gl/maps/abc", .googleMaps),
    ("https://www.google.fr/maps/place/Test", .googleMaps),
    ("https://maps.google.co.uk/?q=44,-0.6", .googleMaps),
    ("https://consent.google.com/m?continue=https%3A%2F%2Fwww.google.com%2Fmaps%2Fplace%2FTest", .googleMaps),
    ("https://maps.apple.com/?ll=44,-0.6", .appleMaps),
    ("44.8, -0.6", .text),
    ("Google Maps, a shop name", .text),
    ("https://maps.google.com.example.org/maps", .text),
    ("https://google.com/search?q=maps", .text),
    ("https://consent.google.com/m?continue=https%3A%2F%2Fexample.org", .text)
] { require(SharedPlaceSource.detect(input) == expected, "Incorrect shared source: " + input) }
var googlePlace = place
googlePlace.sharedSource = .googleMaps
let sourced = SharedPlaceRequest(place: googlePlace, action: .start)
let sourceRoundTrip = try JSONDecoder().decode(SharedPlaceRequest.self, from: JSONEncoder().encode(sourced))
require(sourceRoundTrip.sourceTitle == "From Google Maps" && sourceRoundTrip.place?.sharedSource == .googleMaps,
        "Source must survive the shared queue independently of search provider")
draft.accept(sourceRoundTrip)
require(draft.start?.sharedSource == .googleMaps, "Endpoint must retain attachment source")
draft.destination = place
require(draft.swapEndpoints() && draft.destination?.sharedSource == .googleMaps, "Source follows swapped endpoint")
var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(sourced)) as! [String: Any]
legacy.removeValue(forKey: "source")
let legacyRequest = try JSONDecoder().decode(SharedPlaceRequest.self, from: JSONSerialization.data(withJSONObject: legacy))
require(legacyRequest.place != nil && legacyRequest.sourceTitle == "Shared place", "Legacy inbox remains readable without fabricated provenance")
var oldPlace = try JSONSerialization.jsonObject(with: JSONEncoder().encode(googlePlace)) as! [String: Any]
oldPlace.removeValue(forKey: "sharedSource")
let decodedOldPlace = try JSONDecoder().decode(RoutePlace.self, from: JSONSerialization.data(withJSONObject: oldPlace))
require(decodedOldPlace.sharedSource == nil,
        "Old recents remain readable")
let recent = RouteRecentPlaces(defaults: defaults)
recent.remember(googlePlace)
require(RouteRecentPlaces(defaults: defaults).places.first?.sharedSource == .googleMaps, "Recents retain source")
print("PASS: source links/consent/host boundaries, durable provenance, endpoint swaps and legacy decoding")
