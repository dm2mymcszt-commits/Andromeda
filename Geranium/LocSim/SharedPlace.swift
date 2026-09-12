import SwiftUI
import CoreLocation

enum SharedPlaceAction: String, Codable, CaseIterable, Identifiable {
    case go, start, destination, favorite
    var id: String { rawValue }
    var title: String {
        switch self {
        case .go: return "Go there now"
        case .start: return "Use as route start"
        case .destination: return "Use as route destination"
        case .favorite: return "Save as favorite"
        }
    }
    var icon: String {
        switch self {
        case .go: return "location.fill"
        case .start: return "a.circle"
        case .destination: return "b.circle"
        case .favorite: return "star"
        }
    }
}

// Transfers are WGS-84, just like Favorites. Map-space coordinates never cross
// the extension boundary. One atomic file per request avoids lost queue writes.
struct SharedPlaceRequest: Codable, Identifiable {
    let id: UUID
    let created: Date
    let action: SharedPlaceAction
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let approximate: Bool

    init(place: RoutePlace, action: SharedPlaceAction) {
        id = UUID(); created = Date(); self.action = action
        name = place.name; address = place.address; approximate = place.isApproximate
        let coordinate = CoordTransform.gcj02ToWgs84(place.coordinate)
        latitude = coordinate.latitude; longitude = coordinate.longitude
    }

    var place: RoutePlace? {
        guard let wgs = PlaceInput.valid(latitude, longitude) else { return nil }
        var place = RoutePlace(name: name, address: address, coordinate: CoordTransform.wgs84ToGcj02(wgs))
        place.approximate = approximate
        return place
    }
}

struct SharedPlaceInbox {
    static let suite = "group.live.cclerc.geraniumBookmarks"
    let directory: URL?

    init(container: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suite)) {
        directory = container?.appendingPathComponent("SharedPlaces", isDirectory: true)
    }

    func enqueue(_ request: SharedPlaceRequest) throws {
        guard let directory = directory, request.place != nil else {
            throw SearchError.message("Couldn't access Andromeda's shared storage. Open Andromeda once, then try sharing again.")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(request).write(to: directory.appendingPathComponent(request.id.uuidString + ".json"), options: .atomic)
    }

    func pending() -> [SharedPlaceRequest] {
        guard let directory = directory,
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == "json" }.compactMap { file in
            guard let data = try? Data(contentsOf: file),
                  let request = try? JSONDecoder().decode(SharedPlaceRequest.self, from: data),
                  request.place != nil, file.deletingPathExtension().lastPathComponent == request.id.uuidString else { return nil }
            return request
        }.sorted { $0.created < $1.created }
    }

    func remove(_ request: SharedPlaceRequest) throws {
        guard let directory = directory else { return }
        try FileManager.default.removeItem(at: directory.appendingPathComponent(request.id.uuidString + ".json"))
    }

    static func saveFavorite(_ place: RoutePlace, defaults: UserDefaults? = UserDefaults(suiteName: suite)) throws {
        guard let defaults = defaults else { throw SearchError.message("Couldn't access Favorites. Open Andromeda once and try again.") }
        let coordinate = CoordTransform.gcj02ToWgs84(place.coordinate)
        guard CLLocationCoordinate2DIsValid(coordinate) else { throw SearchError.message("Invalid location.") }
        var bookmarks = defaults.array(forKey: "bookmarks") as? [[String: Any]] ?? []
        bookmarks.append(["name": place.name, "lat": coordinate.latitude, "long": coordinate.longitude])
        defaults.set(bookmarks, forKey: "bookmarks")
    }
}

final class RouteDraft: ObservableObject {
    @Published var start: RoutePlace?
    @Published var destination: RoutePlace?
    // A shared endpoint invalidates a previous preview when the planner opens.
    var needsRecalculation = false

    @discardableResult
    func swapEndpoints() -> Bool {
        guard let oldStart = start, let oldDestination = destination else { return false }
        start = oldDestination
        destination = oldStart
        needsRecalculation = true
        return true
    }

    func accept(_ request: SharedPlaceRequest) {
        guard let place = request.place else { return }
        if request.action == .start { start = place }
        else if request.action == .destination { destination = place }
        else { return }
        needsRecalculation = true
    }
}

#if os(iOS)
struct IncomingPlaceView: View {
    let request: SharedPlaceRequest
    let routeRunning: Bool
    let accept: () -> Void
    let cancel: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Shared place") {
                    Text(request.name).font(.headline)
                    if !request.address.isEmpty && PlaceInput.coordinates(request.address) == nil { Text(request.address) }
                    Text(String(format: "%.5f, %.5f", request.latitude, request.longitude)).foregroundColor(.secondary)
                    if request.approximate { Text("Approximate").foregroundColor(.secondary) }
                }
                Section {
                    Button(action: accept) { Label(request.action.title, systemImage: request.action.icon) }
                } footer: {
                    if routeRunning && request.action == .go {
                        Text("Moving here will stop the current route.")
                    } else if routeRunning && (request.action == .start || request.action == .destination) {
                        Text("The current route keeps running. This place will be ready in the route planner after you stop it.")
                    }
                }
            }
            .navigationTitle("From Maps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: cancel) } }
        }
    }
}
#endif
