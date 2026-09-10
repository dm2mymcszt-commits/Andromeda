import SwiftUI
import MapKit

struct RoutePlace: Codable, Identifiable {
    var id = UUID()
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    var source: String? = nil

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

enum FrenchAddressLookup {
    static func isAddress(_ text: String) -> Bool {
        text.range(of: #"\b\d{5}\b"#, options: .regularExpression) != nil
            && text.range(of: #"\b(cr|crs|cours|rue|avenue|av|boulevard|bd|chemin|impasse|route|place|allée|allee|quai)\b"#,
                          options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func normalized(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAddress(trimmed) else { return trimmed }
        return trimmed.replacingOccurrences(
            of: #"^(\d+[a-z]?(?:\s+(?:bis|ter))?\s+)(?:cr|crs)\.?\s+"#,
            with: "$1Cours ", options: [.regularExpression, .caseInsensitive])
    }

    static func url(for query: String) -> URL {
        var components = URLComponents(string: "https://data.geopf.fr/geocodage/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: normalized(query)),
            URLQueryItem(name: "index", value: "address"),
            URLQueryItem(name: "limit", value: "5")
        ]
        return components.url!
    }

    private struct Response: Decodable {
        struct Feature: Decodable {
            struct Geometry: Decodable { let coordinates: [Double] }
            struct Properties: Decodable {
                let label: String
                let name: String?
                let score: Double?
                let type: String?
                let postcode: String?
            }
            let geometry: Geometry
            let properties: Properties
        }
        let features: [Feature]
    }

    static func decode(_ data: Data, query: String) throws -> [RoutePlace] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let postcode = query.range(of: #"\b\d{5}\b"#, options: .regularExpression).map { String(query[$0]) }
        return response.features.compactMap { feature in
            let properties = feature.properties
            let coordinates = feature.geometry.coordinates
            guard coordinates.count == 2, (properties.score ?? 0) >= 0.5,
                  postcode == nil || properties.postcode == postcode else { return nil }
            let coordinate = CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
            guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
            var place = RoutePlace(name: properties.name ?? properties.label,
                                   address: properties.label, coordinate: coordinate)
            place.source = properties.type == "housenumber" ? "IGN / BAN"
                : "IGN / BAN · Area or street-level match"
            return place
        }
    }
}

final class RoutePlaceSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" { didSet { updateSuggestions() } }
    @Published private(set) var suggestions: [MKLocalSearchCompletion] = []
    @Published private(set) var results: [RoutePlace] = []
    @Published private(set) var isSearching = false
    @Published private(set) var message: String?
    var region: MKCoordinateRegion?
    private var completer: MKLocalSearchCompleter?
    private var search: MKLocalSearch?
    private var debounce: DispatchWorkItem?
    private var generation = UUID()
    private var addressTask: URLSessionDataTask?
    private let geocoder = CLGeocoder()
    private var pendingLookups = 0
    private var lookupFailed = false
    private var suggestionTimeout: DispatchWorkItem?

    func cancel() {
        generation = UUID()
        debounce?.cancel()
        suggestionTimeout?.cancel()
        completer?.cancel()
        completer = nil
        search?.cancel()
        search = nil
        addressTask?.cancel()
        addressTask = nil
        geocoder.cancelGeocode()
        pendingLookups = 0
        isSearching = false
    }

    private func updateSuggestions() {
        cancel()
        suggestions = []
        results = []
        message = nil
        let fragment = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fragment.isEmpty else { return }
        isSearching = true
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            // A complete postal address deserves a lookup, even without completions.
            if FrenchAddressLookup.isAddress(fragment) {
                self.searchAddress()
                return
            }
            let completer = MKLocalSearchCompleter()
            completer.delegate = self
            completer.resultTypes = [.address, .pointOfInterest]
            if let region = self.region { completer.region = region }
            self.completer = completer
            completer.queryFragment = fragment
            let timeout = DispatchWorkItem { [weak self, weak completer] in
                guard let self = self, let completer = completer,
                      self.completer === completer else { return }
                self.searchAddress()
            }
            self.suggestionTimeout = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeout)
        }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard completer === self.completer else { return }
        suggestionTimeout?.cancel()
        suggestions = completer.results
        isSearching = false
        if suggestions.isEmpty { searchAddress() }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        guard completer === self.completer else { return }
        searchAddress()
    }

    func searchAddress() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = FrenchAddressLookup.normalized(text)
        perform(request, text: text, selection: nil)
    }

