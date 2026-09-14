import SwiftUI
import CoreLocation

enum FavoritePlaceSave {
    static func save(_ place: RoutePlace, name: String,
                     write: (Double, Double, String) -> Bool = BookMarkSave) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let wgs = CoordTransform.gcj02ToWgs84(place.coordinate)
        guard !name.isEmpty, CLLocationCoordinate2DIsValid(wgs) else { return false }
        return write(wgs.latitude, wgs.longitude, name)
    }
}

#if os(iOS)
struct FavoritePlaceEditor: View {
    let place: RoutePlace
    var didSave: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var failed = false

    init(place: RoutePlace, didSave: @escaping () -> Void = {}) {
        self.place = place
        self.didSave = didSave
        _name = State(initialValue: place.name)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Name") {
                    TextField("Favorite name", text: $name).accessibilityIdentifier("favorite-name")
                }
                Section("Place") {
                    if !place.address.isEmpty { Text(place.address) }
                    let wgs = CoordTransform.gcj02ToWgs84(place.coordinate)
                    Text(String(format: "%.5f, %.5f", wgs.latitude, wgs.longitude))
                        .foregroundColor(.secondary)
                    if place.isApproximate { Text("Approximate").foregroundColor(.secondary) }
                }
            }
            .navigationTitle("Save as favorite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if FavoritePlaceSave.save(place, name: name) { didSave(); dismiss() }
                        else { failed = true }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Couldn't save favorite", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: { Text("Check the name and location, then try again.") }
        }
    }
}
#endif
