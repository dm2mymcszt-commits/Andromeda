import SwiftUI

struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = AppSettings()
    var body: some View {
        List {
            Section {
                Label("Your location, your route", systemImage: "location.fill")
                    .font(.title2.weight(.semibold))
                Text("Search for a place, choose a point on the map, or simulate a route with the speed you select.")
            }
            Section("Get started") {
                Label("Search or choose a destination", systemImage: "magnifyingglass")
                Label("Compare routes before starting", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                Label("Open the gear for map and search settings", systemImage: "gearshape")
            }
            Section {
                Text("Install with TrollStore to enable location simulation. Current Location uses the position reported by iOS, which may already be simulated.")
                    .foregroundColor(.secondary)
                Button("Open map") { settings.isFirstRun = false; dismiss() }
            }
        }
        .navigationTitle("TrollRoute")
        .interactiveDismissDisabled()
    }
}
