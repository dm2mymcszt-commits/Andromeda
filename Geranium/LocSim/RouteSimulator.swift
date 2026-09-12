//
//  RouteSimulator.swift
//  Andromeda
//
//  Route simulation - moves location along a real route with background support
//

import Foundation
import CoreLocation
import MapKit
import UIKit
import Combine

enum RouteSimulationMath {
    static func distance(_ from: CLLocationCoordinate2D, _ to: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
    }

    static func simulationSeconds(distance: Double, speed: Double) -> TimeInterval? {
        guard distance.isFinite, distance >= 0, speed.isFinite, speed > 0 else { return nil }
        return distance / speed
    }

    static func durationText(_ seconds: TimeInterval?) -> String {
        guard let seconds = seconds, seconds.isFinite, seconds >= 0,
              seconds < Double(Int.max) else { return "Unavailable" }
        let rounded = Int(ceil(seconds))
        if rounded < 60 { return "\(rounded)s" }
        let minutes = rounded / 60
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m \(rounded % 60)s"
    }

    // Every alternative uses the same simulation speed, so shortest is fastest.
    static func rankedIndices(distances: [Double]) -> [Int] {
        return distances.indices.sorted { lhs, rhs in
            let lhsDistance = distances[lhs].isFinite && distances[lhs] > 0 ? distances[lhs] : .infinity
            let rhsDistance = distances[rhs].isFinite && distances[rhs] > 0 ? distances[rhs] : .infinity
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
            return lhs < rhs
        }
    }

    static func interpolate(coords: [CLLocationCoordinate2D], speed: Double, interval: TimeInterval) -> [CLLocationCoordinate2D] {
        let stepDistance = speed * interval
        guard speed.isFinite, speed > 0, interval.isFinite, interval > 0,
              stepDistance.isFinite, stepDistance > 0,
              coords.allSatisfy({ CLLocationCoordinate2DIsValid($0) }) else { return [] }
        guard coords.count >= 2 else { return coords }
        var result = [coords[0]]
        var distanceUntilNextSample = stepDistance

        for index in 1..<coords.count {
            let from = coords[index - 1]
            let to = coords[index]
            let segmentDistance = distance(from, to)
            guard segmentDistance > 0 else { continue }
            var covered = 0.0
            while distanceUntilNextSample <= segmentDistance - covered {
                covered += distanceUntilNextSample
                let fraction = covered / segmentDistance
                // Take the short direction if a route crosses the date line.
                let longitudeDelta = (to.longitude - from.longitude + 540)
                    .truncatingRemainder(dividingBy: 360) - 180
                let longitude = (from.longitude + longitudeDelta * fraction + 540)
                    .truncatingRemainder(dividingBy: 360) - 180
                result.append(CLLocationCoordinate2D(
                    latitude: from.latitude + (to.latitude - from.latitude) * fraction,
                    longitude: longitude))
                distanceUntilNextSample = stepDistance
            }
            distanceUntilNextSample -= segmentDistance - covered
        }
        // Avoid a duplicate destination (and a spurious extra second) at exact step boundaries.
        if let last = coords.last, let sampledLast = result.last {
            if distance(sampledLast, last) > 0.001 {
                result.append(last)
            } else {
                result[result.count - 1] = last
            }
        }
        return result
    }
}

enum TravelMode: String, CaseIterable {
    case walking = "Walking"
    case cycling = "Cycling"
    case driving = "Driving"
    
    var defaultSpeedKmh: Double {
        switch self {
        case .walking: return 5
        case .cycling: return 20
        case .driving: return 50
        }
    }
    
    var icon: String {
        switch self {
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .driving: return "car.fill"
        }
    }
    
    var appleTransportType: MKDirectionsTransportType? {
        switch self {
        case .walking: return .walking
        case .cycling: return nil // MapKit has no bicycle directions API.
        case .driving: return .automobile
        }
    }
}

