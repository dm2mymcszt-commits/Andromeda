import SwiftUI
import MapKit

// Simulator-only app. The route geometry and displayed estimates below are synthetic
// Bordeaux fixtures, not live directions or traffic results. Both views are production code.
struct EquatableCoordinate: Equatable {
    let coordinate: CLLocationCoordinate2D
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

enum BordeauxFixture {
    static let etas = ["24 min", "31 min", "42 min"]
    static let distances = ["24.1 km", "24.3 km", "13.2 km"]
    static let simulations = ["19m 18s", "19m 26s", "10m 34s"]
    static let roads = ["A630 · Pont d'Aquitaine", "A630 · Mérignac", "Bordeaux centre"]

    static func routes(latitudeOffset: Double = 0) -> [MKPolyline] {
        let paths: [[(Double, Double)]] = [
            [(44.805, -0.553), (44.795, -0.536), (44.836, -0.516), (44.876, -0.520),
             (44.901, -0.532), (44.910, -0.548), (44.902, -0.575), (44.908, -0.606),
             (44.914, -0.645), (44.897, -0.657), (44.882, -0.652)],
            [(44.805, -0.553), (44.784, -0.566), (44.787, -0.598), (44.802, -0.619),
             (44.801, -0.646), (44.812, -0.676), (44.840, -0.687), (44.867, -0.680),
             (44.882, -0.652)],
            [(44.805, -0.553), (44.819, -0.574), (44.820, -0.598), (44.838, -0.606),
             (44.856, -0.611), (44.867, -0.630), (44.882, -0.652)]
        ]
        return paths.map { path in
            let coordinates = path.map { CLLocationCoordinate2D(latitude: $0.0 + latitudeOffset, longitude: $0.1) }
            return MKPolyline(coordinates: coordinates, count: coordinates.count)
        }
    }
}

private struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

// MapKit is permitted to request its renderer synchronously during insertion. Force
// that timing to guard against the original stale route identity / all-blue bug.
private final class InsertionProbeMap: MKMapView {
    struct Capture {
        let polyline: MKPolyline
        let color: UIColor?
        let width: CGFloat
        let alpha: CGFloat
    }
    var captures: [Capture] = []