    func resolve(_ suggestion: MKLocalSearchCompletion, selection: @escaping (RoutePlace) -> Void) {
        perform(MKLocalSearch.Request(completion: suggestion),
                text: suggestion.title + " " + suggestion.subtitle, selection: selection)
    }

    private func perform(_ request: MKLocalSearch.Request, text: String, selection: ((RoutePlace) -> Void)?) {
        cancel()
        suggestions = []
        results = []
        message = nil
        isSearching = true
        lookupFailed = false
        if !FrenchAddressLookup.isAddress(text), let region = region { request.region = region }
        let token = generation
        let useFrench = FrenchAddressLookup.isAddress(text)
            && (UserDefaults.standard.object(forKey: "frenchAddressLookup") as? Bool ?? true)
        pendingLookups = useFrench ? 2 : 1
        if useFrench { lookupFrenchAddress(text, token: token) }
        let search = MKLocalSearch(request: request)
        self.search = search
        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self = self, self.generation == token else { return }
                let items = response?.mapItems ?? []
                if let selection = selection, let item = items.first {
                    self.cancel()
                    selection(RoutePlace(item))
                } else if !items.isEmpty {
                    self.merge(items.map(RoutePlace.init))
                    self.finishLookup(failed: false)
                } else {
                    // Geocoding handles complete addresses that place search misses.
                    self.geocoder.geocodeAddressString(FrenchAddressLookup.normalized(text)) { [weak self] placemarks, geocodeError in
                        DispatchQueue.main.async {
                            guard let self = self, self.generation == token else { return }
                            self.merge((placemarks ?? []).compactMap { placemark in
                                guard let coordinate = placemark.location?.coordinate,
                                      CLLocationCoordinate2DIsValid(coordinate) else { return nil }
                                return RoutePlace(MKMapItem(placemark: MKPlacemark(placemark: placemark)))
                            })
                            self.finishLookup(failed: error != nil && geocodeError != nil)
                        }
                    }
                }
            }
        }
    }

    private func lookupFrenchAddress(_ text: String, token: UUID) {
        var request = URLRequest(url: FrenchAddressLookup.url(for: text))
        request.timeoutInterval = 12
        addressTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let places = data.flatMap { try? FrenchAddressLookup.decode($0, query: text) }
            DispatchQueue.main.async {
                guard let self = self, self.generation == token else { return }
                let valid = error == nil && (200..<300).contains(status) && places != nil
                if valid { self.merge(places ?? [], prefer: true) }
                self.finishLookup(failed: !valid)
            }
        }
        addressTask?.resume()
    }

    private func merge(_ places: [RoutePlace], prefer: Bool = false) {
        var unique: [RoutePlace] = []
        for place in (prefer ? places + results : results + places) {
            guard CLLocationCoordinate2DIsValid(place.coordinate) else { continue }
            if !unique.contains(where: {
                $0.name.caseInsensitiveCompare(place.name) == .orderedSame
                    && (Self.samePostalAddress($0.address, place.address)
                        || CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(
                            from: CLLocation(latitude: place.latitude, longitude: place.longitude)) < 30)
            }) { unique.append(place) }
        }
        results = Array(unique.prefix(12))
    }

    static func samePostalAddress(_ first: String, _ second: String) -> Bool {
        guard FrenchAddressLookup.isAddress(first), FrenchAddressLookup.isAddress(second) else { return false }
        func canonical(_ address: String) -> String {
            FrenchAddressLookup.normalized(address).lowercased()
                .replacingOccurrences(of: ",", with: " ")
                .replacingOccurrences(of: #"\s+france\s*$"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return canonical(first) == canonical(second)
    }

    private func finishLookup(failed: Bool) {
        lookupFailed = lookupFailed || failed
        pendingLookups = max(0, pendingLookups - 1)
        isSearching = pendingLookups > 0
        if !isSearching && results.isEmpty {
            message = lookupFailed ? "Search couldn't finish. Check your connection and try again."
                : "No matching places. Check the street number and town, or choose on map."
        }
    }
}

struct RouteLocationPicker: View {
    let title: String
    let region: MKCoordinateRegion?
    let selectedCoordinate: CLLocationCoordinate2D?
    @ObservedObject var recents: RouteRecentPlaces
    var useCurrentLocation: (() -> Void)?
    var initialQuery: String = ""
    let select: (RoutePlace) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var search = RoutePlaceSearch()
    @State private var showMap = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    if let useCurrentLocation = useCurrentLocation {
                        Button {
                            useCurrentLocation()
                            dismiss()
                        } label: { Label("Use Current Location", systemImage: "location.fill") }
                    }
                    Button {
                        search.cancel()
                        showMap = true
                    } label: { Label("Choose on Map", systemImage: "map") }
                }
                if search.isSearching { ProgressView("Searching…") }
                if let message = search.message { Text(message).foregroundColor(.secondary) }
                if !search.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button { search.searchAddress() } label: {
                        Label("Search full address", systemImage: "magnifyingglass")
                    }
                    .disabled(search.isSearching)
                }
                if search.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("Recent Places") {
                        if recents.places.isEmpty {
                            Text("Places you choose here will appear here next time.")
                                .foregroundColor(.secondary)
                        }
                        ForEach(recents.places) { place in
                            HStack {
                                Button { choose(place) } label: {
                                    placeRow(place.name, subtitle: place.address, icon: "clock")
                                }
                                .buttonStyle(.borderless)
                                Button { recents.remove(place) } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Remove \(place.name) from recent places")
                            }
                        }
                    }
                } else {
                    ForEach(search.suggestions, id: \.self) { suggestion in
                        Button {
                            search.resolve(suggestion, selection: choose)
                        } label: {
                            placeRow(suggestion.title, subtitle: suggestion.subtitle, icon: "mappin.circle")
                        }
                    }
                    ForEach(search.results) { place in
                        Button { choose(place) } label: {
                            placeRow(place.name, subtitle: [place.address, place.source].compactMap { $0 }.joined(separator: "\n"), icon: "mappin.circle")
                        }
                    }
                }
            }
            .searchable(text: $search.query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search address or place")
            .onSubmit(of: .search) { search.searchAddress() }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .sheet(isPresented: $showMap) {
                RouteMapPicker(title: title, region: region, selectedCoordinate: selectedCoordinate,
                               select: choose)
            }
        }
        .onAppear {
            search.region = region
            if search.query.isEmpty && !initialQuery.isEmpty { search.query = initialQuery }
        }
        .onDisappear { search.cancel() }
    }

    private func choose(_ place: RoutePlace) {
        search.cancel()
        select(place)
        dismiss()
    }

    private func placeRow(_ name: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(name).foregroundColor(.primary)
                if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundColor(.secondary) }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct RouteMapPicker: View {
    let title: String
    let region: MKCoordinateRegion?
    let selectedCoordinate: CLLocationCoordinate2D?
    let select: (RoutePlace) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var point: EquatableCoordinate?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text("Move and zoom the map, then tap your \(title.lowercased()).")
                    .font(.subheadline).foregroundColor(.secondary).padding()
                RouteSelectionMap(region: region, selectedCoordinate: selectedCoordinate, point: $point)
                VStack(spacing: 10) {
                    if let point = point {
                        Text(String(format: "%.5f, %.5f", point.coordinate.latitude, point.coordinate.longitude))
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Button {
                        guard let point = point else { return }
                        select(RoutePlace(name: "Map pin", address: String(format: "%.5f, %.5f",
                            point.coordinate.latitude, point.coordinate.longitude), coordinate: point.coordinate))
                        dismiss()
                    } label: {
                        Text("Use as \(title)").frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(point == nil)
                }
                .padding()
            }
            .navigationTitle("Choose on Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// This map only selects a coordinate. It never starts or changes location simulation.
private struct RouteSelectionMap: UIViewRepresentable {
    @AppStorage("mapStyle") private var mapStyle = "standard"
    let region: MKCoordinateRegion?
    let selectedCoordinate: CLLocationCoordinate2D?
    @Binding var point: EquatableCoordinate?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.mapType = mapStyle == "hybrid" ? .hybrid : .standard
        map.showsUserLocation = true
        if let coordinate = selectedCoordinate {
            map.setRegion(MKCoordinateRegion(center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)), animated: false)
        } else if let region = region {
            map.setRegion(region, animated: false)
        }
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        tap.cancelsTouchesInView = false
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        if let point = point {
            if let pin = context.coordinator.pin {
                pin.coordinate = point.coordinate
            } else {
                let pin = MKPointAnnotation()
                pin.coordinate = point.coordinate
                pin.title = "Selected point"
                map.addAnnotation(pin)
                context.coordinator.pin = pin
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject {
        var parent: RouteSelectionMap
        var pin: MKPointAnnotation?
        init(_ parent: RouteSelectionMap) { self.parent = parent }
        @objc func tap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let map = gesture.view as? MKMapView else { return }
            parent.point = EquatableCoordinate(coordinate: map.convert(gesture.location(in: map), toCoordinateFrom: map))
        }
    }
}
