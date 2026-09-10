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
    @StateObject private var places = RouteRecentPlaces()
    @AppStorage("mapStyle") private var mapStyle = "standard"
    let screen: String
    let appearance: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CustomMapView(tappedCoordinate: .constant(nil), moveToRegion: $region,
                          allowsLocationSelection: false, showsUserLocation: false, mapStyle: mapStyle)
                .ignoresSafeArea()
            FloatingQuickMenu(onAction: { action in
                if action == .settings { showSettings = true }
                if action == .search { showSearch = true }
                if action == .route { routeActive.toggle() }
            }, joystickActive: false, timerActive: false, routeActive: routeActive)
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
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showSearch) {
            RouteLocationPicker(title: "Find a place", region: nil, selectedCoordinate: nil,
                recents: places, initialQuery: "125 Cr Gambetta, 33400 Talence", select: { _ in })
        }
        .task {
            if screen == "settings" { showSettings = true }
            if screen == "search" { showSearch = true }
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
