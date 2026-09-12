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
    
    var speed: Double { // meters per second
        switch self {
        case .walking: return 1.4   // ~5 km/h
        case .cycling: return 5.5   // ~20 km/h
        case .driving: return 13.9  // ~50 km/h
        }
    }
    
    var icon: String {
        switch self {
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .driving: return "car.fill"
        }
    }
    
    var transportType: MKDirectionsTransportType {
        switch self {
        case .walking: return .walking
        case .cycling: return .walking
        case .driving: return .automobile
        }
    }
}

class RouteOption: Identifiable, ObservableObject {
    let id = UUID()
    let route: MKRoute
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

    func simulationTimeText(mode: TravelMode, speedMultiplier: Double) -> String {
        RouteSimulationMath.durationText(RouteSimulationMath.simulationSeconds(
            distance: route.distance, speed: mode.speed * speedMultiplier))
    }
    
    init(route: MKRoute, index: Int) {
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
    @Published private var speedMultiplier: Double = 1.0
    var currentSpeedMultiplier: Double { speedMultiplier }
    var simulatedRouteETAs: [String] {
        availableRoutes.map { $0.simulationTimeText(mode: travelMode, speedMultiplier: speedMultiplier) }
    }
    private let updateInterval: TimeInterval = 1.0
    private var lastSimulatedLocation: CLLocation?
    private var pendingDirections: MKDirections?
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
    
    func calculateRoutes(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, mode: TravelMode, speedMult: Double, completion: @escaping (Bool, String?) -> Void) {
        guard !isSimulating else {
            completion(false, "Stop the current simulation before calculating another route.")
            return
        }
        clearCalculatedRoutes()
        guard CLLocationCoordinate2DIsValid(start), CLLocationCoordinate2DIsValid(end),
              speedMult.isFinite, speedMult > 0 else {
            completion(false, "Choose valid endpoints and a positive simulation speed.")
            return
        }
        isCalculatingRoute = true
        travelMode = mode
        speedMultiplier = min(10, max(0.5, speedMult))
        let requestID = calculationID
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = mode.transportType
        request.requestsAlternateRoutes = true
        request.departureDate = Date()
        
        let directions = MKDirections(request: request)
        pendingDirections = directions
        directions.calculate { [weak self] response, error in
            DispatchQueue.main.async {
                // A canceled result must not revive a preview for old endpoints or travel mode.
                guard let self = self, self.calculationID == requestID else { return }
                self.pendingDirections = nil
                self.isCalculatingRoute = false
                if let error = error {
                    completion(false, "Route error: \(error.localizedDescription)")
                    return
                }
                let routes = (response?.routes ?? []).filter {
                    $0.polyline.pointCount >= 2 && $0.distance.isFinite && $0.distance > 0
                }
                guard !routes.isEmpty else {
                    completion(false, "No route found")
                    return
                }
                let sortedRoutes = RouteSimulationMath.rankedIndices(
                    distances: routes.map(\.distance)
                ).map { routes[$0] }
                self.availableRoutes = sortedRoutes.enumerated().map { RouteOption(route: $0.element, index: $0.offset) }
                self.allRoutePolylines = sortedRoutes.map { $0.polyline }
                self.routeStart = start
                self.routeEnd = end
                self.selectRoute(at: 0)
                completion(true, nil)
            }
        }
    }
    
    func selectRoute(at index: Int) {
        guard !isSimulating, availableRoutes.indices.contains(index) else { return }
        selectedRouteIndex = index
        let route = availableRoutes[index].route
        
        let pointCount = route.polyline.pointCount
        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        
        let effectiveSpeed = travelMode.speed * speedMultiplier
        routePoints = RouteSimulationMath.interpolate(coords: coords, speed: effectiveSpeed, interval: updateInterval)
        totalPoints = routePoints.count
        routePolyline = route.polyline
        
        estimatedTime = availableRoutes[index].simulationTimeText(mode: travelMode, speedMultiplier: speedMultiplier)
    }

    func updateSpeedMultiplier(_ multiplier: Double) {
        guard !isSimulating, multiplier.isFinite, multiplier > 0 else { return }
        speedMultiplier = min(10, max(0.5, multiplier))
        selectRoute(at: selectedRouteIndex)
    }

    func clearCalculatedRoutes() {
        guard !isSimulating else { return }
        calculationID = UUID()
        pendingDirections?.cancel()
        pendingDirections = nil
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
        return (isPaused ? 0 : min(travelMode.speed * speedMultiplier, stepDistance / updateInterval), course)
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
