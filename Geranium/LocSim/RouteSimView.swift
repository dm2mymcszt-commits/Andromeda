//  Andromeda LocSim - Route Extension
//  Created by son3ra1n.

import SwiftUI
import MapKit
import AlertKit

struct RouteSimSheet: View {
    @AppStorage("mapStyle") private var mapStyle = "standard"
    @ObservedObject var routeSimulator: RouteSimulator
    @ObservedObject var draft: RouteDraft
    @Binding var mapRegion: MKCoordinateRegion?
    @Binding var isPresented: Bool
    
    @State private var startText: String = ""
    @State private var endText: String = ""
    @State private var startCoord: CLLocationCoordinate2D? = nil
    @State private var endCoord: CLLocationCoordinate2D? = nil
    @State private var selectedMode: TravelMode = .driving
    @StateObject private var currentLocation = RouteCurrentLocation()
    @StateObject private var recentPlaces = RouteRecentPlaces()
    @State private var pickerField: ActiveField?
    @State private var waitingForCurrentStart = false
    @State private var didInitializeStart = false
    @State private var routeReady: Bool = false
    @State private var speedMultiplier: Double = 1.0
    @State private var showGPXPicker: Bool = false
    
    enum ActiveField: String, Identifiable {
        case start, end
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Route Status (when simulating)
                    if routeSimulator.isSimulating {
                        simulationStatusCard
                    } else {
                        // MARK: - Start Point
                        locationCard(
                            title: "Start Point",
                            icon: "play.circle.fill",
                            iconColor: .green,
                            text: startText,
                            selectedCoord: startCoord,
                            field: .start
                        )
                        if waitingForCurrentStart {
                            if currentLocation.isLocating {
                                ProgressView("Finding your current location…")
                            }
                            if let message = currentLocation.message {
                                Text(message).font(.caption).foregroundColor(.secondary).padding(.horizontal)
                                Button("Retry Current Location", action: useCurrentStart)
                            }
                        }
                        
                        // Arrow between cards
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        
                        // MARK: - End Point
                        locationCard(
                            title: "Destination",
                            icon: "flag.checkered.circle.fill",
                            iconColor: .red,
                            text: endText,
                            selectedCoord: endCoord,
                            field: .end
                        )
                        
                        // MARK: - Travel Mode
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Travel Mode")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            HStack(spacing: 12) {
                                ForEach(TravelMode.allCases, id: \.self) { mode in
                                    Button(action: {
                                        guard selectedMode != mode else { return }
                                        selectedMode = mode
                                        invalidateRoute()
                                    }) {
                                        VStack(spacing: 4) {
                                            Image(systemName: mode.icon)
                                                .font(.title2)
                                            Text(mode.rawValue)
                                                .font(.caption)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedMode == mode ?
                                                      Color.accentColor.opacity(0.2) :
                                                      Color(UIColor.secondarySystemBackground))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedMode == mode ?
                                                        Color.accentColor : Color.clear, lineWidth: 2)
                                        )
                                    }
                                    .foregroundColor(selectedMode == mode ? .accentColor : .primary)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // MARK: - Speed Multiplier
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Speed")
                                    .font(.headline)
                                Spacer()
                                Text("\(String(format: "%.1f", speedMultiplier))x (\(formattedSpeed))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            Slider(value: $speedMultiplier, in: 0.5...10.0, step: 0.5)
                                .padding(.horizontal)
                                .onChange(of: speedMultiplier) { _ in
                                    routeSimulator.updateSpeedMultiplier(speedMultiplier)
                                }
                        }
                        
                        // MARK: - Calculate Button
                                Button(action: calculateRoute) {
                                    HStack {
                                        if routeSimulator.isCalculatingRoute {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                                        }
                                        Text(routeSimulator.isCalculatingRoute ? "Calculating..." : "Calculate Routes")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill((startCoord != nil && endCoord != nil) ?
                                                  Color.indigo : Color.gray)
                                    )
                                    .foregroundColor(.white)
                                    .font(.headline)
                                }
                        .disabled(startCoord == nil || endCoord == nil || routeSimulator.isCalculatingRoute)
                        .padding(.horizontal)
                        
