import SwiftUI
import MapKit

struct PlaceMatch {
    var place: RoutePlace
    var quality: Int
    var order: Int

    init(place: RoutePlace, houseNumber: String?, query: String, exact: Bool, order: Int) {
        self.place = place
        self.order = order
        if AddressQuery.houseNumber(query) != nil, AddressQuery.isAddress(query) {
            let matches = AddressQuery.matchesHouse(houseNumber, query: query, address: place.address)
            let addressMatches = AddressQuery.matchesAddressText(query: query, result: place.name + ", " + place.address)
            quality = exact && matches && addressMatches ? 100 : 30
            self.place.approximate = quality < 100
        } else {
            quality = exact ? 80 : 30
            self.place.approximate = !exact
        }
    }
}

enum PlaceProvider {
    static let userAgent = "Andromeda/2.5 (https://github.com/dm2mymcszt-commits/Andromeda)"

    static func photonURL(_ query: String) -> URL {
        var components = URLComponents(string: "https://photon.komoot.io/api/")!
        components.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: "8")]
        return components.url!
    }

    static func nationalURL(_ query: String) -> URL? {
        guard query.range(of: #"\b\d{5}\b(?!-)"#, options: .regularExpression) != nil,
              query.range(of: #"\b(?:cours|rue|avenue|boulevard|chemin|impasse|allée|quai)\b"#,
                          options: [.regularExpression, .caseInsensitive]) != nil else { return nil }
        var components = URLComponents(string: "https://data.geopf.fr/geocodage/search")!
        components.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "index", value: "address"),
                                URLQueryItem(name: "limit", value: "5")]
        return components.url!
    }

    struct Response: Decodable {
        struct Feature: Decodable {
            struct Geometry: Decodable { let coordinates: [Double] }
            struct Properties: Decodable {
                let name: String?, label: String?, housenumber: String?, street: String?
                let city: String?, district: String?, state: String?, country: String?, postcode: String?
                let type: String?, score: Double?
            }
            let geometry: Geometry
            let properties: Properties
        }
        let features: [Feature]
    }

    static func decode(_ data: Data, query: String, national: Bool = false, order: Int = 20) throws -> [PlaceMatch] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.features.compactMap { feature in
            let p = feature.properties, coordinates = feature.geometry.coordinates
            guard coordinates.count >= 2, let wgs = PlaceInput.valid(coordinates[1], coordinates[0]) else { return nil }
            if national {
                guard (p.score ?? 0) >= 0.5 else { return nil }
                if let postcode = PlaceInput.captures(#"\b(\d{5})\b"#, query)?.first,
                   p.postcode != postcode { return nil }
            }
            let street = [p.housenumber, p.street].compactMap { $0 }.joined(separator: " ")
            let address = p.label ?? [street.isEmpty ? nil : street, p.district, p.city, p.postcode, p.state, p.country]
                .compactMap { $0 }.joined(separator: ", ")
            let name = p.name ?? (street.isEmpty ? (p.label ?? p.city ?? "Selected place") : street)
            let place = RoutePlace(name: name, address: address, coordinate: CoordTransform.wgs84ToGcj02(wgs))
            let house = p.housenumber ?? (national ? AddressQuery.houseNumber(p.label ?? "") : nil)
            let exact = national ? p.type == "housenumber" : !["street", "city", "district", "county", "state", "country", "locality"].contains(p.type ?? "")
            // A town is an exact result when the user is actually searching for a town.
            return PlaceMatch(place: place, houseNumber: house, query: query,
                              exact: exact || !AddressQuery.isAddress(query), order: order)
        }
    }

    static func apple(_ query: String, order: Int) async -> [PlaceMatch] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query // Full addresses never inherit the visible map region.
        var places: [MKMapItem] = []
        do { places = try await MKLocalSearch(request: request).start().mapItems } catch { }
        if places.isEmpty {
            do {
                places = try await CLGeocoder().geocodeAddressString(query)
                    .map { MKMapItem(placemark: MKPlacemark(placemark: $0)) }
            } catch { }
        }
        return places.map { item in
            PlaceMatch(place: RoutePlace(item), houseNumber: item.placemark.subThoroughfare,
                       query: query, exact: item.placemark.thoroughfare != nil || !AddressQuery.isAddress(query), order: order)
        }
    }

    static func national(_ query: String) async -> [PlaceMatch] {
        guard let url = nationalURL(query) else { return [] }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { return [] }
            return try decode(data, query: query, national: true, order: 0)
        } catch { return [] }
    }
}

