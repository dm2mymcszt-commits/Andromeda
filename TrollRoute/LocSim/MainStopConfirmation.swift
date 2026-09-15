import SwiftUI

struct MainStopRequest: Identifiable {
    let id = UUID()
    let routeRunning: Bool
    var message: String {
        routeRunning
            ? "This will stop the running route and restore your real location."
            : "This will stop location spoofing and restore your real location."
    }
}

// Only the main map toolbar uses this controller. Route Stop has its own outcomes.
final class MainStopController: ObservableObject {
    @Published var presentedRequest: MainStopRequest?
    private var pendingID: UUID?
    private var stopAction: (() -> Void)?

    func request(confirm: Bool, routeRunning: Bool, stop: @escaping () -> Void) {
        cancel()
        guard confirm else { stop(); return }
        let request = MainStopRequest(routeRunning: routeRunning)
        pendingID = request.id
        stopAction = stop
        presentedRequest = request
    }

    func confirm(_ request: MainStopRequest) {
        guard pendingID == request.id, let stop = stopAction else { return }
        cancel()
        stop()
    }

    func cancel() {
        pendingID = nil
        stopAction = nil
        presentedRequest = nil
    }
}

struct MainStopConfirmation: ViewModifier {
    @ObservedObject var controller: MainStopController
    func body(content: Content) -> some View {
        content.alert("Stop location spoofing?", isPresented: Binding(
            get: { controller.presentedRequest != nil },
            set: { if !$0 { controller.presentedRequest = nil } }),
            presenting: controller.presentedRequest) { request in
                Button("Cancel", role: .cancel) { controller.cancel() }
                Button("Stop", role: .destructive) { controller.confirm(request) }
            } message: { request in Text(request.message) }
    }
}
