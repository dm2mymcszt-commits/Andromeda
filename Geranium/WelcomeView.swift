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
        .navigationTitle("Andromeda")
        .interactiveDismissDisabled()
    }
}

public struct CustomButtonStyle: ButtonStyle {
    public func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .padding(.vertical, 12)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14.0, style: .continuous)
                            .fill(Color.accentColor))
            .opacity(configuration.isPressed ? 0.4 : 1.0)
    }
}

public struct LinkButtonStyle: ButtonStyle {
    public func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .padding(.vertical, 12)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12.0, style: .continuous)
                            .fill(Color.blue.opacity(0.1)))
            .opacity(configuration.isPressed ? 0.4 : 1.0)
    }
}

public struct DangerButtonStyle: ButtonStyle {
    public func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .padding(.vertical, 12)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12.0, style: .continuous)
                            .fill(Color.red.opacity(0.1)))
            .opacity(configuration.isPressed ? 0.4 : 1.0)
    }
}