    override func addOverlay(_ overlay: MKOverlay, level: MKOverlayLevel) {
        if let polyline = overlay as? MKPolyline,
           let renderer = delegate?.mapView?(self, rendererFor: overlay) as? MKPolylineRenderer {
            captures.append(Capture(polyline: polyline, color: renderer.strokeColor,
                                    width: renderer.lineWidth, alpha: renderer.alpha))
        }
        super.addOverlay(overlay, level: level)
    }
}

@MainActor private enum RouteMapChecks {
    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw CheckFailure(description: message) }
    }

    private static func sameCoordinate(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        abs(a.latitude - b.latitude) < 0.000001 && abs(a.longitude - b.longitude) < 0.000001
    }

    static func run() throws -> String {
        var location: EquatableCoordinate?
        var selections: [Int] = []
        let originalRoutes = BordeauxFixture.routes()
        var parent = CustomMapView(
            tappedCoordinate: Binding(get: { location }, set: { location = $0 }),
            moveToRegion: .constant(nil), allRoutePolylines: originalRoutes,
            selectedRouteIndex: 1, routeETAs: BordeauxFixture.etas,
            allowsLocationSelection: false, onSelectRoute: { selections.append($0) },
            fitsRoutes: true, showsUserLocation: false
        )
        let map = InsertionProbeMap(frame: CGRect(x: 0, y: 0, width: 358, height: 340))
        let coordinator = parent.makeCoordinator()
        map.delegate = coordinator
        coordinator.updateRoutes(on: map)
        try assertRoutes(map, coordinator: coordinator, routes: originalRoutes, selected: 1)
        try assertAnnotations(map, coordinator: coordinator, routes: originalRoutes,
                              selected: 1, etas: BordeauxFixture.etas)

        // Selection updates existing geometry, ordering, endpoint markers and badge state.
        parent.selectedRouteIndex = 2
        coordinator.parent = parent
        map.captures.removeAll()
        coordinator.updateRoutes(on: map)
        try assertRoutes(map, coordinator: coordinator, routes: originalRoutes, selected: 2)
        try assertAnnotations(map, coordinator: coordinator, routes: originalRoutes,
                              selected: 2, etas: BordeauxFixture.etas)

        // Recalculation can return the same number of routes and vertices at new locations.
        let replacementRoutes = BordeauxFixture.routes(latitudeOffset: 0.02)
        parent.allRoutePolylines = replacementRoutes
        coordinator.parent = parent
        map.captures.removeAll()
        coordinator.updateRoutes(on: map)
        try assertRoutes(map, coordinator: coordinator, routes: replacementRoutes, selected: 2)
        try assertAnnotations(map, coordinator: coordinator, routes: replacementRoutes,
                              selected: 2, etas: BordeauxFixture.etas)
        try require(!map.overlays.contains { overlay in originalRoutes.contains { $0 === overlay as AnyObject } },
                    "Recalculation retained obsolete route geometry")

        // ETA-only changes must refresh badges without changing the underlying routes.
        parent.routeETAs = ["25 min", "32 min", "43 min"]
        coordinator.parent = parent
        coordinator.updateRoutes(on: map)
        try assertAnnotations(map, coordinator: coordinator, routes: replacementRoutes,
                              selected: 2, etas: parent.routeETAs)

        let badge = map.annotations.compactMap { $0 as? RouteBadgeAnnotation }.first { $0.routeIndex == 0 }!
        let badgeView = coordinator.mapView(map, viewFor: badge)!
        coordinator.mapView(map, didSelect: badgeView)
        try require(selections == [0], "Numbered badge did not select its matching route")

        // Exercise the production polyline hit test at a uniquely routed segment.
        // Annotations are removed only from this test map so they cannot intercept the sample tap.
        map.removeAnnotations(map.annotations)
        let route = replacementRoutes[1]
        let midpoint = MKMapPoint(x: (route.points()[4].x + route.points()[5].x) / 2,
                                  y: (route.points()[4].y + route.points()[5].y) / 2).coordinate
        coordinator.handleMapTap(at: map.convert(midpoint, toPointTo: map), on: map)
        try require(selections == [0, 1], "Tapping an alternative line did not select that route")
        try require(location == nil, "Route selection unexpectedly changed the simulated location")
        coordinator.handleMapTap(at: CGPoint(x: 5, y: 5), on: map)
        try require(location == nil, "The route preview allowed a background tap to select a location")

        // Removing all routes must remove both overlays and their map labels.
        parent.allRoutePolylines = []
        coordinator.parent = parent
        coordinator.updateRoutes(on: map)
        try require(map.overlays.isEmpty, "Clearing routes left stale map lines")
        try require(map.annotations.filter { !($0 is MKUserLocation) }.isEmpty,
                    "Clearing routes left stale markers")
        return "PASS: initial renderer colors, selected overlay ordering, A/B endpoints, numbered ETA badges, selection changes, same-count geometry replacement, ETA refresh, badge/line taps, location protection, and route clearing."
    }

    private static func assertRoutes(_ map: InsertionProbeMap, coordinator: CustomMapView.Coordinator,
                                     routes: [MKPolyline], selected: Int) throws {
        let overlays = map.overlays.compactMap { $0 as? MKPolyline }
        try require(overlays.count == routes.count, "Incorrect number of map route overlays")
        try require(overlays.last === routes[selected], "Selected route is not drawn above alternatives")
        try require(map.captures.count == routes.count, "Insertion renderer probe did not observe each route")
        let colors: [UIColor] = [.systemBlue, .systemOrange, .systemPurple]
        for (index, route) in routes.enumerated() {
            guard let insertion = map.captures.first(where: { $0.polyline === route }) else {
                throw CheckFailure(description: "No insertion renderer for route \(index + 1)")
            }
            try require(insertion.color?.isEqual(colors[index]) == true,
                        "Route \(index + 1) had wrong color during overlay insertion")
            try require(insertion.width == (index == selected ? 7 : 5),
                        "Route \(index + 1) had stale selection width during overlay insertion")
            try require(abs(insertion.alpha - (index == selected ? 1 : 0.85)) < 0.001,
                        "Route \(index + 1) had stale selection opacity during overlay insertion")
            let renderer = coordinator.mapView(map, rendererFor: route) as! MKPolylineRenderer
            try require(renderer.strokeColor?.isEqual(colors[index]) == true,
                        "Route \(index + 1) renderer lost its color")
        }
    }

    private static func assertAnnotations(_ map: MKMapView, coordinator: CustomMapView.Coordinator,
                                          routes: [MKPolyline], selected: Int, etas: [String]) throws {
        let endpoints = map.annotations.compactMap { $0 as? RouteEndpointAnnotation }
        try require(endpoints.count == 2, "Expected one start and one destination marker")
        for isStart in [true, false] {
            guard let endpoint = endpoints.first(where: { $0.isStart == isStart }) else {
                throw CheckFailure(description: "Missing route endpoint")
            }
            let route = routes[selected]
            let expected = route.points()[isStart ? 0 : route.pointCount - 1].coordinate
            try require(sameCoordinate(endpoint.coordinate, expected), "Endpoint marker is not at the selected route endpoint")
            let view = coordinator.mapView(map, viewFor: endpoint) as! MKMarkerAnnotationView
            try require(view.glyphText == (isStart ? "A" : "B"), "Endpoint marker lost its A/B label")
        }
        let badges = map.annotations.compactMap { $0 as? RouteBadgeAnnotation }
        try require(badges.count == routes.count, "Expected one numbered badge per route")
        for index in routes.indices {
            guard let badge = badges.first(where: { $0.routeIndex == index }) else {
                throw CheckFailure(description: "Missing numbered route badge")
            }
            try require(badge.eta == etas[index], "Route badge displays another route's ETA")
            let view = coordinator.mapView(map, viewFor: badge) as! RouteBadgeAnnotationView
            let labels = view.subviews.compactMap { ($0 as? UILabel)?.text }
            try require(labels.contains(String(index + 1)) && labels.contains(etas[index]),
                        "Route badge does not visibly show its number and ETA")
            try require(view.accessibilityTraits.contains(.selected) == (index == selected),
                        "Route badge selection does not match the selected route")
        }
    }
}

