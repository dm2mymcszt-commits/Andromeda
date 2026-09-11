import SwiftUI
import MapKit

struct EquatableCoordinate: Equatable {
    let coordinate: CLLocationCoordinate2D
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

struct WorkspacePreview: View {
    @State private var region: MKCoordinateRegion? = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 44.8378, longitude: -0.5792),
        span: MKCoordinateSpan(latitudeDelta: 0.07, longitudeDelta: 0.07))
    @State private var showSettings = false
    @State private var showSearch = false
    @State private var routeActive = false
    @State private var tapped: EquatableCoordinate?
    // Deterministic address fixture for the confirmation screenshot, not a live lookup.
    @StateObject private var mapMove = MapMoveController(lookup: { _, completion in
        completion("Preview address, Bordeaux")
        return {}
    })
    @StateObject private var places = RouteRecentPlaces()
    @AppStorage("mapStyle") private var mapStyle = "standard"
    @AppStorage("tapMapToSetLocation") private var tapEnabled = false
    @AppStorage("askBeforeMoving") private var askBeforeMoving = true
    let screen: String
    let appearance: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CustomMapView(tappedCoordinate: $tapped, moveToRegion: $region,
                          allowsLocationSelection: tapEnabled, showsUserLocation: false, mapStyle: mapStyle,
                          proposedPosition: mapMove.pendingRequest?.coordinate)
                .ignoresSafeArea()
            FloatingQuickMenu(onAction: { action in
                if action == .settings { showSettings = true }
                if action == .search { showSearch = true }
                if action == .route { routeActive.toggle() }
            }, joystickActive: false, routeActive: routeActive)
                .background(GeometryReader { geometry in
                    Color.clear.onAppear {
                        let width = geometry.size.width
                        let result = width <= 150 && width >= 140
                            ? "PASS: map menu width is \(width) points"
                            : "FAIL: map menu expanded to \(width) points"
                        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                            .appendingPathComponent("menu-width.txt")
                        try? result.write(to: path, atomically: true, encoding: .utf8)
                    }
                })
                .padding(.trailing, 12).padding(.top, 12)
        }
        .modifier(MapMoveConfirmation(controller: mapMove))
        .onChange(of: tapped) { coordinate in
            guard let coordinate = coordinate else { return }
            tapped = nil
            mapMove.request(coordinate.coordinate, displayCoordinate: coordinate.coordinate,
                            enabled: tapEnabled, ask: askBeforeMoving, routeRunning: routeActive) { _ in }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showSearch) {
            RouteLocationPicker(title: "Find a place", region: nil, selectedCoordinate: nil,
                recents: places, initialQuery: "125 Cr Gambetta, 33400 Talence", select: { _ in })
        }
        .task {
            tapEnabled = screen == "settings-enabled"
            if screen == "settings" || screen == "settings-enabled" { showSettings = true }
            if screen == "search" { showSearch = true }
            if screen == "confirmation" {
                let point = CLLocationCoordinate2D(latitude: 44.8378, longitude: -0.5792)
                mapMove.request(point, displayCoordinate: point, enabled: true, ask: true,
                                routeRunning: true) { _ in }
            }
        }
        .preferredColorScheme(appearance == "dark" ? .dark : .light)
        .tint(.indigo)
    }
}

@main struct MapWorkspacePreview: App {
    private func argument(_ key: String, fallback: String) -> String {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: key), index + 1 < args.count else { return fallback }
        return args[index + 1]
    }
    var body: some Scene {
        WindowGroup {
            WorkspacePreview(screen: argument("--screen", fallback: "map"),
                             appearance: argument("--appearance", fallback: "dark"))
        }
    }
}
