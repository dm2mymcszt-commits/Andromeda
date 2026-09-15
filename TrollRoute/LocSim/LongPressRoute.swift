import SwiftUI
import CoreLocation

struct LongPressRouteRequest: Identifiable {
    let id = UUID()
    let destination: CLLocationCoordinate2D // map coordinates
    let spoofedStart: CLLocationCoordinate2D? // WGS-84
    let autoStart: Bool
}

struct LongPressRouteEndpoints {
    let start: CLLocationCoordinate2D // map coordinates
    let destination: CLLocationCoordinate2D
    let startName: String
    let autoStart: Bool
}

final class LongPressRouteController: ObservableObject {
    typealias Lookup = (@escaping (Result<CLLocation, Error>) -> Void) -> (() -> Void)
    @Published var presentedRequest: LongPressRouteRequest?
    @Published var error: String?
    @Published private(set) var isLocating = false
    private var pending: LongPressRouteRequest?
    private var lookup: Lookup?
    private var cancelLookup: (() -> Void)?
    private var create: ((LongPressRouteEndpoints) -> Void)?

    func request(destination: CLLocationCoordinate2D, enabled: Bool, confirm: Bool,
                 autoStart: Bool, spoofedStart: CLLocationCoordinate2D?, routeRunning: Bool,
                 lookup: @escaping Lookup, create: @escaping (LongPressRouteEndpoints) -> Void) {
        cancel()
        error = nil
        guard enabled, CLLocationCoordinate2DIsValid(destination) else { return }
        guard !routeRunning else {
            error = "Stop the current route before creating another route."
            return
        }
        let request = LongPressRouteRequest(destination: destination,
            spoofedStart: spoofedStart, autoStart: autoStart)
        pending = request
        self.lookup = lookup
        self.create = create
        if confirm { presentedRequest = request } else { confirmRequest(request) }
    }

    func confirmRequest(_ request: LongPressRouteRequest) {
        guard pending?.id == request.id, !isLocating else { return }
        presentedRequest = nil
        if let coordinate = request.spoofedStart, CLLocationCoordinate2DIsValid(coordinate) {
            complete(request, start: coordinate, name: "Current spoofed location")
        } else {
            isLocating = true
            cancelLookup = lookup? { [weak self] result in
                guard let self = self, self.pending?.id == request.id else { return }
                switch result {
                case .success(let location):
                    self.complete(request, start: location.coordinate, name: "Current Location")
                case .failure(let error):
                    self.cancel()
                    self.error = error.localizedDescription
                }
            }
            if pending == nil { cancelLookup?(); cancelLookup = nil }
        }
    }

    private func complete(_ request: LongPressRouteRequest, start: CLLocationCoordinate2D, name: String) {
        guard pending?.id == request.id, CLLocationCoordinate2DIsValid(start), let create = create else { return }
        cancel()
        create(LongPressRouteEndpoints(start: CoordTransform.wgs84ToGcj02(start),
            destination: request.destination, startName: name, autoStart: request.autoStart))
    }

    func cancel() {
        pending = nil
        presentedRequest = nil
        create = nil
        lookup = nil
        isLocating = false
        cancelLookup?()
        cancelLookup = nil
    }
}

struct LongPressRouteConfirmation: ViewModifier {
    @ObservedObject var controller: LongPressRouteController
    func body(content: Content) -> some View {
        content.alert("Create route to here?", isPresented: Binding(
            get: { controller.presentedRequest != nil },
            set: { if !$0 { controller.presentedRequest = nil } }),
            presenting: controller.presentedRequest) { request in
                Button("Cancel", role: .cancel) { controller.cancel() }
                Button("Create route") { controller.confirmRequest(request) }
            } message: { request in
                let wgs = CoordTransform.gcj02ToWgs84(request.destination)
                Text(String(format: "%.5f, %.5f", wgs.latitude, wgs.longitude))
            }
    }
}

// Owns the once-only transition from directions completion to preview/auto-start.
// Closing Navigation or replacing the calculation invalidates its continuation.
final class RoutePreparationController: ObservableObject {
    private var requestID: UUID?

    func prepare(autoStart: Bool, calculate: (@escaping (Bool, String?) -> Void) -> Void,
                 ready: @escaping () -> Void, start: @escaping () -> Void,
                 failure: @escaping (String?) -> Void) {
        let id = UUID()
        requestID = id
        calculate { [weak self] success, error in
            guard let self = self, self.requestID == id else { return }
            self.requestID = nil
            guard success else { failure(error); return }
            ready()
            if autoStart { start() }
        }
    }

    func cancel() { requestID = nil }
}
