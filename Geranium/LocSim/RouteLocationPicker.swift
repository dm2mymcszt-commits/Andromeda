import SwiftUI
import MapKit

struct RoutePlace: Codable, Identifiable {
    var id = UUID()
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double

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

final class RoutePlaceSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" { didSet { updateSuggestions() } }
    @Published private(set) var suggestions: [MKLocalSearchCompletion] = []
    @Published private(set) var results: [MKMapItem] = []
    @Published private(set) var isSearching = false
    @Published private(set) var message: String?
    var region: MKCoordinateRegion?
    private var completer: MKLocalSearchCompleter?
    private var search: MKLocalSearch?
    private var debounce: DispatchWorkItem?
    private var generation = UUID()

    func cancel() {
        generation = UUID()
        debounce?.cancel()
        completer?.cancel()
        completer = nil
        search?.cancel()
        search = nil
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
            let completer = MKLocalSearchCompleter()
            completer.delegate = self
            completer.resultTypes = [.address, .pointOfInterest]
            if let region = self.region { completer.region = region }
            self.completer = completer
            completer.queryFragment = fragment
        }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard completer === self.completer else { return }
        suggestions = completer.results
        isSearching = false
        message = suggestions.isEmpty ? "No suggestions. Try a nearby town or choose on map." : nil
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        guard completer === self.completer else { return }
        isSearching = false
        message = "Search is unavailable. Check your connection or choose a recent place."
    }

    func searchAddress() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        perform(request, selection: nil)
    }

    func resolve(_ suggestion: MKLocalSearchCompletion, selection: @escaping (RoutePlace) -> Void) {
        perform(MKLocalSearch.Request(completion: suggestion), selection: selection)
    }

    private func perform(_ request: MKLocalSearch.Request, selection: ((RoutePlace) -> Void)?) {
        cancel()
        suggestions = []
        results = []
        message = nil
        isSearching = true
        if let region = region { request.region = region }
        let token = generation
        let search = MKLocalSearch(request: request)
        self.search = search
        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self = self, self.generation == token else { return }
                self.isSearching = false
                let items = response?.mapItems ?? []
                if let selection = selection, let item = items.first {
                    selection(RoutePlace(item))
                } else {
                    self.results = items
                    self.message = items.isEmpty ? "No places found. Try another search or choose on map." : nil
                }
            }
        }
    }
}

struct RouteLocationPicker: View {
    let title: String
    let region: MKCoordinateRegion?
    let selectedCoordinate: CLLocationCoordinate2D?
    @ObservedObject var recents: RouteRecentPlaces
    var useCurrentLocation: (() -> Void)?
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
                    ForEach(search.results, id: \.self) { item in
                        Button { choose(RoutePlace(item)) } label: {
                            placeRow(item.name ?? "Place", subtitle: item.placemark.title ?? "", icon: "mappin.circle")
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
        .onAppear { search.region = region }
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
    let region: MKCoordinateRegion?
    let selectedCoordinate: CLLocationCoordinate2D?
    @Binding var point: EquatableCoordinate?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
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
