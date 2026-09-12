import SwiftUI

struct SharePlaceView: View {
    var initialPlace: RoutePlace? = nil
    let load: () async throws -> [RoutePlace]
    let done: () -> Void
    @State private var places: [RoutePlace] = []
    @State private var selected: RoutePlace?
    @State private var name = ""
    @State private var loading = true
    @State private var error: String?
    @State private var completion: String?

    var body: some View {
        NavigationView {
            Form {
                if loading { ProgressView("Finding shared location…") }
                if let completion = completion {
                    Section { Label(completion, systemImage: "checkmark.circle") }
                } else if let place = selected {
                    Section("Shared place") {
                        TextField("Place name", text: $name)
                        if !place.address.isEmpty { Text(place.address).foregroundColor(.secondary) }
                        if place.isApproximate { Text("Approximate").foregroundColor(.secondary) }
                    }
                    if places.count > 1 {
                        Section("Other matches") {
                            ForEach(places.filter { $0.id != place.id }) { alternative in
                                Button(alternative.name + " · " + alternative.address) {
                                    selected = alternative; name = alternative.name
                                }
                            }
                        }
                    }
                    Section {
                        ForEach(SharedPlaceAction.allCases) { action in
                            Button { save(action) } label: { Label(action.title, systemImage: action.icon) }
                        }
                    } footer: {
                        Text("Favorites are saved here. For the other actions, open Andromeda to review and continue.")
                    }
                }
                if let error = error {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .navigationTitle("Andromeda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(completion == nil ? "Cancel" : "Done", action: done) } }
        }
        .task {
            do {
                let result: [RoutePlace]
                if let initialPlace = initialPlace { result = [initialPlace] }
                else { result = try await load() }
                guard !Task.isCancelled else { return }
                places = result; selected = result.first; name = result.first?.name ?? ""
                if result.isEmpty { error = "No matching location. Copy its coordinates or plus code from Maps and try again." }
            } catch { self.error = error.localizedDescription }
            loading = false
        }
    }

    private func save(_ action: SharedPlaceAction) {
        guard let selected = selected else { return }
        let entered = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var place = RoutePlace(name: entered.isEmpty ? selected.name : entered, address: selected.address, coordinate: selected.coordinate)
        place.approximate = selected.approximate
        do {
            if action == .favorite {
                try SharedPlaceInbox.saveFavorite(place)
                completion = "Saved to Favorites"
            } else {
                try SharedPlaceInbox().enqueue(SharedPlaceRequest(place: place, action: action))
                completion = "Ready. Open Andromeda to continue."
            }
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}