struct RouteSpeeds {
    private var values: [TravelMode: Double] = [:]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        for mode in TravelMode.allCases {
            let saved = defaults.double(forKey: Self.key(mode))
            values[mode] = saved.isFinite && (1...500).contains(saved) ? saved : mode.defaultSpeedKmh
        }
    }

    subscript(mode: TravelMode) -> Double { values[mode] ?? mode.defaultSpeedKmh }
    private static func key(_ mode: TravelMode) -> String { "routeSpeedKmh." + mode.rawValue.lowercased() }
    mutating func set(_ kmh: Double, for mode: TravelMode) {
        guard kmh.isFinite else { return }
        let speed = min(500, max(1, kmh))
        values[mode] = speed
        defaults.set(speed, forKey: Self.key(mode))
    }
}

// A provider-independent route keeps mode selection and future travel modes
// separate from Apple's read-only MKRoute type.
struct RoutePath {
    let polyline: MKPolyline
    let distance: Double
    let expectedTravelTime: TimeInterval
    let name: String
    let trafficLabel: String

    init(_ route: MKRoute, mode: TravelMode) {
        polyline = route.polyline
        distance = route.distance
        expectedTravelTime = route.expectedTravelTime
        name = route.name
        trafficLabel = mode == .driving ? "Real traffic" : "Typical travel"
    }

    init(polyline: MKPolyline, distance: Double, expectedTravelTime: TimeInterval,
         name: String, trafficLabel: String = "Typical travel") {
        self.polyline = polyline
        self.distance = distance
        self.expectedTravelTime = expectedTravelTime
        self.name = name
        self.trafficLabel = trafficLabel
    }
}

struct RouteModeCache {
    private(set) var routes: [TravelMode: [RouteOption]] = [:]
    private(set) var selections: [TravelMode: Int] = [:]
    mutating func store(_ paths: [RoutePath], for mode: TravelMode) {
        let valid = paths.filter { $0.polyline.pointCount >= 2 && $0.distance.isFinite && $0.distance > 0 }
        routes[mode] = RouteSimulationMath.rankedIndices(distances: valid.map(\.distance))
            .enumerated().map { RouteOption(route: valid[$0.element], index: $0.offset) }
        selections[mode] = 0
    }
    mutating func select(_ index: Int, for mode: TravelMode) {
        guard routes[mode]?.indices.contains(index) == true else { return }
        selections[mode] = index
    }
    func duration(for mode: TravelMode, kmh: Double) -> String? {
        routes[mode]?.first?.simulationTimeText(speedKmh: kmh)
    }
}

enum BicycleRouteError: LocalizedError {
    case unavailable
    var errorDescription: String? { "Cycling directions are unavailable. Please try calculating again." }
}