private struct RouteMapFixtureView: View {
    @State private var selected = 0
    private let routes = BordeauxFixture.routes()
    private let arguments = ProcessInfo.processInfo.arguments

    private func argument(_ name: String, fallback: String) -> String {
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return fallback }
        return arguments[index + 1]
    }

    var body: some View {
        let appearance = argument("--appearance", fallback: "dark")
        let section = argument("--section", fallback: "map")
        NavigationStack {
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Select Route", systemImage: "map.fill").font(.headline)
                            Spacer()
                            Text("3 routes").font(.caption).foregroundColor(.secondary)
                        }
                        CustomMapView(
                            tappedCoordinate: .constant(nil), moveToRegion: .constant(nil),
                            allRoutePolylines: routes, selectedRouteIndex: selected,
                            routeETAs: BordeauxFixture.etas, allowsLocationSelection: false,
                            onSelectRoute: { selected = $0 }, fitsRoutes: true, showsUserLocation: false
                        )
                        .frame(height: 340)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        Text("Tap a numbered route to select it. A is the start; B is the destination.")
                            .font(.caption).foregroundColor(.secondary)
                        ForEach(0..<3, id: \.self) { index in
                            RouteChoiceCard(
                                number: index + 1,
                                name: index == 0 ? "Fastest Route" : "Alternative \(index)",
                                roadName: BordeauxFixture.roads[index], distance: BordeauxFixture.distances[index],
                                roadETA: BordeauxFixture.etas[index], simulationETA: BordeauxFixture.simulations[index],
                                speed: "75 km/h", isFastest: index == 0, isSelected: selected == index,
                                select: { selected = index }
                            )
                        }
                        Text("Synthetic Bordeaux routes · Visual QA fixture")
                            .font(.caption2).foregroundColor(.secondary).id("bottom")
                    }
                    .padding(16)
                }
                .task {
                    let report: String
                    do { report = try RouteMapChecks.run() }
                    catch { report = "FAIL: \(error)" }
                    // Allow the map to lay out and its tiles to load before the capture signal.
                    try? await Task.sleep(nanoseconds: 8_000_000_000)
                    if section == "cards" { reader.scrollTo("bottom", anchor: .bottom) }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    try? report.write(to: documents.appendingPathComponent("route-map-\(appearance)-\(section).txt"),
                                      atomically: true, encoding: .utf8)
                }
            }
            .navigationTitle("Bordeaux · QA fixture")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(appearance == "dark" ? .dark : .light)
    }
}

@main struct RouteMapPreview: App {
    var body: some Scene {
        WindowGroup { RouteMapFixtureView() }
    }
}