                        // MARK: - Route Selection (shown after calculation)
                        if routeReady && !routeSimulator.availableRoutes.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "map.fill")
                                        .foregroundColor(.accentColor)
                                    Text("Select Route")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(routeSimulator.availableRoutes.count) route(s)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)

                                routePreview

                                Text("Times use your simulation speed. Real traffic estimates are shown separately.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                ForEach(Array(routeSimulator.availableRoutes.enumerated()), id: \.element.id) { idx, option in
                                    routeOptionCard(option: option, index: idx)
                                }
                                
                                // Start button
                                Button(action: startRoute) {
                                    HStack {
                                        Image(systemName: "play.fill")
                                        Text("Start Route Simulation")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.green)
                                    )
                                    .foregroundColor(.white)
                                    .font(.headline)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
                .disabled(routeSimulator.isCalculatingRoute)
            }
            .navigationTitle("Andromeda Navigation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        routeSimulator.stopSimulation()
                        invalidateRoute()
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                    .opacity(routeSimulator.isSimulating ? 1 : 0)
                    .disabled(!routeSimulator.isSimulating)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showGPXPicker = true }) {
                        Image(systemName: "doc.badge.plus")
                            .foregroundColor(.indigo)
                            .font(.title3)
                    }
                    .opacity(routeSimulator.isSimulating ? 0 : 1)
                    .disabled(routeSimulator.isSimulating)
                }
            }
            .sheet(item: $pickerField) { field in
                RouteLocationPicker(
                    title: field == .start ? "Start Point" : "Destination",
                    region: searchRegion,
                    selectedCoordinate: field == .start ? startCoord : endCoord,
                    recents: recentPlaces,
                    useCurrentLocation: field == .start ? useCurrentStart : nil,
                    select: { selectPlace($0, field: field) }
                )
            }
            .sheet(isPresented: $showGPXPicker) {
                GPXDocumentPicker { url in
                    guard let result = GPXParser.parse(url: url), !result.isEmpty else {
                        UIApplication.shared.alert(body: "Failed to parse GPX file or file is empty.")
                        return
                    }
                    
                    let coords = result.allCoordinates
                    if coords.count >= 2 {
                        waitingForCurrentStart = false
                        currentLocation.cancel()
                        invalidateRoute()
                        // Use first and last as start/end
                        startCoord = coords.first
                        endCoord = coords.last
                        startText = "GPX Start"
                        endText = "GPX End (\(coords.count) points)"
                        
                        // Fit map to route
                        let centerLat = coords.map { $0.latitude }.reduce(0, +) / Double(coords.count)
                        let centerLon = coords.map { $0.longitude }.reduce(0, +) / Double(coords.count)
                        mapRegion = MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                        
                        AlertKitAPI.present(title: "GPX Loaded! \(coords.count) pts", icon: .done, style: .iOS17AppleMusic, haptic: .success)
                    }
                }
            }
        }
        .onAppear {
            if !didInitializeStart {
                didInitializeStart = true
                if draft.start != nil || draft.destination != nil {
                    startCoord = draft.start?.coordinate
                    startText = draft.start?.name ?? ""
                    endCoord = draft.destination?.coordinate
                    endText = draft.destination?.name ?? ""
                    selectedMode = routeSimulator.travelMode
                    speedMultiplier = routeSimulator.currentSpeedMultiplier
                    if draft.needsRecalculation && !routeSimulator.isSimulating {
                        invalidateRoute()
                        draft.needsRecalculation = false
                    } else { routeReady = !routeSimulator.availableRoutes.isEmpty }
                    if startCoord == nil && !routeSimulator.isSimulating { useCurrentStart() }
                } else if !routeSimulator.availableRoutes.isEmpty {
                    startCoord = routeSimulator.routeStart
                    endCoord = routeSimulator.routeEnd
                    startText = "Route Start"
                    endText = "Destination"
                    selectedMode = routeSimulator.travelMode
                    speedMultiplier = routeSimulator.currentSpeedMultiplier
                    routeReady = true
                } else if !routeSimulator.isSimulating {
                    useCurrentStart()
                }
            }
        }
        .onChange(of: routeSimulator.isSimulating) { running in
            if !running && draft.needsRecalculation {
                invalidateRoute()
                draft.needsRecalculation = false
                if startCoord == nil { useCurrentStart() }
            }
        }
        .onDisappear {
            currentLocation.cancel()
            draft.start = startCoord.map { RoutePlace(name: startText, coordinate: $0) }
            draft.destination = endCoord.map { RoutePlace(name: endText, coordinate: $0) }
        }
        .onReceive(currentLocation.$location) { location in
            guard waitingForCurrentStart, let location = location else { return }
            startCoord = CoordTransform.wgs84ToGcj02(location.coordinate)
            startText = "Current Location"
            waitingForCurrentStart = false
            invalidateRoute()
        }
    }
    
    private var routePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            CustomMapView(
                tappedCoordinate: .constant(nil), moveToRegion: .constant(nil),
                routePolyline: routeSimulator.routePolyline,
                allRoutePolylines: routeSimulator.allRoutePolylines,
                selectedRouteIndex: routeSimulator.selectedRouteIndex,
                routeETAs: routeSimulator.simulatedRouteETAs,
                allowsLocationSelection: false,
                onSelectRoute: { routeSimulator.selectRoute(at: $0) },
                fitsRoutes: true, showsUserLocation: false, mapStyle: mapStyle
            )
            .frame(height: 340)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            Text("Tap a numbered route to select it. A is the start; B is the destination.")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: - Route Option Card
    private func routeOptionCard(option: RouteOption, index: Int) -> some View {
        RouteChoiceCard(
            number: index + 1,
            name: option.name,
            roadName: option.route.name,
            distance: option.distanceText,
            roadETA: option.trafficTimeText,
            simulationETA: option.simulationTimeText(mode: selectedMode, speedMultiplier: speedMultiplier),
            speed: formattedSpeed,
            isSelected: routeSimulator.selectedRouteIndex == index,
            select: { routeSimulator.selectRoute(at: index) }
        )
        .padding(.horizontal)
    }

    // MARK: - Simulation Status Card
    private var simulationStatusCard: some View {
        VStack(spacing: 16) {
            // Progress
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: selectedMode.icon)
                        .foregroundColor(.accentColor)
                    Text("Route in Progress")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(routeSimulator.progress * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                }
                
                ProgressView(value: routeSimulator.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                
                HStack {
                    Text("Point \(routeSimulator.currentPointIndex)/\(routeSimulator.totalPoints)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Duration: \(routeSimulator.estimatedTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            
            // Controls
            HStack(spacing: 20) {
                Button(action: {
                    routeSimulator.togglePause()
                }) {
                    HStack {
                        Image(systemName: routeSimulator.isPaused ? "play.fill" : "pause.fill")
                        Text(routeSimulator.isPaused ? "Resume" : "Pause")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.orange)
                    )
                    .foregroundColor(.white)
                    .font(.headline)
                }
                
                Button(action: {
                    routeSimulator.stopSimulation()
                    routeReady = false
                    AlertKitAPI.present(
                        title: "Route Stopped",
                        icon: .done,
                        style: .iOS17AppleMusic,
                        haptic: .success
                    )
                }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.red)
                    )
                    .foregroundColor(.white)
                    .font(.headline)
                }
            }
            
            // Current position info
            if let pos = routeSimulator.currentPosition {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text(String(format: "%.5f, %.5f", pos.latitude, pos.longitude))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Location Card
    private func locationCard(
        title: String,
        icon: String,
        iconColor: Color,
        text: String,
        selectedCoord: CLLocationCoordinate2D?,
        field: ActiveField
    ) -> some View {
        Button { pickerField = field } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundColor(iconColor).font(.title2)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.caption).foregroundColor(.secondary)
                    Text(text.isEmpty ? "Choose a place" : text)
                        .font(.headline).foregroundColor(.primary)
                    if field == .end && selectedCoord == nil {
                        Text("Search, recent places, or choose on map")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Computed
    private var formattedSpeed: String {
        let baseSpeed = selectedMode.speed * speedMultiplier
        let kmh = baseSpeed * 3.6
        return "\(Int(kmh)) km/h"
    }
    
    // MARK: - Actions
    private var searchRegion: MKCoordinateRegion? {
        if let coordinate = startCoord {
            return MKCoordinateRegion(center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        }
        return mapRegion
    }

    private func invalidateRoute() {
        routeReady = false
        routeSimulator.clearCalculatedRoutes()
    }

    private func useCurrentStart() {
        invalidateRoute()
        startCoord = nil
        startText = "Current Location"
        waitingForCurrentStart = true
        currentLocation.request()
    }

    private func selectPlace(_ place: RoutePlace, field: ActiveField) {
        if field == .start {
            waitingForCurrentStart = false
            currentLocation.cancel()
            startCoord = place.coordinate
            startText = place.name
        } else {
            endCoord = place.coordinate
            endText = place.name
        }
        recentPlaces.remember(place)
        invalidateRoute()
    }

    private func calculateRoute() {
        guard let start = startCoord, let end = endCoord else { return }
        
        routeSimulator.calculateRoutes(from: start, to: end, mode: selectedMode, speedMult: speedMultiplier) { success, error in
            if success {
                routeReady = true
                showRouteOnMap()
            } else {
                UIApplication.shared.alert(body: error ?? "Failed to calculate route")
            }
        }
    }
    
    private func showRouteOnMap() {
        // Fit every alternative, including routes far outside the selected route.
        let rect = routeSimulator.allRoutePolylines.reduce(MKMapRect.null) {
            $0.union($1.boundingMapRect)
        }
        if !rect.isNull {
            let region = MKCoordinateRegion(rect.insetBy(dx: -rect.size.width * 0.2, dy: -rect.size.height * 0.2))
            mapRegion = region
        }
    }
    
    private func startRoute() {
        guard routeReady && !routeSimulator.availableRoutes.isEmpty else { return }
        routeSimulator.startSimulation(altitude: 0.0)
        guard routeSimulator.isSimulating else { return }
        isPresented = false

        AlertKitAPI.present(
            title: "Route Started!",
            icon: .done,
            style: .iOS17AppleMusic,
            haptic: .success
        )
    }
}

// Shared by route setup and the isolated simulator visual check.
struct RouteChoiceCard: View {
    let number: Int
    let name: String
    let roadName: String
    let distance: String
    let roadETA: String
    let simulationETA: String
    let speed: String
    let isSelected: Bool
    let select: () -> Void

    private var color: Color {
        let colors: [Color] = [.blue, .orange, .purple, .pink]
        return colors[(number - 1) % colors.count]
    }

    var body: some View {
        Button(action: select) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(number)")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(color).clipShape(Circle())
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(name).font(.subheadline.weight(.semibold))
                        Spacer(minLength: 4)
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(color)
                        }
                    }
                    if !roadName.isEmpty {
                        Text(roadName).font(.caption).foregroundColor(.secondary).lineLimit(2)
                    }
                    Text("\(simulationETA) · \(distance)")
                        .font(.headline).foregroundColor(.primary)
                    Text("At \(speed) · Real traffic: \(roadETA)")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? color : Color(UIColor.separator), lineWidth: isSelected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Route \(number), \(name), \(simulationETA) at \(speed), \(distance). Real traffic: \(roadETA)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
