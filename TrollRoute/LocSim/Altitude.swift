import Foundation
import CoreLocation
import Combine

struct AltitudeProfile: Codable, Equatable {
    enum Mode: String, Codable { case automatic, custom }
    var mode: Mode = .automatic
    var customMeters: Double = 0

    static func parse(_ text: String) -> Double? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard value.range(of: #"^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$"#, options: .regularExpression) != nil,
              let number = Double(value), number.isFinite else { return nil }
        return number
    }
}

final class AltitudeSettings: ObservableObject {
    static let shared = AltitudeSettings()
    private let defaults: UserDefaults
    @Published private(set) var profile: AltitudeProfile {
        didSet { defaults.set(try? JSONEncoder().encode(profile), forKey: "altitudeProfile") }
    }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.data(forKey: "altitudeProfile").flatMap {
            try? JSONDecoder().decode(AltitudeProfile.self, from: $0)
        }
        profile = saved.flatMap { $0.customMeters.isFinite ? $0 : nil } ?? AltitudeProfile()
    }
    func setCustom(_ meters: Double) {
        guard meters.isFinite else { return }
        profile = AltitudeProfile(mode: .custom, customMeters: meters)
    }
    func reset() { profile = AltitudeProfile() }
}

enum ElevationLookup {
    static func decode(_ data: Data) -> Double? {
        struct Response: Decodable { let elevation: [Double?] }
        guard let response = try? JSONDecoder().decode(Response.self, from: data),
              response.elevation.count == 1, let value = response.elevation[0],
              value.isFinite, value != -9999 else { return nil }
        return value
    }
    static func fetch(_ coordinate: CLLocationCoordinate2D) async -> Double? {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        var url = URLComponents(string: "https://api.open-meteo.com/v1/elevation")!
        url.queryItems = [URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
                         URLQueryItem(name: "longitude", value: String(coordinate.longitude))]
        var request = URLRequest(url: url.url!, timeoutInterval: 8)
        request.setValue("TrollRoute/\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.0.0") (https://github.com/dm2mymcszt-commits/TrollRoute)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return decode(data)
    }
}

// All callers supply WGS-84 locations. Altitude is applied once, immediately
// before injection, without changing any of the caller's motion metadata.
final class AltitudeController: ObservableObject {
    @Published private(set) var currentMeters: Double?
    @Published private(set) var isActive = false
    private var profile: AltitudeProfile
    private var activeLocation: CLLocation?
    private var cache: [(coordinate: CLLocationCoordinate2D, meters: Double)] = []
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var observation: AnyCancellable?
    private let deliver: (CLLocation) -> Void
    private let lookup: (CLLocationCoordinate2D) async -> Double?
    private let interval: TimeInterval
    private let defaults: UserDefaults
    private var nextLookup: Date

    init(settings: AltitudeSettings = .shared, defaults: UserDefaults = .standard,
         interval: TimeInterval = 10,
         lookup: @escaping (CLLocationCoordinate2D) async -> Double? = ElevationLookup.fetch,
         deliver: @escaping (CLLocation) -> Void) {
        self.profile = settings.profile
        self.defaults = defaults
        self.interval = interval
        self.lookup = lookup
        self.deliver = deliver
        // Persist the reservation so relaunching cannot bypass the free API limit.
        nextLookup = defaults.object(forKey: "elevationNextLookup") as? Date ?? .distantPast
        observation = settings.$profile.sink { [weak self] profile in
            guard let self = self else { return }
            self.profile = profile
            self.cancelLookup()
            self.refresh()
        }
    }

    func receive(_ location: CLLocation) {
        activeLocation = location
        isActive = true
        refresh(reissue: false)
    }

    func stop() {
        cancelLookup()
        activeLocation = nil
        isActive = false
        currentMeters = nil
    }

    private func cancelLookup() {
        generation = UUID()
        task?.cancel()
        task = nil
    }

    private func cached(_ coordinate: CLLocationCoordinate2D) -> Double? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return cache.reversed().first {
            location.distance(from: CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)) <= 45
        }?.meters
    }

    private func refresh(reissue: Bool = true) {
        guard let location = activeLocation else { return }
        let meters = profile.mode == .custom ? profile.customMeters : cached(location.coordinate)
        currentMeters = meters
        deliver(Self.applying(meters, to: location, accuracy: profile.mode == .custom ? 1 : 90,
                              timestamp: reissue ? Date() : nil))
        guard profile.mode == .automatic, meters == nil, task == nil else { return }
        let token = generation
        task = Task { @MainActor [weak self] in
            guard let self = self else { return }
            while self.nextLookup > Date(), !Task.isCancelled {
                let delay = min(60, max(0, self.nextLookup.timeIntervalSinceNow))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled, self.generation == token,
                  let coordinate = self.activeLocation?.coordinate else { return }
            self.nextLookup = Date().addingTimeInterval(self.interval)
            self.defaults.set(self.nextLookup, forKey: "elevationNextLookup")
            let result = await self.lookup(coordinate)
            guard !Task.isCancelled, self.generation == token else { return }
            if let meters = result, meters.isFinite {
                self.cache.append((coordinate, meters))
                if self.cache.count > 2048 { self.cache.removeFirst() }
            } else {
                // Failed/offline lookups remain unknown; retry without hammering.
                self.nextLookup = Date().addingTimeInterval(max(60, self.interval))
                self.defaults.set(self.nextLookup, forKey: "elevationNextLookup")
            }
            self.task = nil
            // Reapply to the latest sample, never the sample that started the request.
            // A result for a place we have already left stays in the cache only.
            self.refresh()
        }
    }

    static func applying(_ meters: Double?, to location: CLLocation, accuracy: Double, timestamp: Date? = nil) -> CLLocation {
        let valid = meters?.isFinite == true
        return CLLocation(coordinate: location.coordinate, altitude: valid ? meters! : 0,
            horizontalAccuracy: location.horizontalAccuracy,
            // Core Location requires a numeric altitude; negative accuracy marks
            // that placeholder as unknown, never as a measured sea-level elevation.
            verticalAccuracy: valid ? max(1, accuracy) : -1,
            course: location.course, courseAccuracy: location.courseAccuracy,
            speed: location.speed, speedAccuracy: location.speedAccuracy, timestamp: timestamp ?? location.timestamp)
    }
}
