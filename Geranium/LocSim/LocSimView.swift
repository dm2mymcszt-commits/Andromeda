//  Andromeda LocSim
//  Created by son3ra1n.
//  Enhanced version of Geranium.
//  Developed by son3ra1n.
//

import SwiftUI
import CoreLocation
import MapKit
import AlertKit

struct LocSimView: View {
    @AppStorage("mapStyle") private var mapStyle = "standard"
    @StateObject private var routeSimulator = RouteSimulator()
    
    @State private var locationManager = CLLocationManager()
    @State private var lat: Double = 0.0
    @State private var long: Double = 0.0
    @State private var altitude: String = "0.0"
    @State private var tappedCoordinate: EquatableCoordinate? = nil
    @State private var bookmarkSheetToggle: Bool = false
    @State private var showRouteSheet: Bool = false
    @State private var showSearchBar: Bool = false
    @State private var showSettings = false
    @StateObject private var recentPlaces = RouteRecentPlaces()
    @State private var mapRegion: MKCoordinateRegion? = nil
    
    // Joystick
    @State private var joystickActive: Bool = false
    @State private var joystickCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
    
    // Favorites
    @State private var showFavorites: Bool = false
    
    // App Profiles
    @State private var showAppProfiles: Bool = false
    
    // Timer
    @State private var showTimerPicker: Bool = false
    @State private var timerRemaining: Int = 0
    @State private var timerActive: Bool = false
    @State private var simTimer: Timer? = nil
    var body: some View {
        LocSimMainView()
    }
    @ViewBuilder
        private func LocSimMainView() -> some View {
            ZStack(alignment: .topTrailing) {
                // MARK: - Main Map
                CustomMapView(tappedCoordinate: $tappedCoordinate, moveToRegion: $mapRegion,
                              routePolyline: routeSimulator.routePolyline,
                              allRoutePolylines: routeSimulator.allRoutePolylines,
                              selectedRouteIndex: routeSimulator.selectedRouteIndex,
                              movingPosition: routeSimulator.currentPosition,
                              routeETAs: routeSimulator.availableRoutes.map(\.etaText),
                              onSelectRoute: { index in
                                  guard !routeSimulator.isSimulating else { return }
                                  routeSimulator.selectRoute(at: index)
                              }, mapStyle: mapStyle)
                    .onAppear {
                        CLLocationManager().requestAlwaysAuthorization()
                    }
                    .onChange(of: tappedCoordinate) { newCoord in
                        guard let coord = newCoord else { return }
                        let altitudeValue = Double(altitude) ?? 0.0
                        startSimulation(at: coord.coordinate, altitude: altitudeValue)
                    }
                    .ignoresSafeArea()
                
            // MARK: - Map Controls
            FloatingQuickMenu(
                onAction: { action in
                    handleQuickMenuAction(action)
                },
                joystickActive: joystickActive,
                timerActive: timerActive,
                routeActive: routeSimulator.isSimulating
            )
            .padding(.trailing, 12)
            .padding(.top, 12)
            
            // MARK: - Joystick Overlay
            if joystickActive {
                JoystickView(
                    isActive: $joystickActive,
                    onMove: { newCoord in
                        joystickCoordinate = newCoord
                        let location = CLLocation(coordinate: newCoord, altitude: Double(altitude) ?? 0, horizontalAccuracy: 5, verticalAccuracy: 5, timestamp: Date())
                        LocSimManager.startLocSim(location: location)
                        lat = newCoord.latitude
                        long = newCoord.longitude
                    },
                    currentCoordinate: $joystickCoordinate
                )
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
            
            // MARK: - Timer Countdown
            if timerActive {
                VStack {
                    Spacer()
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "timer")
                                .foregroundColor(.orange)
                            Text(timerString())
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                            Button(action: { cancelTimer() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.15), radius: 8)
                        Spacer()
                    }
                    .padding(.leading, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showSearchBar) {
            RouteLocationPicker(title: "Find a place", region: mapRegion,
                selectedCoordinate: nil, recents: recentPlaces) { place in
                recentPlaces.remember(place)
                let coordinate = place.coordinate
                mapRegion = MKCoordinateRegion(center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                startSimulation(at: coordinate, altitude: Double(altitude) ?? 0)
            }
        }
        .sheet(isPresented: $bookmarkSheetToggle) {
            BookMarkSlider(lat: $lat, long: $long)
        }
        .sheet(isPresented: $showRouteSheet) {
            RouteSimSheet(routeSimulator: routeSimulator, mapRegion: $mapRegion, isPresented: $showRouteSheet)
        }
        .sheet(isPresented: $showFavorites) {
            FavoritesView(isPresented: $showFavorites, currentLat: lat, currentLong: long) { favLat, favLong, name in
                let coord = CLLocationCoordinate2D(latitude: favLat, longitude: favLong)
                let region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                mapRegion = region
                startSimulation(at: coord, altitude: Double(altitude) ?? 0.0)
                AlertKitAPI.present(title: "📍 \(name)", icon: .done, style: .iOS17AppleMusic, haptic: .success)
            }
        }
        .actionSheet(isPresented: $showTimerPicker) {
            ActionSheet(title: Text("Auto-Stop Timer"), message: Text("LocSim will stop automatically after:"), buttons: [
                .default(Text("15 minutes")) { startTimer(minutes: 15) },
                .default(Text("30 minutes")) { startTimer(minutes: 30) },
                .default(Text("1 hour")) { startTimer(minutes: 60) },
                .default(Text("2 hours")) { startTimer(minutes: 120) },
                .cancel()
            ])
        }
        .sheet(isPresented: $showAppProfiles) {
            AppProfilesView(isPresented: $showAppProfiles, currentLat: lat, currentLong: long) { profLat, profLong, name in
                let coord = CLLocationCoordinate2D(latitude: profLat, longitude: profLong)
                let region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                mapRegion = region
                startSimulation(at: coord, altitude: Double(altitude) ?? 0.0)
                AlertKitAPI.present(title: name, icon: .done, style: .iOS17AppleMusic, haptic: .success)
            }
        }
    }
    
    private func startSimulation(at gcjCoordinate: CLLocationCoordinate2D, altitude: Double) {
        if routeSimulator.isSimulating { routeSimulator.stopSimulation() }
        joystickActive = false
        let wgsCoordinate = CoordTransform.gcj02ToWgs84(gcjCoordinate)
        
        self.lat = wgsCoordinate.latitude
        self.long = wgsCoordinate.longitude
        
        let location = CLLocation(coordinate: wgsCoordinate, altitude: altitude,horizontalAccuracy:5,verticalAccuracy: 5,timestamp: Date())
        LocSimManager.startLocSim(location: location)
        
        joystickCoordinate = wgsCoordinate
        
        AlertKitAPI.present(
            title: "Started!",
            icon: .done,
            style: .iOS17AppleMusic,
            haptic: .success
        )
    }
    
    // MARK: - Timer
    private func startTimer(minutes: Int) {
        timerRemaining = minutes * 60
        timerActive = true
        simTimer?.invalidate()
        simTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timerRemaining > 0 {
                timerRemaining -= 1
            } else {
                stopSimulation()
                cancelTimer()
            }
        }
        AlertKitAPI.present(title: "Timer: \(minutes)m", icon: .done, style: .iOS17AppleMusic, haptic: .success)
    }
    
    private func cancelTimer() {
        simTimer?.invalidate()
        simTimer = nil
        timerActive = false
        timerRemaining = 0
    }
    
    private func timerString() -> String {
        let h = timerRemaining / 3600
        let m = (timerRemaining % 3600) / 60
        let s = timerRemaining % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
    
    // MARK: - Quick Menu Handler
    private func handleQuickMenuAction(_ action: QuickMenuAction) {
        switch action {
        case .search:
            showSearchBar.toggle()
        case .favorites:
            showFavorites.toggle()
        case .appProfiles:
            showAppProfiles.toggle()
        case .joystick:
            if !joystickActive && routeSimulator.isSimulating {
                if let position = routeSimulator.currentPosition {
                    let coordinate = CoordTransform.gcj02ToWgs84(position)
                    lat = coordinate.latitude
                    long = coordinate.longitude
                }
                routeSimulator.stopSimulation()
            }
            withAnimation(.spring(response: 0.3)) {
                joystickActive.toggle()
                if joystickActive {
                    joystickCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
                }
            }
        case .route:
            joystickActive = false
            showRouteSheet.toggle()
        case .altitude:
            UIApplication.shared.TextFieldAlert(
                title: "Set Altitude",
                message: "Enter the altitude in meters.",
                textFieldPlaceHolder: "Altitude (m)"
            ) { altitudeText, _ in
                if let altText = altitudeText, !altText.isEmpty {
                    self.altitude = altText
                    AlertKitAPI.present(title: "Altitude Set!", icon: .done, style: .iOS17AppleMusic, haptic: .success)
                }
            }
        case .settings:
            showSettings = true
        case .timer:
            showTimerPicker = true
        case .stop:
            stopSimulation()
        }
    }
    
    private func stopSimulation() {
        routeSimulator.stopSimulation()
        joystickActive = false
        cancelTimer()
        AlertKitAPI.present(title: "Stopped!", icon: .done, style: .iOS17AppleMusic, haptic: .success)
    }
    
}
