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
    func inject(_ location: CLLocation, reason: LocationInjectionReason)
    func stop()
}

enum LocationInjectionReason { case continuous, jump, stateChange }

/// Trailing-edge coalescing on a monotonic clock. UI state never waits for this
/// queue. Explicit jumps and pause/arrival changes bypass it; Stop cancels it.
final class LocationInjectionQueue {
    typealias Schedule = (TimeInterval, @escaping () -> Void) -> (() -> Void)
    private let interval: TimeInterval
    private let now: () -> TimeInterval
    private let schedule: Schedule
    private let deliver: (CLLocation, LocationInjectionReason) -> Void
    private var lastDelivery: TimeInterval?
    private var pending: CLLocation?
    private var cancelWork: (() -> Void)?
    private var generation = 0

    init(interval: TimeInterval = 0.25,
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         schedule: @escaping Schedule = LocationInjectionQueue.scheduleOnMain,
         deliver: @escaping (CLLocation, LocationInjectionReason) -> Void) {
        self.interval = max(0, interval)
        self.now = now
        self.schedule = schedule
        self.deliver = deliver
    }

    static func scheduleOnMain(after delay: TimeInterval, work: @escaping () -> Void) -> () -> Void {
        let item = DispatchWorkItem(block: work)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return { item.cancel() }
    }

    func submit(_ location: CLLocation, reason: LocationInjectionReason) {
        let delay = lastDelivery.map { max(0, interval - (now() - $0)) } ?? 0
        if reason != .continuous || delay <= 0 {
            cancelPending()
            emit(location, reason: reason)
            return
        }
        pending = location
        guard cancelWork == nil else { return }
        let token = generation
        cancelWork = schedule(delay) { [weak self] in
            guard let self = self, self.generation == token else { return }
            self.flush()
        }
    }

    func flush() {
        let latest = pending
        cancelPending()
        if let latest = latest { emit(latest, reason: .continuous) }
    }

    func stop() { cancelPending(); lastDelivery = nil }

    private func cancelPending() {
        generation += 1
        cancelWork?()
        cancelWork = nil
        pending = nil
    }

    private func emit(_ location: CLLocation, reason: LocationInjectionReason) {
        lastDelivery = now()
        deliver(location, reason)
    }
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
    private let batchLookup: ([CLLocationCoordinate2D]) async -> [Double?]?
    private let injectionInterval: TimeInterval
    private var deliveryReason = LocationInjectionReason.continuous
    private var firstRouteSample = false
    private lazy var injectionQueue = LocationInjectionQueue(interval: injectionInterval,
        deliver: { [weak self] in self?.inject($0, reason: $1) })
    lazy var altitudeController = AltitudeController(settings: settings, defaults: defaults,
        lookup: lookup, batchLookup: batchLookup, currentLocation: { [weak self] in self?.inputSample },
        deliver: { [weak self] in self?.deliver($0) })

    init(driver: LocationSimulationDriver, defaults: UserDefaults = SharedPreferences.defaults,
         settings: AltitudeSettings = .shared, injectionInterval: TimeInterval = 0.25,
         lookup: @escaping (CLLocationCoordinate2D) async -> Double? = ElevationLookup.fetch,
         batchLookup: @escaping ([CLLocationCoordinate2D]) async -> [Double?]? = ElevationLookup.fetchBatch) {
        self.driver = driver
        self.defaults = defaults
        self.settings = settings
        self.lookup = lookup
        self.batchLookup = batchLookup
        self.injectionInterval = injectionInterval
        store = LocationSessionStore(defaults: defaults)
        snapshot = store.load()
        inputSample = snapshot.current?.location
        lastKnown = snapshot.current
    }

    var current: SessionLocation? { snapshot.current }
    var isActive: Bool { snapshot.isActive }

    func beginRoute() {
        injectionQueue.flush()
        snapshot.beforeRoute = snapshot.current
        snapshot.kind = .route
        firstRouteSample = true
        store.save(snapshot)
    }

    func receive(_ location: CLLocation, kind: LocationSessionSnapshot.Kind,
                 reason: LocationInjectionReason = .continuous, routeDistance: Double? = nil) {
        guard SessionLocation(location).isValid else { return }
        if kind != .route { altitudeController.finishRoute() }
        let stopped = location.speed == 0 && inputSample?.speed != 0
        deliveryReason = (kind == .stationary || firstRouteSample || reason == .jump) ? .jump :
            (stopped || reason == .stateChange ? .stateChange : .continuous)
        firstRouteSample = false
        inputSample = location
        snapshot.kind = kind
        if kind != .route { snapshot.beforeRoute = nil }
        altitudeController.receive(routeDistance: kind == .route ? routeDistance : nil)
        deliveryReason = .continuous
    }

    /// Natural arrival already emitted its zero-speed sample; only ownership changes.
    func finishHolding() {
        injectionQueue.flush()
        // Keep terrain loading at the fixed final route distance. This can
        // refine a held provisional height without ever restarting movement.
        snapshot.kind = snapshot.current == nil ? nil : .stationary
        snapshot.beforeRoute = nil
        store.save(snapshot)
    }

    func stop() {
        inputSample = nil
        firstRouteSample = false
        injectionQueue.stop()
        altitudeController.stop()
        driver.stop()
        snapshot = LocationSessionSnapshot()
        store.save(snapshot)
    }

    private func deliver(_ location: CLLocation) {
        guard inputSample != nil, snapshot.kind != nil else { return }
        injectionQueue.submit(location, reason: deliveryReason)
    }

    private func inject(_ location: CLLocation, reason: LocationInjectionReason) {
        guard inputSample != nil, snapshot.kind != nil else { return }
        driver.inject(location, reason: reason)
        snapshot.current = SessionLocation(location)
        lastKnown = snapshot.current
        store.save(snapshot)
    }
}