actor BicycleDirections {
    static let shared = BicycleDirections()
    private var nextRequest = Date.distantPast
    // A single reservation queue keeps requests over one second apart, even
    // when an earlier route was cancelled. No requests happen on tab/speed changes.
    func routes(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) async throws -> [RoutePath] {
        let delay = max(0, nextRequest.timeIntervalSinceNow)
        nextRequest = Date().addingTimeInterval(delay + 1.1)
        if delay > 0 { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
        try Task.checkCancellation()
        let start = CoordTransform.gcj02ToWgs84(start)
        let end = CoordTransform.gcj02ToWgs84(end)
        let pair = "\(start.longitude),\(start.latitude);\(end.longitude),\(end.latitude)"
        let url = URL(string: "https://routing.openstreetmap.de/routed-bike/route/v1/bike/\(pair)?alternatives=true&overview=full&geometries=geojson&steps=false")!
        var request = URLRequest(url: url, timeoutInterval: 25)
        request.setValue("Andromeda/2.6 (https://github.com/dm2mymcszt-commits/Andromeda)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw BicycleRouteError.unavailable }
        return try Self.decode(data)
    }

    static func decode(_ data: Data) throws -> [RoutePath] {
        struct Response: Decodable {
            struct Route: Decodable {
                struct Geometry: Decodable { let coordinates: [[Double]] }
                struct Leg: Decodable { let summary: String? }
                let geometry: Geometry
                let distance: Double
                let duration: Double
                let legs: [Leg]
            }
            let code: String
            let routes: [Route]?
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.code == "Ok" else { throw BicycleRouteError.unavailable }
        let routes = (response.routes ?? []).compactMap { route -> RoutePath? in
            let coords = route.geometry.coordinates.compactMap { pair -> CLLocationCoordinate2D? in
                guard pair.count == 2 else { return nil }
                let coord = CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
                return CLLocationCoordinate2DIsValid(coord) ? CoordTransform.wgs84ToGcj02(coord) : nil
            }
            guard coords.count == route.geometry.coordinates.count, coords.count >= 2,
                  route.distance.isFinite, route.distance > 0 else { return nil }
            return RoutePath(polyline: MKPolyline(coordinates: coords, count: coords.count),
                             distance: route.distance, expectedTravelTime: route.duration,
                             name: route.legs.compactMap(\.summary).filter { !$0.isEmpty }.joined(separator: ", "))
        }
        guard !routes.isEmpty else { throw BicycleRouteError.unavailable }
        return routes
    }
}

class RouteOption: Identifiable, ObservableObject {
    let id = UUID()
    let route: RoutePath
    let index: Int

    var isFastest: Bool {
        index == 0 && route.distance.isFinite && route.distance > 0
    }
    
    var name: String {
        if isFastest { return "Fastest Route" }
        if index == 0 { return "Route 1" }
        return "Alternative \(index)"
    }
    
    var distanceText: String {
        if route.distance >= 1000 {
            return String(format: "%.1f km", route.distance / 1000)
        }
        return String(format: "%.0f m", route.distance)
    }
    
    var trafficTimeText: String {
        guard route.expectedTravelTime.isFinite, route.expectedTravelTime > 0 else { return "ETA unavailable" }
        let minutes = max(1, Int(ceil(route.expectedTravelTime / 60)))
        if minutes >= 60 {
            let hours = minutes / 60
            let rem = minutes % 60
            return "\(hours)h \(rem)m"
        }
        return "\(minutes) min"
    }

    func simulationTimeText(speedKmh: Double) -> String {
        RouteSimulationMath.durationText(RouteSimulationMath.simulationSeconds(
            distance: route.distance, speed: speedKmh / 3.6))
    }
    
    init(route: RoutePath, index: Int) {
        self.route = route
        self.index = index
    }
}

class RouteSimulator: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isSimulating: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentPointIndex: Int = 0
    @Published var totalPoints: Int = 0
    @Published var routePolyline: MKPolyline? = nil
    @Published var currentPosition: CLLocationCoordinate2D? = nil
    @Published var progress: Double = 0.0
    @Published var isCalculatingRoute: Bool = false
    @Published var estimatedTime: String = ""
    @Published var travelMode: TravelMode = .driving
    
    @Published var availableRoutes: [RouteOption] = []
    @Published var allRoutePolylines: [MKPolyline] = []
    @Published var selectedRouteIndex: Int = 0
    @Published var routeStart: CLLocationCoordinate2D? = nil
    @Published var routeEnd: CLLocationCoordinate2D? = nil
    
    private var routePoints: [CLLocationCoordinate2D] = []
    private var timer: Timer? = nil
    private var altitude: Double = 0.0
    @Published private var speeds = RouteSpeeds()
    @Published private var modeCache = RouteModeCache()
    @Published private(set) var modeErrors: [TravelMode: String] = [:]
    func speedKmh(for mode: TravelMode) -> Double { speeds[mode] }
    var currentSpeedKmh: Double { speeds[travelMode] }
    func modeDuration(_ mode: TravelMode) -> String? { modeCache.duration(for: mode, kmh: speeds[mode]) }
    var simulatedRouteETAs: [String] {
        availableRoutes.map { $0.simulationTimeText(speedKmh: currentSpeedKmh) }
    }
    private let updateInterval: TimeInterval = 1.0
    private var lastSimulatedLocation: CLLocation?
    private var pendingDirections: [TravelMode: MKDirections] = [:]
    private var bicycleTask: Task<Void, Never>?
    private var calculationID = UUID()
    
    // Background handling
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
    }
    
    func calculateRoutes(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, mode: TravelMode, completion: @escaping (Bool, String?) -> Void) {
        guard !isSimulating else {
            completion(false, "Stop the current simulation before calculating another route.")
            return
        }
        clearCalculatedRoutes()
        guard CLLocationCoordinate2DIsValid(start), CLLocationCoordinate2DIsValid(end) else {
            completion(false, "Choose valid endpoints.")
            return
        }
        isCalculatingRoute = true
        travelMode = mode
        routeStart = start
        routeEnd = end
        let requestID = calculationID
        var remaining = TravelMode.allCases.count
        // All results belong to the same endpoint snapshot. Cancellation discards
        // the entire generation, including a late bicycle response after swapping.
        let receive: (TravelMode, [RoutePath], String?) -> Void = { [weak self] mode, routes, error in
            guard let self = self, self.calculationID == requestID else { return }
            self.pendingDirections[mode] = nil
            self.modeCache.store(routes, for: mode)
            if routes.isEmpty { self.modeErrors[mode] = error ?? "No route found for this mode." }
            remaining -= 1
            guard remaining == 0 else { return }
            self.bicycleTask = nil
            self.isCalculatingRoute = false
            self.selectMode(self.travelMode)
            // Keep successful modes available even if another mode has no route.
            completion(!self.availableRoutes.isEmpty, self.modeErrors[self.travelMode])
        }
        for mode in TravelMode.allCases {
            if let transport = mode.appleTransportType {
                let request = MKDirections.Request()
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
                request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
                request.transportType = transport
                request.requestsAlternateRoutes = true
                request.departureDate = Date()
                let directions = MKDirections(request: request)
                pendingDirections[mode] = directions
                directions.calculate { response, error in
                    DispatchQueue.main.async {
                        receive(mode, (response?.routes ?? []).map { RoutePath($0, mode: mode) }, error?.localizedDescription)
                    }
                }
            } else {
                bicycleTask = Task { @MainActor in
                    do { receive(mode, try await BicycleDirections.shared.routes(from: start, to: end), nil) }
                    catch { receive(mode, [], error.localizedDescription) }
                }
            }
        }
    }

    func selectMode(_ mode: TravelMode) {
        guard !isSimulating else { return }
        travelMode = mode
        availableRoutes = modeCache.routes[mode] ?? []
        allRoutePolylines = availableRoutes.map { $0.route.polyline }
        routePolyline = nil
        routePoints = []
        totalPoints = 0
        estimatedTime = ""
        selectedRouteIndex = modeCache.selections[mode] ?? 0
        selectRoute(at: selectedRouteIndex)
    }

    func selectRoute(at index: Int) {
        guard !isSimulating, availableRoutes.indices.contains(index) else { return }
        selectedRouteIndex = index
        modeCache.select(index, for: travelMode)
        let route = availableRoutes[index].route
        
        let pointCount = route.polyline.pointCount
        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        
        let effectiveSpeed = currentSpeedKmh / 3.6
        routePoints = RouteSimulationMath.interpolate(coords: coords, speed: effectiveSpeed, interval: updateInterval)
        totalPoints = routePoints.count
        routePolyline = route.polyline
        
        estimatedTime = availableRoutes[index].simulationTimeText(speedKmh: currentSpeedKmh)
    }

    func updateSpeedKmh(_ kmh: Double, for mode: TravelMode) {
        guard !isSimulating else { return }
        speeds.set(kmh, for: mode)
        if mode == travelMode { selectRoute(at: selectedRouteIndex) }
    }

    func clearCalculatedRoutes() {
        guard !isSimulating else { return }
        calculationID = UUID()
        pendingDirections.values.forEach { $0.cancel() }
        pendingDirections = [:]
        bicycleTask?.cancel()
        bicycleTask = nil
        modeCache = RouteModeCache()
        modeErrors = [:]
        isCalculatingRoute = false
        availableRoutes = []
        allRoutePolylines = []
        routePolyline = nil
        routePoints = []
        routeStart = nil
        routeEnd = nil
        selectedRouteIndex = 0
        totalPoints = 0
        currentPointIndex = 0
        progress = 0
        estimatedTime = ""
    }
    
    func startSimulation(altitude: Double = 0.0) {
        guard !isSimulating, routePoints.count >= 2 else { return }
        timer?.invalidate()
        self.altitude = altitude
        currentPointIndex = 0
        isSimulating = true
        isPaused = false
        progress = 0.0
        lastSimulatedLocation = nil
        
        // Request "Always" authorization for background
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        
        startBackgroundTask()
        updateLocation(at: 0)
        
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.advanceToNextPoint()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    func togglePause() {
        guard isSimulating else { return }
        if isPaused {
            isPaused = false
            startBackgroundTask()
            timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
                self?.advanceToNextPoint()
            }
            RunLoop.current.add(timer!, forMode: .common)
        } else {
            isPaused = true
            timer?.invalidate()
            timer = nil
            endBackgroundTask()
        }
        // Refresh motion at the same coordinate; pausing must not leave a moving speed.
        if let location = lastSimulatedLocation {
            injectLocation(RouteLocationSample.make(
                coordinate: location.coordinate,
                altitude: location.altitude,
                course: location.course,
                speed: motion(at: currentPointIndex).speed,
                timestamp: Date()
            ))
        }
    }
    
    func stopSimulation() {
        timer?.invalidate()
        timer = nil
        isSimulating = false
        isPaused = false
        clearCalculatedRoutes()
        currentPosition = nil
        lastSimulatedLocation = nil
        locationManager.stopUpdatingLocation()
        endBackgroundTask()
        LocSimManager.stopLocSim()
    }
    
    private func advanceToNextPoint() {
        guard isSimulating, !isPaused else { return }
        currentPointIndex += 1
        currentPointIndex = min(currentPointIndex, routePoints.count - 1)
        updateLocation(at: currentPointIndex)
        progress = Double(currentPointIndex) / Double(max(totalPoints - 1, 1))

        if currentPointIndex == routePoints.count - 1 {
            // Finish immediately on the exact destination, whose injected speed is zero.
            // Keep its simulated location fixed until the user explicitly stops LocSim.
            timer?.invalidate()
            timer = nil
            isSimulating = false
            isPaused = false
            progress = 1.0
            endBackgroundTask()
            locationManager.stopUpdatingLocation()
        }
    }
    
    private func updateLocation(at index: Int) {
        guard routePoints.indices.contains(index) else { return }
        let coord = routePoints[index]
        currentPosition = coord
        
        let wgsCoord = CoordTransform.gcj02ToWgs84(coord)
        let motion = motion(at: index)
        let location = RouteLocationSample.make(
            coordinate: wgsCoord,
            altitude: altitude,
            course: motion.course,
            speed: motion.speed,
            timestamp: Date()
        )
        injectLocation(location)
    }

    private func injectLocation(_ location: CLLocation) {
        lastSimulatedLocation = location
        LocSimManager.startLocSim(location: location)
    }

    private func motion(at index: Int) -> (speed: CLLocationSpeed, course: CLLocationDirection) {
        let previousCourse = lastSimulatedLocation?.course ?? 0
        guard index >= 0, index + 1 < routePoints.count else {
            // Keep the destination fixed with zero speed and the last known bearing.
            return (0, previousCourse)
        }
        // Use unjittered WGS-84 route points so random noise does not steer the bearing.
        let from = CoordTransform.gcj02ToWgs84(routePoints[index])
        let to = CoordTransform.gcj02ToWgs84(routePoints[index + 1])
        let stepDistance = RouteSimulationMath.distance(from, to)
        guard stepDistance > 0 else { return (0, previousCourse) }
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLongitude = (to.longitude - from.longitude) * .pi / 180
        let y = sin(deltaLongitude) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLongitude)
        let course = (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        return (isPaused ? 0 : min(currentSpeedKmh / 3.6, stepDistance / updateInterval), course)
    }
    
    // MARK: - Background Task Management
    private func startBackgroundTask() {
        endBackgroundTask()
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "RouteSimulation") { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}
