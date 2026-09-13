import SwiftUI
import MapKit

struct RoutePlace: Codable, Identifiable {
    var id = UUID()
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    var approximate: Bool? = nil

    var isApproximate: Bool { approximate == true }

    static func pasted(_ wgs: CLLocationCoordinate2D, approximate: Bool = false) -> RoutePlace {
        var place = RoutePlace(name: "Pasted location",
                              address: String(format: "%.5f, %.5f", wgs.latitude, wgs.longitude),
                              coordinate: CoordTransform.wgs84ToGcj02(wgs))
        place.approximate = approximate
        return place
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(name: String, address: String = "", coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.address = address
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    init(_ item: MKMapItem) {
        self.init(name: item.name ?? "Selected place", address: item.placemark.title ?? "",
                  coordinate: item.placemark.coordinate)
    }
}

enum RouteFavoritePlaces {
    static func places(from bookmarks: [[String: Any]]) -> [RoutePlace] {
        bookmarks.compactMap { bookmark in
            guard let latitude = bookmark["lat"] as? Double,
                  let longitude = bookmark["long"] as? Double else { return nil }
            let wgs = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            guard CLLocationCoordinate2DIsValid(wgs) else { return nil }
            let name = (bookmark["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return RoutePlace(name: name.isEmpty ? "Favorite" : name,
                              address: String(format: "%.5f, %.5f", latitude, longitude),
                              coordinate: CoordTransform.wgs84ToGcj02(wgs))
        }
    }

    static func matching(_ places: [RoutePlace], query: String) -> [RoutePlace] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return places }
        return places.filter {
            $0.name.range(of: text, options: [.caseInsensitive, .diacriticInsensitive],
                          locale: .current) != nil
        }
    }
}

final class RouteRecentPlaces: ObservableObject {
    @Published private(set) var places: [RoutePlace]
    private let defaults: UserDefaults
    private let key = "routeRecentPlaces.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        places = defaults.data(forKey: key)
            .flatMap { try? JSONDecoder().decode([RoutePlace].self, from: $0) } ?? []
        places = Array(places.filter { CLLocationCoordinate2DIsValid($0.coordinate) }.prefix(12))
    }

    func remember(_ place: RoutePlace) {
        guard CLLocationCoordinate2DIsValid(place.coordinate) else { return }
        places.removeAll {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(
                from: CLLocation(latitude: place.latitude, longitude: place.longitude)) < 10
        }
        places.insert(place, at: 0)
        places = Array(places.prefix(12))
        save()
    }

    func remove(_ place: RoutePlace) {
        places.removeAll { $0.id == place.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(places) { defaults.set(data, forKey: key) }
    }
}

final class RouteCurrentLocation: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var isLocating = false
    @Published private(set) var message: String?
    private let manager = CLLocationManager()
    private var timeout: DispatchWorkItem?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func request() {
        cancel()
        message = nil
        isLocating = true
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: locate()
        default: fail("Location access is off. Enable it in Settings, or choose a start point.")
        }
    }

    func cancel() {
        timeout?.cancel()
        timeout = nil
        manager.stopUpdatingLocation()
        isLocating = false
    }

    private func locate() {
        timeout?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.fail("Couldn't get your location. Retry, search, or choose on map.")
        }
        timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: work)
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isLocating else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: locate()
        case .denied, .restricted:
            fail("Location access is off. Enable it in Settings, or choose a start point.")
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isLocating, let fix = locations.last,
              fix.horizontalAccuracy >= 0, abs(fix.timestamp.timeIntervalSinceNow) < 60,
              CLLocationCoordinate2DIsValid(fix.coordinate) else { return }
        cancel()
        location = fix
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard isLocating else { return }
        fail("Couldn't get your location. Retry, search, or choose on map.")
    }

    private func fail(_ text: String) {
        cancel()
        message = text
    }
}

