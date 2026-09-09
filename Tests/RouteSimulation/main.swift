import Foundation
import CoreLocation

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
let speed = TravelMode.driving.speed * 1.5
let etas = [24_100.0, 24_300.0, 13_200.0].map {
    RouteSimulationMath.durationText(RouteSimulationMath.simulationSeconds(distance: $0, speed: speed))
}
require(Set(etas).count == 3, "Routes with different distances must have different simulated durations")
require(RouteSimulationMath.simulationSeconds(distance: 100, speed: 0) == nil, "Zero speed has no duration")
require(RouteSimulationMath.durationText(3_600) == "1h 0m", "One-hour boundary")
require(RouteSimulationMath.durationText(.nan) == "Unavailable", "Non-finite duration")
require(RouteSimulationMath.durationText(60.01) == "1m 1s", "Round remaining partial seconds up")
require(RouteSimulationMath.rankedIndices(times: [1_800, 1_200, 2_400], distances: [24_300, 24_100, 13_200]) == [1, 0, 2],
        "Fastest must follow provider ETA, not response order or shortest distance")
require(RouteSimulationMath.rankedIndices(times: [.nan, 0, 90, 90], distances: [1, 2, 20, 10]) == [3, 2, 0, 1],
        "Invalid ETA must sort last; equal ETA uses distance")
require(RouteSimulationMath.rankedIndices(times: [90, 90], distances: [10, 10]) == [0, 1], "Stable ranking tie")
print("PASS: route interpolation, short segments, duplicate vertices, exact destination, invalid inputs, date line, per-route durations, provider ETA ranking")
