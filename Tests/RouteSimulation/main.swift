import Foundation
import CoreLocation
import MapKit

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

func coordinate(_ metersEast: Double) -> CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: 0, longitude: metersEast / 111_319.49079327358)
}

func near(_ lhs: Double, _ rhs: Double, tolerance: Double = 0.005) -> Bool {
    abs(lhs - rhs) <= tolerance
}

// A normal route can contain many vertices shorter than one simulation step.
// Their residual distance must carry across every vertex, including duplicates.
let shortSegments = (0...100).map { coordinate(Double($0)) }
let length = RouteSimulationMath.distance(shortSegments[0], shortSegments[100])
let samples = RouteSimulationMath.interpolate(coords: shortSegments, speed: length / 10, interval: 1)
require(samples.count == 11, "Ten seconds of travel must contain a start and ten updates")
for index in samples.indices {
    require(near(RouteSimulationMath.distance(samples[0], samples[index]), length * Double(index) / 10),
            "Residual distance must survive short segments")
}
let withDuplicates = [coordinate(0), coordinate(0), coordinate(3), coordinate(3), coordinate(7), coordinate(100)]
let duplicateSamples = RouteSimulationMath.interpolate(coords: withDuplicates, speed: length / 10, interval: 1)
require(duplicateSamples.count == samples.count, "Zero-length segments must not consume time")
for index in samples.indices {
    require(near(RouteSimulationMath.distance(samples[index], duplicateSamples[index]), 0),
            "Duplicate vertices changed the sampled route")
}

let partialEnd = RouteSimulationMath.interpolate(coords: [coordinate(0), coordinate(95)], speed: length / 10, interval: 1)
require(partialEnd.count == 11, "Keep one partial final step")
require(near(RouteSimulationMath.distance(partialEnd.last!, coordinate(95)), 0), "Destination must be exact")
require(RouteSimulationMath.interpolate(coords: [], speed: 10, interval: 1).isEmpty, "Empty route")
require(RouteSimulationMath.interpolate(coords: [coordinate(0)], speed: 10, interval: 1).count == 1, "One-point route")
for invalid in [0.0, -1, Double.nan, Double.infinity] {
    require(RouteSimulationMath.interpolate(coords: shortSegments, speed: invalid, interval: 1).isEmpty, "Invalid speed must not loop")
    require(RouteSimulationMath.interpolate(coords: shortSegments, speed: 10, interval: invalid).isEmpty, "Invalid interval must not loop")
}
let invalidCoordinate = CLLocationCoordinate2D(latitude: 91, longitude: 0)
require(RouteSimulationMath.interpolate(coords: [coordinate(0), invalidCoordinate], speed: 10, interval: 1).isEmpty,
        "Invalid route coordinates must be rejected")

// A route crossing 180 degrees must stay near the date line, not traverse longitude 0.
let dateLine = [CLLocationCoordinate2D(latitude: 0, longitude: 179.999),
                CLLocationCoordinate2D(latitude: 0, longitude: -179.999)]
let crossing = RouteSimulationMath.interpolate(coords: dateLine,
    speed: RouteSimulationMath.distance(dateLine[0], dateLine[1]) / 4, interval: 1)
require(crossing.count == 5, "Date-line step count")
require(crossing.allSatisfy { abs($0.longitude) > 179.99 }, "Date-line interpolation took the long way")

// The simulated duration belongs to each route; provider traffic ETA remains separate.
let speed = 75.0 / 3.6
let etas = [24_100.0, 24_300.0, 13_200.0].map {
    RouteSimulationMath.durationText(RouteSimulationMath.simulationSeconds(distance: $0, speed: speed))
}
require(Set(etas).count == 3, "Routes with different distances must have different simulated durations")
require(RouteSimulationMath.simulationSeconds(distance: 100, speed: 0) == nil, "Zero speed has no duration")
require(RouteSimulationMath.durationText(3_600) == "1h 0m", "One-hour boundary")
require(RouteSimulationMath.durationText(.nan) == "Unavailable", "Non-finite duration")
require(RouteSimulationMath.durationText(60.01) == "1m 1s", "Round remaining partial seconds up")
require(RouteSimulationMath.rankedIndices(distances: [24_300, 24_100, 13_200]) == [2, 1, 0],
        "Fastest must follow simulated duration: shortest at the same speed")
