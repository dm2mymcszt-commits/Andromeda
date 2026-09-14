import Foundation
import CoreLocation
import Combine

/// A portable WGS-84 sample. Unknown altitude remains unknown after persistence.
struct SessionLocation: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let course: Double
    let courseAccuracy: Double
    let speed: Double
    let speedAccuracy: Double
    let timestamp: Date

    init(_ location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude = location.altitude
        horizontalAccuracy = location.horizontalAccuracy
        verticalAccuracy = location.verticalAccuracy
        course = location.course
        courseAccuracy = location.courseAccuracy
        speed = location.speed
        speedAccuracy = location.speedAccuracy
        timestamp = location.timestamp
    }

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    var meters: Double? { verticalAccuracy >= 0 ? altitude : nil }
    var isValid: Bool {
        CLLocationCoordinate2DIsValid(coordinate) &&
        [altitude, horizontalAccuracy, verticalAccuracy, course, courseAccuracy,
         speed, speedAccuracy, timestamp.timeIntervalSince1970].allSatisfy(\.isFinite)
    }
    var location: CLLocation {
        CLLocation(coordinate: coordinate, altitude: altitude,
            horizontalAccuracy: horizontalAccuracy, verticalAccuracy: verticalAccuracy,
            course: course, courseAccuracy: courseAccuracy, speed: speed,
            speedAccuracy: speedAccuracy, timestamp: timestamp)
    }
}

struct LocationSessionSnapshot: Codable, Equatable {
    enum Kind: String, Codable { case stationary, joystick, route }
    var kind: Kind?
    var current: SessionLocation?
    var beforeRoute: SessionLocation?
    var isActive: Bool { kind != nil && current != nil }
    var isValid: Bool {
        (current?.isValid ?? true) && (beforeRoute?.isValid ?? true) &&
        (kind != nil || current == nil)
    }
}

/// Shared storage contains the last injected sample, not a second route engine.
/// Loading a snapshot never starts playback or silently changes the location.
final class LocationSessionStore {
    private let defaults: UserDefaults
    private let key = "locationSession.v1"
    init(defaults: UserDefaults = SharedPreferences.defaults) { self.defaults = defaults }
    func load() -> LocationSessionSnapshot {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(LocationSessionSnapshot.self, from: data),
              value.isValid else { return LocationSessionSnapshot() }
        return value
    }
    func save(_ snapshot: LocationSessionSnapshot) {
        guard snapshot.isValid, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
}

protocol LocationSimulationDriver: AnyObject {
    func inject(_ location: CLLocation)
    func stop()
}

/// The only owner of the active spoof. Route geometry and UI remain consumers.
final class LocationSession: ObservableObject {
    @Published private(set) var snapshot: LocationSessionSnapshot
    private(set) var inputSample: CLLocation?
    private(set) var lastKnown: SessionLocation?
    private let driver: LocationSimulationDriver
    private let store: LocationSessionStore
    private let settings: AltitudeSettings
    private let defaults: UserDefaults
    private let lookup: (CLLocationCoordinate2D) async -> Double?
    lazy var altitudeController = AltitudeController(settings: settings, defaults: defaults,
        lookup: lookup, currentLocation: { [weak self] in self?.inputSample },
        deliver: { [weak self] in self?.deliver($0) })

    init(driver: LocationSimulationDriver, defaults: UserDefaults = SharedPreferences.defaults,
         settings: AltitudeSettings = .shared,
         lookup: @escaping (CLLocationCoordinate2D) async -> Double? = ElevationLookup.fetch) {
        self.driver = driver
        self.defaults = defaults
        self.settings = settings
        self.lookup = lookup
        store = LocationSessionStore(defaults: defaults)
        snapshot = store.load()
        inputSample = snapshot.current?.location
        lastKnown = snapshot.current
    }

    var current: SessionLocation? { snapshot.current }
    var isActive: Bool { snapshot.isActive }

    func beginRoute() {
        snapshot.beforeRoute = snapshot.current
        snapshot.kind = .route
        store.save(snapshot)
    }

    func receive(_ location: CLLocation, kind: LocationSessionSnapshot.Kind) {
        guard SessionLocation(location).isValid else { return }
        inputSample = location
        snapshot.kind = kind
        if kind != .route { snapshot.beforeRoute = nil }
        altitudeController.receive()
    }

    /// Natural arrival already emitted its zero-speed sample; only ownership changes.
    func finishHolding() {
        snapshot.kind = snapshot.current == nil ? nil : .stationary
        snapshot.beforeRoute = nil
        store.save(snapshot)
    }

    func stop() {
        inputSample = nil
        altitudeController.stop()
        driver.stop()
        snapshot = LocationSessionSnapshot()
        store.save(snapshot)
    }

    private func deliver(_ location: CLLocation) {
        guard inputSample != nil, snapshot.kind != nil else { return }
        driver.inject(location)
        snapshot.current = SessionLocation(location)
        lastKnown = snapshot.current
        store.save(snapshot)
    }
}
