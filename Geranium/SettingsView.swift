import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("mapAppearance") private var mapAppearance = "system"
    @AppStorage("mapStyle") private var mapStyle = "standard"
    @AppStorage("mapButtonLabels") private var mapButtonLabels = true
    @AppStorage("mapHaptics") private var mapHaptics = true
    @AppStorage("tapMapToSetLocation") private var tapMapToSetLocation = false
    @AppStorage("askBeforeMoving") private var askBeforeMoving = true
    @AppStorage("frenchAddressLookup") private var frenchAddressLookup = true

    var body: some View {
        NavigationView {
            Form {
                Section("Map") {
                    Picker("Appearance", selection: $mapAppearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    Picker("Map style", selection: $mapStyle) {
                        Text("Standard").tag("standard")
                        Text("Satellite").tag("hybrid")
                    }
                    Toggle("Show button labels", isOn: $mapButtonLabels)
                    Toggle("Button haptics", isOn: $mapHaptics)
                    Toggle("Tap map to set location", isOn: $tapMapToSetLocation)
                    if tapMapToSetLocation {
                        Toggle("Ask before moving", isOn: $askBeforeMoving)
                    }
                }
                Section {
                    Toggle("French address lookup", isOn: $frenchAddressLookup)
                } header: {
                    Text("Search")
                } footer: {
                    Text("Adds French address results from IGN / Base Adresse Nationale. Address searches are sent to this service; your current location is not. Apple Maps remains available for worldwide places.")
                }
                Section {
                    Button("Location permissions") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                } header: { Text("Location") } footer: {
                    Text("Allow location access to use Current Location. Route simulation can continue while this settings panel is open.")
                }
                Section("About") {
                    HStack {
                        Text("Andromeda")
                        Spacer()
                        Text("\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""))")
                            .foregroundColor(.secondary)
                    }
                    Link("Source code", destination: URL(string: "https://github.com/dm2mymcszt-commits/Andromeda")!)
                    Text("Based on Andromeda by son3ra1n and Geranium by c22dev. GPL-3.0.")
                        .font(.caption).foregroundColor(.secondary)
                    Link("French address data: IGN / BAN", destination: URL(string: "https://geoservices.ign.fr/services-geoplateforme-geocodage")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
