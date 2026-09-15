import UIKit
import MapKit

// Only the privileged output is replaced. The full production RouteSimulator,
// LocationSession, geometry, altitude and finish code execute in the simulator.
enum LocSimManager {
    static var session: LocationSession { fatalError("Inject the recording owner") }
}
final class EngineDriver: LocationSimulationDriver {
    var samples: [CLLocation] = []
    func inject(_ location: CLLocation, reason: LocationInjectionReason) { samples.append(location) }
    func stop() {}
}

final class EngineFixture {
    let suite: String
    let defaults: UserDefaults
    let settings: RouteFinishSettings
    let driver: EngineDriver
    let owner: LocationSession
    var engine: RouteSimulator!
    var clock = 1000.0
    var notifications: [String] = []
    let a = CLLocationCoordinate2D(latitude: 44.8, longitude: -0.6)
    let b = CLLocationCoordinate2D(latitude: 44.81, longitude: -0.59)
    let c = CLLocationCoordinate2D(latitude: 45, longitude: 1)

    init() {
        let domain = "engine-tests-\(UUID().uuidString)"
        let storage = UserDefaults(suiteName: domain)!
        let recording = EngineDriver()
        suite = domain
        defaults = storage
        driver = recording
        settings = RouteFinishSettings(defaults: storage)
        let altitude = AltitudeSettings(defaults: storage)
        altitude.setCustom(250)
        owner = LocationSession(driver: recording, defaults: storage, settings: altitude,
            injectionInterval: 0, lookup: { _ in nil }, batchLookup: { _ in nil })
        engine = RouteSimulator(locationSession: owner, finishDefaults: settings,
            now: { [unowned self] in self.clock },
            notifyCompletion: { [unowned self] in self.notifications.append($0) })
    }
    func prepare() {
        engine.clearCalculatedRoutes()
        engine.routeStart = a
        engine.routeEnd = b
        let coords = [a, b].map(CoordTransform.wgs84ToGcj02)
        let polyline = MKPolyline(coordinates: coords, count: coords.count)
        engine.availableRoutes = [RouteOption(route: RoutePath(polyline: polyline,
            distance: RouteSimulationMath.distance(a, b), expectedTravelTime: 300, name: "Fixture"), index: 0)]
        engine.selectRoute(at: 0)
        engine.updateSpeedKmh(50, for: .driving)
    }
    func close() {
        engine.stopSimulation()
        defaults.removePersistentDomain(forName: suite)
    }
    func at(_ point: CLLocationCoordinate2D) -> Bool {
        guard let location = owner.current else { return false }
        return location.location.distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude)) < 0.1
    }
}

func testRouteFinishEngine() {
    let fixture = EngineFixture()
    defer { fixture.close() }
    fixture.prepare()
    fixture.engine.configureFinish(RouteFinishConfiguration(action: .returnOnce))
    precondition(fixture.settings.action == .stay)
    fixture.engine.startSimulation()
    precondition(fixture.engine.isSimulating && fixture.owner.current!.speed > 0)
    fixture.engine.seek(to: 1)
    precondition(fixture.engine.isSimulating && fixture.at(fixture.b))
    fixture.engine.seek(to: 1)
    precondition(!fixture.engine.isSimulating && fixture.at(fixture.a))
    precondition(fixture.owner.current!.speed == 0 && fixture.owner.current!.meters == 250)
    precondition(fixture.notifications == ["Returning to start", "Staying at the start"])
    fixture.prepare()
    precondition(fixture.engine.finishConfiguration.action == .stay, "Next prepared trip must use Settings")

    for returning in [false, true] {
        for action in RouteFinishAction.allCases {
            let f = EngineFixture()
            f.prepare()
            if returning { f.engine.configureFinish(RouteFinishConfiguration(action: .returnOnce)) }
            f.engine.startSimulation()
            if returning { f.engine.seek(to: 1) }
            let before = f.driver.samples.count
            let place = RouteFinishDestination(name: "Trip only", address: "", coordinate: f.c)
            f.engine.configureFinish(RouteFinishConfiguration(action: action, destination: place))
            precondition(f.driver.samples.count == before, "Editing completion must not inject or pause")
            precondition(f.settings.action == .stay && f.settings.destination == nil)
            f.clock += 1
            f.engine.advanceRoute()
            precondition(f.owner.current!.speed > 0 && f.owner.current!.meters == 250)
            f.engine.seek(to: 1)
            switch action {
            case .stay:
                precondition(!f.engine.isSimulating && f.at(returning ? f.a : f.b))
                precondition(f.owner.current!.speed == 0)
                precondition(f.notifications.last == (returning ? "Staying at the start" : "Staying at destination"))
            case .goToPlace:
                precondition(!f.engine.isSimulating && f.at(f.c) && f.owner.current!.speed == 0)
                precondition(f.owner.current!.meters == 250)
            case .stop:
                precondition(!f.engine.isSimulating && !f.owner.isActive)
            case .loop:
                precondition(f.engine.isSimulating && f.at(f.a) && f.owner.current!.speed > 0)
                f.engine.seek(to: 1)
                precondition(f.notifications.count == 1 && f.at(f.a))
            case .returnOnce:
                if returning { precondition(!f.engine.isSimulating && f.at(f.a)) }
                else {
                    precondition(f.engine.isSimulating && f.at(f.b))
                    f.engine.seek(to: 1)
                    precondition(!f.engine.isSimulating && f.at(f.a) && f.notifications.count == 2)
                }
            case .backAndForth:
                precondition(f.engine.isSimulating && f.at(returning ? f.a : f.b))
                f.engine.seek(to: 1)
                precondition(f.engine.isSimulating && f.at(returning ? f.b : f.a) && f.notifications.count == 1)
            }
            f.close()
        }
    }
}

@main final class EngineApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        self.window = window
        DispatchQueue.main.async {
            testRouteFinishEngine()
            let text = "PASS: actual RouteSimulator prepared defaults, per-trip isolation, all six live actions on outbound/return legs, notifications, speed and altitude\n"
            let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("results.txt")
            try! text.write(to: path, atomically: true, encoding: .utf8)
        }
        return true
    }
}
