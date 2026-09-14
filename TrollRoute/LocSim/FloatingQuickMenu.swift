import SwiftUI

// Shared by the production map and the UI test host. The scroll view itself is
// only as tall as its visible content (or the space above the playback panel).
struct MapToolbarOverlay: ViewModifier {
    let onAction: (QuickMenuAction) -> Void
    var joystickActive: Bool
    var routeActive: Bool
    @AppStorage("mapButtonLabels", store: SharedPreferences.defaults) private var showLabels = true
    @State private var contentHeight: CGFloat = 336

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            GeometryReader { available in
                ScrollView(showsIndicators: false) {
                    FloatingQuickMenu(onAction: onAction, joystickActive: joystickActive, routeActive: routeActive)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(GeometryReader { geometry in
                            Color.clear.preference(key: MenuHeightKey.self, value: geometry.size.height)
                        })
                }
                .frame(width: showLabels ? 144 : 56,
                       height: min(contentHeight, max(44, available.size.height - 24)))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .accessibilityIdentifier("map-toolbar")
                .onPreferenceChange(MenuHeightKey.self) { contentHeight = $0 }
                .padding(.top, 12).padding(.trailing, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
    }
}

private struct MenuHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 336
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

enum QuickMenuAction: String, CaseIterable {
    case search = "Search"
    case route = "Route"
    case favorites = "Favorites"
    case joystick = "Joystick"
    case altitude = "Altitude"
    case settings = "Settings"
    case stop = "Stop"

    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .route: return "point.topleft.down.to.point.bottomright.curvepath"
        case .favorites: return "star"
        case .joystick: return "gamecontroller"
        case .altitude: return "mountain.2"
        case .settings: return "gearshape"
        case .stop: return "stop.fill"
        }
    }
}

struct FloatingQuickMenu: View {
    let onAction: (QuickMenuAction) -> Void
    var joystickActive: Bool
    var routeActive: Bool = false
    @AppStorage("mapButtonLabels", store: SharedPreferences.defaults) private var showLabels = true
    @AppStorage("mapHaptics", store: SharedPreferences.defaults) private var haptics = true

    var body: some View {
        VStack(spacing: 2) {
            ForEach(QuickMenuAction.allCases, id: \.self) { action in
                if action == .stop { Divider().padding(.horizontal, 6) }
                let active = (action == .joystick && joystickActive)
                    || (action == .route && routeActive)
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
