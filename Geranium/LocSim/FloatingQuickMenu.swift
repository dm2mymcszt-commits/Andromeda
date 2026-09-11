import SwiftUI

enum QuickMenuAction: String, CaseIterable {
    case search = "Search"
    case route = "Route"
    case favorites = "Favorites"
    case joystick = "Joystick"
    case altitude = "Altitude"
    case timer = "Timer"
    case settings = "Settings"
    case stop = "Stop"

    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .route: return "point.topleft.down.to.point.bottomright.curvepath"
        case .favorites: return "star"
        case .joystick: return "gamecontroller"
        case .altitude: return "mountain.2"
        case .timer: return "timer"
        case .settings: return "gearshape"
        case .stop: return "stop.fill"
        }
    }
}

struct FloatingQuickMenu: View {
    let onAction: (QuickMenuAction) -> Void
    var joystickActive: Bool
    var timerActive: Bool
    var routeActive: Bool = false
    @AppStorage("mapButtonLabels") private var showLabels = true
    @AppStorage("mapHaptics") private var haptics = true

    var body: some View {
        VStack(spacing: 2) {
            ForEach(QuickMenuAction.allCases, id: \.self) { action in
                if action == .stop { Divider().padding(.horizontal, 6) }
                let active = (action == .joystick && joystickActive)
                    || (action == .timer && timerActive) || (action == .route && routeActive)
                Button {
                    if haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                    onAction(action)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: action.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 24)
                        if showLabels {
                            Text(action.rawValue).font(.subheadline.weight(.medium))
                            Spacer(minLength: 0)
                        }
                    }
                    .foregroundColor(active ? .white : .indigo)
                    .padding(.horizontal, 10)
                    .frame(width: showLabels ? 132 : 44, height: 44)
                    .background(active ? Color.indigo : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(action.rawValue)
                .accessibilityAddTraits(active ? [.isSelected] : [])
            }
        }
        .frame(width: showLabels ? 132 : 44)
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(UIColor.separator).opacity(0.4), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
    }
}
