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
    @AppStorage("tapMapToSetLocation") private var tapMapToSetLocation = false
    @AppStorage("askBeforeMoving") private var askBeforeMoving = true
    @StateObject private var mapMove = MapMoveController()
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
                              allowsLocationSelection: tapMapToSetLocation,
                              onSelectRoute: { index in
                                  guard !routeSimulator.isSimulating else { return }
                                  routeSimulator.selectRoute(at: index)
                              }, mapStyle: mapStyle,
                              proposedPosition: mapMove.pendingRequest?.coordinate)
                    .onAppear {
                        CLLocationManager().requestAlwaysAuthorization()
                    }
                    .onChange(of: tappedCoordinate) { newCoord in
                        guard let coord = newCoord else { return }
                        tappedCoordinate = nil
                        mapMove.request(coord.coordinate,
                            displayCoordinate: CoordTransform.gcj02ToWgs84(coord.coordinate),
                            enabled: tapMapToSetLocation, ask: askBeforeMoving,
                            routeRunning: routeSimulator.isSimulating) { coordinate in
                            startSimulation(at: coordinate, altitude: Double(altitude) ?? 0)
                        }
                    }
                    .ignoresSafeArea()
                
            // MARK: - Map Controls
            FloatingQuickMenu(
                onAction: { action in
                    handleQuickMenuAction(action)
                },
                joystickActive: joystickActive,
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
            
        }
        .modifier(MapMoveConfirmation(controller: mapMove))
        .onChange(of: tapMapToSetLocation) { _ in mapMove.cancel() }
        .onChange(of: askBeforeMoving) { _ in mapMove.cancel() }
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
                let coord = CoordTransform.wgs84ToGcj02(CLLocationCoordinate2D(latitude: favLat, longitude: favLong))
                let region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                mapRegion = region
                startSimulation(at: coord, altitude: Double(altitude) ?? 0.0)
                AlertKitAPI.present(title: "📍 \(name)", icon: .done, style: .iOS17AppleMusic, haptic: .success)
            }
        }

    }
    
    private func startSimulation(at gcjCoordinate: CLLocationCoordinate2D, altitude: Double) {
        mapMove.cancel()
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
    
    // MARK: - Quick Menu Handler
    private func handleQuickMenuAction(_ action: QuickMenuAction) {
        // A pending map proposal must not appear over a newly opened tool.
        mapMove.cancel()
        switch action {
        case .search:
            showSearchBar.toggle()
        case .favorites:
            showFavorites.toggle()
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
        case .stop:
            stopSimulation()
        }
    }
    
    private func stopSimulation() {
        mapMove.cancel()
        routeSimulator.stopSimulation()
        joystickActive = false
        AlertKitAPI.present(title: "Stopped!", icon: .done, style: .iOS17AppleMusic, haptic: .success)
    }
    
}
