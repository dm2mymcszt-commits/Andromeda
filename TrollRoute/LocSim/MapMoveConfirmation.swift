import SwiftUI
import CoreLocation

struct PendingMapMove: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let displayCoordinate: CLLocationCoordinate2D
    let stopsRoute: Bool
    var address: String?

    var message: String {
        var lines = [String(format: "%.5f, %.5f", displayCoordinate.latitude, displayCoordinate.longitude)]
        if let address = address, !address.isEmpty { lines.append(address) }
        if stopsRoute { lines.append("Moving here will stop the running route.") }
        return lines.joined(separator: "\n\n")
    }
}

// Owns a proposed move only. No location is injected before confirm() or an
// explicitly enabled immediate move. UUIDs invalidate late geocoder callbacks.
final class MapMoveController: ObservableObject {
    typealias Lookup = (CLLocationCoordinate2D, @escaping (String?) -> Void) -> (() -> Void)
    @Published private(set) var pendingRequest: PendingMapMove?
    @Published var presentedRequest: PendingMapMove?
    private let geocoder = CLGeocoder()
    private let customLookup: Lookup?
    private let addressWait: TimeInterval
    private var cancelLookup: (() -> Void)?
    private var promptWork: DispatchWorkItem?
    private var moveAction: ((CLLocationCoordinate2D) -> Void)?

    init(addressWait: TimeInterval = 0.6, lookup: Lookup? = nil) {
        self.addressWait = addressWait
        customLookup = lookup
    }

    func request(_ coordinate: CLLocationCoordinate2D, displayCoordinate: CLLocationCoordinate2D,
                 enabled: Bool, ask: Bool, routeRunning: Bool,
                 move: @escaping (CLLocationCoordinate2D) -> Void) {
        cancel()
        guard enabled, CLLocationCoordinate2DIsValid(coordinate),
              CLLocationCoordinate2DIsValid(displayCoordinate) else { return }
        guard ask else { move(coordinate); return }
        let request = PendingMapMove(coordinate: coordinate, displayCoordinate: displayCoordinate,
                                     stopsRoute: routeRunning)
        pendingRequest = request
        moveAction = move
        let work = DispatchWorkItem { [weak self] in self?.present(request.id) }
        promptWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + addressWait, execute: work)
        let completion: (String?) -> Void = { [weak self] address in
            let apply = {
                guard let self = self, self.pendingRequest?.id == request.id,
                      self.presentedRequest == nil else { return }
                self.pendingRequest?.address = address
                self.present(request.id)
            }
            if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
        }
        if let lookup = customLookup {
            cancelLookup = lookup(displayCoordinate, completion)
        } else {
            geocoder.reverseGeocodeLocation(CLLocation(latitude: displayCoordinate.latitude,
                                                       longitude: displayCoordinate.longitude)) { places, _ in
                let place = places?.first
                let parts = [place?.name, place?.locality, place?.postalCode, place?.country]
                    .compactMap { $0 }.filter { !$0.isEmpty }
                completion(parts.isEmpty ? nil : parts.joined(separator: ", "))
            }
            cancelLookup = { [weak self] in self?.geocoder.cancelGeocode() }
        }
        // A synchronous cached lookup may already have presented the request.
        if presentedRequest != nil { cancelLookup?(); cancelLookup = nil }
    }

    private func present(_ id: UUID) {
        guard let request = pendingRequest, request.id == id, presentedRequest == nil else { return }
        promptWork?.cancel()
        presentedRequest = request
        cancelLookup?()
        cancelLookup = nil
    }

    func confirm(_ request: PendingMapMove) {
        guard pendingRequest?.id == request.id, let move = moveAction else { return }
        cancel()
        move(request.coordinate)
    }

    func cancel() {
        pendingRequest = nil
        presentedRequest = nil
        moveAction = nil
        promptWork?.cancel()
        promptWork = nil
        cancelLookup?()
        cancelLookup = nil
    }
}

struct MapMoveConfirmation: ViewModifier {
    @ObservedObject var controller: MapMoveController
    func body(content: Content) -> some View {
        content.alert(item: $controller.presentedRequest) { request in
            Alert(title: Text("Move location here?"), message: Text(request.message),
                  primaryButton: .cancel(Text("Cancel")) { controller.cancel() },
                  secondaryButton: .default(Text("Move")) { controller.confirm(request) })
        }
    }
}