require(RouteSimulationMath.rankedIndices(distances: [.nan, 0, 20, 10]) == [3, 2, 0, 1], "Invalid distance must sort last")
require(RouteSimulationMath.rankedIndices(distances: [10, 10]) == [0, 1], "Stable ranking tie")
require(RouteSimulationMath.durationText(RouteSimulationMath.simulationSeconds(distance: 7_900, speed: 500 / 3.6)) == "57s", "7.9 km at 500 km/h must show 57 seconds")
require(RouteSimulationMath.durationText(RouteSimulationMath.simulationSeconds(distance: 7_500, speed: 500 / 3.6)) == "54s", "7.5 km is faster than 7.9 km")
print("PASS: route interpolation, short segments, duplicate vertices, exact destination, invalid inputs, date line, per-route durations, simulation-speed ranking")

let suiteName = "Andromeda.RouteSpeeds.Tests.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suiteName)!
defer { defaults.removePersistentDomain(forName: suiteName) }
var speeds = RouteSpeeds(defaults: defaults)
require(speeds[.walking] == 5 && speeds[.cycling] == 20 && speeds[.driving] == 50, "Exact default km/h for each mode")
for mode in TravelMode.allCases {
    speeds.set(1, for: mode)
    require(RouteSpeeds(defaults: defaults)[mode] == 1, "Persist minimum speed in every mode")
    speeds.set(500, for: mode)
    require(RouteSpeeds(defaults: defaults)[mode] == 500, "Persist maximum speed in every mode")
}
speeds.set(7, for: .walking)
speeds.set(26, for: .cycling)
speeds.set(120, for: .driving)
let restored = RouteSpeeds(defaults: defaults)
require(restored[.walking] == 7 && restored[.cycling] == 26 && restored[.driving] == 120, "Mode speeds must remain independent across launches")
speeds.set(.nan, for: .walking)
require(speeds[.walking] == 7, "Reject non-finite speed")
require(TravelMode.cycling.appleTransportType == nil, "Cycling must not request walking directions")

func path(_ distance: Double, offset: Double = 0) -> RoutePath {
    let coords = [coordinate(offset), coordinate(offset + distance)]
    return RoutePath(polyline: MKPolyline(coordinates: coords, count: coords.count), distance: distance,
                     expectedTravelTime: distance / 10, name: "Fixture")
}
var cache = RouteModeCache()
cache.store([path(7_900), path(7_500)], for: .driving)
cache.store([path(6_000, offset: 100), path(5_000, offset: 100)], for: .cycling)
cache.store([path(4_000, offset: 200)], for: .walking)
let original = cache.routes[.driving]![0].route.polyline
require(cache.duration(for: .driving, kmh: 500) == "54s", "Mode tab shows shortest simulated time")
cache.select(1, for: .driving)
cache.select(1, for: .cycling)
require(cache.selections[.driving] == 1 && cache.selections[.cycling] == 1, "Mode switches preserve independent alternative selections")
require(cache.routes[.driving]![0].route.polyline === original, "Switching mode must reuse cached geometry")
require(cache.duration(for: .driving, kmh: 250) == "1m 48s", "Speed changes update mode duration without replacing routes")
cache = RouteModeCache()
require(cache.routes.isEmpty && cache.selections.isEmpty, "Changing endpoints clears every mode")

let bicycleJSON = #"{"code":"Ok","routes":[{"geometry":{"coordinates":[[-0.585746,44.817059],[-0.59,44.82]]},"distance":720,"duration":150,"legs":[{"summary":"Cycleway"}]}]}"#.data(using: .utf8)!
let bicycle = try! BicycleDirections.decode(bicycleJSON)[0]
require(bicycle.distance == 720 && bicycle.name == "Cycleway", "Decode bicycle distance and road name")
require(bicycle.polyline.pointCount == 2 && near(bicycle.polyline.coordinate.latitude, 44.817059, tolerance: 0.01), "Decode GeoJSON longitude/latitude order")
do {
    _ = try BicycleDirections.decode(Data(#"{"code":"NoRoute"}"#.utf8))
    fatalError("NoRoute must be reported, not replaced by walking")
} catch {}
print("PASS: per-mode speed persistence/range, independent route cache, bicycle provider decoding")
