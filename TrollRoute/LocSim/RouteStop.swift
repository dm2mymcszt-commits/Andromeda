import Foundation
import CoreLocation

enum RouteStopAction: String, CaseIterable, Identifiable, Codable {
    case previous, current, start, specific, real
    var id: String { rawValue }
    static let defaults: [Self] = [.previous, .current, .start, .real]
    var title: String {
        switch self {
        case .previous: return "Return to previous spoofed location"
        case .current: return "Stay at current location"
        case .start: return "Return to route start"
        case .specific: return "Go to a specific location"
        case .real: return "Restore real location"
        }
    }
    static func savedDefault(in defaults: UserDefaults) -> Self {
        let saved = Self(rawValue: defaults.string(forKey: "routeStopDefault") ?? "") ?? .previous
        return Self.defaults.contains(saved) ? saved : .previous
    }
}

/// Immutable press-time capture. The route continues while the user decides.
/// The trip ID rejects a response after that trip ends or another one starts.
struct RouteStopRequest: Identifiable, Codable {
    let id: UUID
    let tripID: UUID
    let previous: SessionLocation?
    let current: SessionLocation
    let start: SessionLocation
    let preselection: RouteStopAction

    var choices: [RouteStopAction] {
        previous == nil ? [.current, .start, .specific, .real] : RouteStopAction.defaults
    }

    init(tripID: UUID, previous: SessionLocation?, current: SessionLocation,
         start: SessionLocation, preferred: RouteStopAction) {
        id = UUID()
        self.tripID = tripID
        self.previous = previous
        self.current = current
        self.start = start
        let choices: [RouteStopAction] = previous == nil ? [.current, .start, .specific, .real] : RouteStopAction.defaults
        preselection = choices.contains(preferred) ? preferred : .current
    }
}