// Shared across pickers: cache repeated queries and issue at most one Photon
// request every 1.25 seconds. Canceled keystrokes do not issue queued requests.
actor PhotonSearch {
    static let shared = PhotonSearch()
    private var cache: [String: (Date, Data)] = [:]
    private var lastRequest = Date.distantPast

    func search(_ query: String, order: Int) async -> [PlaceMatch] {
        do {
            if let (date, data) = cache[query], Date().timeIntervalSince(date) < 86400 {
                return try PlaceProvider.decode(data, query: query, order: order)
            }
            while Date().timeIntervalSince(lastRequest) < 1.25 {
                let wait = 1.25 - Date().timeIntervalSince(lastRequest)
                try await Task.sleep(nanoseconds: UInt64(max(0.01, wait) * 1_000_000_000))
            }
            try Task.checkCancellation()
            lastRequest = Date()
            var request = URLRequest(url: PlaceProvider.photonURL(query))
            request.timeoutInterval = 12
            request.setValue(PlaceProvider.userAgent, forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { return [] }
            let places = try PlaceProvider.decode(data, query: query, order: order)
            if cache.count >= 128 { cache.removeValue(forKey: cache.min { $0.value.0 < $1.value.0 }!.key) }
            cache[query] = (Date(), data)
            return places
        } catch { return [] }
    }
}

enum WorldwidePlaceSearch {
    static func merge(_ matches: [PlaceMatch]) -> [RoutePlace] {
        let sorted = matches.enumerated().sorted {
            if $0.element.quality != $1.element.quality { return $0.element.quality > $1.element.quality }
            if $0.element.order != $1.element.order { return $0.element.order < $1.element.order }
            return $0.offset < $1.offset
        }.map(\.element.place)
        var unique: [RoutePlace] = []
        for place in sorted {
            let duplicate = unique.contains { other in
                let distance = CLLocation(latitude: place.latitude, longitude: place.longitude)
                    .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
                return distance < 30 && (AddressQuery.canonical(place.name) == AddressQuery.canonical(other.name)
                    || AddressQuery.canonical(place.address) == AddressQuery.canonical(other.address))
            }
            if !duplicate { unique.append(place) }
        }
        return Array(unique.prefix(16))
    }

    static func search(_ text: String, suggestionsOnly: Bool = false) async -> [RoutePlace] {
        let variants = AddressQuery.variants(text)
        var matches = await withTaskGroup(of: [PlaceMatch].self, returning: [PlaceMatch].self) { group in
            if !suggestionsOnly {
                for (index, query) in variants.enumerated() {
                    group.addTask { await PlaceProvider.apple(query, order: 10 + index) }
                }
                if let normalized = variants.dropFirst().first ?? variants.first {
                    group.addTask { await PlaceProvider.national(normalized) }
                }
            }
            // Use expanded spellings for the OSM source too, keeping the original
            // as a separate query. Serial rate limiting is enforced by its actor.
            for (index, query) in (suggestionsOnly ? [text] : variants).enumerated() {
                group.addTask { await PhotonSearch.shared.search(query, order: 20 + index) }
            }
            var collected: [PlaceMatch] = []
            for await result in group { collected += result }
            return collected
        }
        if !suggestionsOnly, matches.isEmpty, text.contains(","), !Task.isCancelled {
            let town = text.split(separator: ",").dropFirst().joined(separator: ",")
            matches = await PlaceProvider.apple(town, order: 90)
            for index in matches.indices { matches[index].place.approximate = true; matches[index].quality = 0 }
        }
        if ProcessInfo.processInfo.environment["LIVE_ADDRESS_LOOKUP"] == "1" {
            for match in matches {
                print("MATCH \(text) | \(match.order)/\(match.quality) | \(match.place.name) | \(match.place.address) | \(match.place.latitude),\(match.place.longitude)")
            }
            fflush(stdout)
        }
        return Task.isCancelled ? [] : merge(matches)
    }

    static func resolve(_ input: PlaceInput) async throws -> [RoutePlace] {
        switch input {
        case .coordinate(let coordinate): return [.pasted(coordinate)]
        case .text(let text): return await search(text)
        case .plusCode(let code, let town):
            guard !town.isEmpty else { throw SearchError.message("Add a nearby town after this short plus code.") }
            guard let reference = await search(town).first,
                  let coordinate = OpenLocationCode.recover(code, near: CoordTransform.gcj02ToWgs84(reference.coordinate)) else {
                throw SearchError.message("Couldn't find the town for this plus code. Try its full code.")
            }
            return [.pasted(coordinate)]
        case .link(let url):
            let link = try await MapLinkResolver().resolve(url)
            if let coordinate = link.coordinate { return [.pasted(coordinate)] }
            if let query = link.query {
                let parsed = PlaceInput.parse(query)
                if case .link = parsed { throw SearchError.message("This link does not contain a place.") }
                let matches = try await resolve(parsed)
                if let first = matches.first { return [first] }
            }
            if let camera = link.camera { return [.pasted(camera, approximate: true)] }
            throw SearchError.message("This link has no readable location. Copy the place's coordinates or plus code from Maps.")
        }
    }
}

enum SearchError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

final class RoutePlaceSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" { didSet { updateSuggestions() } }
    @Published private(set) var suggestions: [MKLocalSearchCompletion] = []
    @Published private(set) var results: [RoutePlace] = []
    @Published private(set) var isSearching = false
    @Published private(set) var message: String?
    var region: MKCoordinateRegion?
    private var completer: MKLocalSearchCompleter?
    private var work: Task<Void, Never>?
    private var generation = UUID()

    func cancel() {
        generation = UUID()
        work?.cancel(); work = nil
        completer?.cancel(); completer = nil
        isSearching = false
    }

    private func updateSuggestions() {
        cancel()
        suggestions = []; results = []; message = nil
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let input = PlaceInput.parse(text)
        if case .coordinate(let coordinate) = input { results = [.pasted(coordinate)]; return }
        guard case .text = input else { perform(input); return }
        let token = generation
        isSearching = true
        work = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 650_000_000) } catch { return }
            await MainActor.run {
                guard let self = self, self.generation == token else { return }
                if AddressQuery.isAddress(text) { self.perform(.text(text)); return }
                let completer = MKLocalSearchCompleter()
                completer.delegate = self
                completer.resultTypes = [.address, .pointOfInterest]
                if let region = self.region { completer.region = region }
                self.completer = completer
                completer.queryFragment = text
            }
            guard !AddressQuery.isAddress(text), !Task.isCancelled else { return }
            let places = await WorldwidePlaceSearch.search(text, suggestionsOnly: true)
            await MainActor.run {
                guard let self = self, self.generation == token else { return }
                self.results = places; self.isSearching = false
            }
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard completer === self.completer else { return }
        suggestions = completer.results
    }
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        guard completer === self.completer else { return }
        suggestions = [] // Worldwide results still arrive independently.
    }
    func searchAddress() { perform(PlaceInput.parse(query)) }

    private func perform(_ input: PlaceInput) {
        cancel()
        suggestions = []; results = []; message = nil; isSearching = true
        let token = generation
        work = Task { [weak self] in
            do {
                let places = try await WorldwidePlaceSearch.resolve(input)
                await MainActor.run {
                    guard let self = self, self.generation == token else { return }
                    self.results = places; self.isSearching = false
                    if places.isEmpty { self.message = "No matching places. Try a nearby street or town, or paste a Maps link or coordinates." }
                }
            } catch {
                await MainActor.run {
                    guard let self = self, self.generation == token else { return }
                    self.isSearching = false
                    self.message = (error as? SearchError)?.localizedDescription ?? "Couldn't resolve this location. Check your connection and try again."
                }
            }
        }
    }

    func resolve(_ suggestion: MKLocalSearchCompletion, selection: @escaping (RoutePlace) -> Void) {
        cancel(); isSearching = true
        let token = generation
        work = Task { [weak self] in
            do {
                let response = try await MKLocalSearch(request: MKLocalSearch.Request(completion: suggestion)).start()
                await MainActor.run {
                    guard let self = self, self.generation == token else { return }
                    self.isSearching = false
                    if let item = response.mapItems.first { selection(RoutePlace(item)) }
                    else { self.message = "Couldn't locate this suggestion. Search its full name and address." }
                }
            } catch {
                await MainActor.run {
                    guard let self = self, self.generation == token else { return }
                    self.isSearching = false; self.message = "Couldn't locate this suggestion. Try its full address."
                }
            }
        }
    }
}
