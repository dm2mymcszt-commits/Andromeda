//  TrollRoute LocSim
//  Created by son3ra1n.
//  Enhanced version of Geranium.
//  Developed by son3ra1n.
//

import SwiftUI
import CoreLocation
import MapKit
import AlertKit

struct LocSimView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var routeDraft = RouteDraft()
    @State private var incomingPlace: SharedPlaceRequest?
    @State private var openSharedRoute = false
    @State private var sharedPlaceError: String?
    @AppStorage("mapStyle", store: SharedPreferences.defaults) private var mapStyle = "standard"
    @AppStorage("mapButtonLabels", store: SharedPreferences.defaults) private var mapButtonLabels = true
    @State private var routeControlsCollapsed = false
    @AppStorage("tapMapToSetLocation", store: SharedPreferences.defaults) private var tapMapToSetLocation = false
    @AppStorage("askBeforeMoving", store: SharedPreferences.defaults) private var askBeforeMoving = true
    @StateObject private var mapMove = MapMoveController()
    @StateObject private var routeSimulator = RouteSimulator()
    
    @ObservedObject private var locationSession = LocSimManager.session
    private var referenceCoordinate: CLLocationCoordinate2D {
        locationSession.current?.coordinate ?? locationSession.lastKnown?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
    @State private var showAltitude = false
    @State private var tappedCoordinate: EquatableCoordinate? = nil
    @State private var showRouteSheet: Bool = false
    @State private var showSearchBar: Bool = false
    @State private var showSettings = false
    @StateObject private var recentPlaces = RouteRecentPlaces()
    @State private var mapRegion: MKCoordinateRegion? = nil
    
    // Joystick
    @State private var joystickActive: Bool = false
    
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
                              allRoutePolylines: routeSimulator.displayedPolylines,
                              selectedRouteIndex: routeSimulator.isSimulating ? 0 : routeSimulator.selectedRouteIndex,
                              movingPosition: locationSession.current.map { CoordTransform.wgs84ToGcj02($0.coordinate) },
                              routeETAs: routeSimulator.simulatedRouteETAs,
                              allowsLocationSelection: tapMapToSetLocation,
                              onSelectRoute: { index in
                                  guard !routeSimulator.isSimulating else { return }
                                  routeSimulator.selectRoute(at: index)
                              }, mapStyle: mapStyle,
                              proposedPosition: mapMove.pendingRequest?.coordinate ?? routeSimulator.previewPosition,
                              proposalIsRoutePreview: mapMove.pendingRequest == nil && routeSimulator.previewPosition != nil)
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
                            startSimulation(at: coordinate)
                        }
                    }
                    .ignoresSafeArea()
                
            // MARK: - Map Controls
            ScrollView(showsIndicators: false) {
              FloatingQuickMenu(
                onAction: { action in
                    handleQuickMenuAction(action)
                },
                joystickActive: joystickActive,
                routeActive: routeSimulator.isSimulating
            )
            .padding(.trailing, 12)
            .padding(.top, 12)
            }
            .frame(width: mapButtonLabels ? 156 : 68)
            
            // MARK: - Joystick Overlay
            if joystickActive {
                JoystickView(
                    isActive: $joystickActive,
                    onMove: { newCoord in
                        let location = RouteLocationSample.make(coordinate: newCoord, course: -1, speed: -1, timestamp: Date())
                        locationSession.receive(location, kind: .joystick)
                    },
                    currentCoordinate: { referenceCoordinate }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
            
        }
        .safeAreaInset(edge: .bottom) {
          VStack(spacing: 4) {
            if routeSimulator.isSimulating {
                RoutePlaybackPanel(
                    progress: routeSimulator.progress, elapsed: routeSimulator.elapsedTime,
                    remaining: routeSimulator.remainingTime, remainingDistance: routeSimulator.remainingDistance,
                    isPaused: routeSimulator.isPaused,
                    legName: routeSimulator.legName,
                    speedKmh: Binding(get: { routeSimulator.currentSpeedKmh }, set: { routeSimulator.updateLiveSpeed($0) }),
                    collapsed: $routeControlsCollapsed,
                    preview: routeSimulator.previewSeek, seek: routeSimulator.seek,
                    cancelSeek: routeSimulator.cancelSeek, pause: routeSimulator.togglePause, stop: stopSimulation
                ).padding(.horizontal, 12).padding(.bottom, 6)
            }
            if routeSimulator.travelMode == .cycling && !routeSimulator.availableRoutes.isEmpty {
                Text("© [OpenStreetMap contributors](https://www.openstreetmap.org/copyright) · [Routing](https://routing.openstreetmap.de/about.html) · [Fix the map](https://www.openstreetmap.org/fixthemap)")
                    .font(.caption2).padding(6).background(.regularMaterial)
            }
          }
        }
        .modifier(MapMoveConfirmation(controller: mapMove))
        .onChange(of: tapMapToSetLocation) { _ in mapMove.cancel() }
        .onChange(of: askBeforeMoving) { _ in mapMove.cancel() }
        .onAppear(perform: offerSharedPlace)
        .onChange(of: scenePhase) { phase in if phase == .active { offerSharedPlace() } }
        .sheet(isPresented: $showAltitude, onDismiss: offerSharedPlace) {
            AltitudeSheet(settings: .shared, controller: locationSession.altitudeController)
        }
        .sheet(isPresented: $showSettings, onDismiss: offerSharedPlace) { SettingsView() }
        .sheet(isPresented: $showSearchBar, onDismiss: offerSharedPlace) {
            RouteLocationPicker(title: "Find a place", region: mapRegion,
                selectedCoordinate: nil, recents: recentPlaces) { place in
                recentPlaces.remember(place)
                let coordinate = place.coordinate
                mapRegion = MKCoordinateRegion(center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                startSimulation(at: coordinate)
            }
        }
        .sheet(isPresented: $showRouteSheet, onDismiss: offerSharedPlace) {
            RouteSimSheet(routeSimulator: routeSimulator, draft: routeDraft, mapRegion: $mapRegion, isPresented: $showRouteSheet)
        }
        .sheet(isPresented: $showFavorites, onDismiss: offerSharedPlace) {
            FavoritesView(isPresented: $showFavorites, currentLat: referenceCoordinate.latitude, currentLong: referenceCoordinate.longitude) { favLat, favLong, name in
                let coord = CoordTransform.wgs84ToGcj02(CLLocationCoordinate2D(latitude: favLat, longitude: favLong))
                let region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                mapRegion = region
                startSimulation(at: coord)
                AlertKitAPI.present(title: "📍 \(name)", icon: .done, style: .iOS17AppleMusic, haptic: .success)
            }
        }
        .sheet(item: $incomingPlace, onDismiss: {
            if openSharedRoute { openSharedRoute = false; showRouteSheet = true }
        }) { request in
            IncomingPlaceView(request: request, routeRunning: routeSimulator.isSimulating,
                accept: { handleSharedPlace(request, accept: true) },
                cancel: { handleSharedPlace(request, accept: false) })
        }
        .alert("Shared location", isPresented: Binding(get: { sharedPlaceError != nil }, set: { if !$0 { sharedPlaceError = nil } })) {
            Button("OK", role: .cancel) { sharedPlaceError = nil }
        } message: { Text(sharedPlaceError ?? "") }

    }

    private func offerSharedPlace() {
        guard scenePhase == .active, incomingPlace == nil,
              let request = SharedPlaceInbox().pending().first else { return }
        mapMove.cancel()
        if showAltitude || showSettings || showSearchBar || showRouteSheet || showFavorites {
            showAltitude = false; showSettings = false; showSearchBar = false
            showRouteSheet = false; showFavorites = false
            return // onDismiss offers it after the current sheet has closed.
        }
        incomingPlace = request
    }

    private func handleSharedPlace(_ request: SharedPlaceRequest, accept: Bool) {
        do {
            // Remove before applying so activation cannot repeat an accepted move.
            try SharedPlaceInbox().remove(request)
            incomingPlace = nil
            guard accept, let place = request.place else { return }
            recentPlaces.remember(place)
            switch request.action {
            case .go:
                mapRegion = MKCoordinateRegion(center: place.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                startSimulation(at: place.coordinate)
            case .start, .destination:
                routeDraft.accept(request)
                openSharedRoute = true
            case .favorite:
                try SharedPlaceInbox.saveFavorite(place)
            }
        } catch {
            incomingPlace = nil
            sharedPlaceError = error.localizedDescription
        }
    }
    
    private func startSimulation(at gcjCoordinate: CLLocationCoordinate2D) {
        mapMove.cancel()
        if routeSimulator.isSimulating { routeSimulator.stopSimulation() }
        joystickActive = false
        let wgsCoordinate = CoordTransform.gcj02ToWgs84(gcjCoordinate)
        
        
        let location = RouteLocationSample.make(coordinate: wgsCoordinate, course: 0, speed: 0, timestamp: Date())
        locationSession.receive(location, kind: .stationary)
        
        
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
                routeSimulator.stopSimulation()
            }
            withAnimation(.spring(response: 0.3)) {
                joystickActive.toggle()
            }
        case .route:
            joystickActive = false
            showRouteSheet.toggle()
        case .altitude:
            showAltitude = true
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
