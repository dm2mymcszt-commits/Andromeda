import Foundation
import CoreLocation

@MainActor final class PendingBatch {
    var requests: [([CLLocationCoordinate2D], CheckedContinuation<[Double?]?, Never>)] = []
    var sizes: [Int] = []
    func lookup(_ points: [CLLocationCoordinate2D]) async -> [Double?]? {
        sizes.append(points.count)
        return await withCheckedContinuation { requests.append((points, $0)) }
    }
    func answer() {
        let request = requests.removeFirst()
        request.1.resume(returning: request.0.map { Optional($0.longitude * 10000) })
    }
}

@main struct RouteProfileTests {
    @MainActor static func waitFor(_ condition: () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        preconditionFailure("Timed out waiting for route elevation")
    }
    @MainActor static func main() async {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var budget = ElevationRequestBudget()
        for _ in 0..<6 { budget.reservations.append(.init(time: date, count: 100)) }
        precondition(budget.delay(for: 1, at: date) == 60, "100 coordinates count as 100 calls")
        precondition(budget.delay(for: 100, at: date.addingTimeInterval(60)) == 0)
        budget.reservations = (0..<50).map { _ in .init(time: date.addingTimeInterval(-61), count: 100) }
        precondition(budget.delay(for: 1, at: date) == 3539)
        budget.reservations = (0..<100).map { _ in .init(time: date.addingTimeInterval(-3601), count: 100) }
        precondition(budget.delay(for: 1, at: date) == 82799)
        budget.reservations = (0..<3000).map { _ in .init(time: date.addingTimeInterval(-86401), count: 100) }
        precondition(budget.delay(for: 1, at: date) == 30 * 86400 - 1)
        budget = try! JSONDecoder().decode(ElevationRequestBudget.self, from: JSONEncoder().encode(budget))
        precondition(budget.delay(for: 1, at: date) > 0, "Relaunch cannot reset the reservation budget")
        budget.prune(at: date.addingTimeInterval(31 * 86400))
        precondition(budget.reservations.isEmpty)
        let decoded = ElevationLookup.decodeBatch(Data(#"{"elevation":[1,null,-9999,-20]}"#.utf8), count: 4)!
        precondition(decoded[0] == 1 && decoded[1] == nil && decoded[2] == nil && decoded[3] == -20)
        precondition(ElevationLookup.decodeBatch(Data(#"{"elevation":[1]}"#.utf8), count: 2) == nil)

        func point(_ distance: Double) -> CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: 44, longitude: distance / 10000)
        }
        let plan = ElevationRoutePlan(length: 18000, position: point)
        precondition(plan.points.count == 201 && plan.points.last!.distance == 18000)
        let long = ElevationRoutePlan(length: 1_000_000, position: { _ in point(0) })
        precondition(long.points.count == 1000 && long.points.last!.distance == 1_000_000)
        var sparse = RouteElevationProfile(plan: plan)
        precondition(sparse.meters(at: 500) == nil)
        sparse.heights[0] = 0; sparse.heights[200] = 18000
        precondition(sparse.meters(at: 4500) == 4500 && sparse.meters(at: 17000) == 17000)
        precondition(sparse.meters(at: .nan) == nil)

        let suite = "route-elevation-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AltitudeSettings(defaults: defaults)
        let batch = PendingBatch()
        var input: CLLocation?
        var delivered: [CLLocation] = []
        var singleLookups = 0
        let controller = AltitudeController(settings: settings, defaults: defaults,
            lookup: { _ in singleLookups += 1; return nil }, batchLookup: { await batch.lookup($0) },
            currentLocation: { input }, deliver: { delivered.append($0) })
        func receive(_ distance: Double, speed: Double = 500 / 3.6) {
            input = RouteLocationSample.make(coordinate: point(distance), course: 92, speed: speed, timestamp: date)
            controller.receive(routeDistance: distance)
        }
        controller.prepareRoute(plan)
        await waitFor { batch.requests.count == 1 }
        precondition(delivered.isEmpty, "Preparing terrain must not move an inactive location")
        receive(0)
        precondition(delivered.last!.verticalAccuracy < 0, "No data means unknown, not sea level")
        batch.answer()
        await waitFor { batch.requests.count == 1 && controller.currentMeters != nil }
        for step in 0..<500 {
            receive(min(17000, Double(step) * 500 / 3.6 * 0.25))
            let value = delivered.last!
            precondition(value.verticalAccuracy >= 0 && value.speed == 500 / 3.6 && value.courseAccuracy == 0)
            precondition(value.timestamp == date && value.speedAccuracy == 0)
        }
        receive(17000)
        precondition(abs(controller.currentMeters! - 8910) < 0.001, "Hold last known terrain while next batch is pending")
        settings.setCustom(250)
        precondition(delivered.last!.altitude == 250 && delivered.last!.speed == 500 / 3.6)
        batch.answer()
        await waitFor { batch.requests.count == 1 }
        precondition(delivered.last!.altitude == 250, "Profile download cannot override Custom")
        settings.reset()
        precondition(abs(controller.currentMeters! - 17000) < 0.001)
        receive(4500, speed: 120 / 3.6) // Seeking backwards / a reversed leg uses canonical distance.
        precondition(abs(controller.currentMeters! - 4500) < 0.001)
        receive(4500, speed: 0)
        precondition(delivered.last!.speed == 0 && delivered.last!.courseAccuracy < 0)
        receive(18000)
        batch.answer()
        await waitFor { abs((controller.currentMeters ?? 0) - 18000) < 0.001 }
        precondition(abs(controller.currentMeters! - 18000) < 0.001)
        precondition(batch.sizes == [100, 100, 1] && singleLookups == 0)
        controller.finishRoute()
        controller.receive()
        precondition(abs(controller.currentMeters! - 18000) < 0.001, "Held destination keeps its terrain height")
        controller.prepareRoute(plan)
        try? await Task.sleep(nanoseconds: 20_000_000)
        precondition(batch.sizes.count == 3, "Mode/route revisit reuses a completed profile")

        let other = ElevationRoutePlan(length: 1000, position: point)
        controller.prepareRoute(other)
        await waitFor { batch.requests.count == 1 }
        receive(500)
        let count = delivered.count
        input = nil; controller.stop(); batch.answer()
        try? await Task.sleep(nanoseconds: 20_000_000)
        precondition(delivered.count == count && controller.currentMeters == nil)

        // A trip that finishes before terrain arrives remains spoofed and can
        // resolve the held point, rather than cancelling every route lookup.
        var heldReply: CheckedContinuation<Double?, Never>?
        var held: CLLocation?
        let shortTrip = AltitudeController(settings: settings, defaults: defaults, interval: 0,
            lookup: { _ in await withCheckedContinuation { heldReply = $0 } },
            batchLookup: { $0.map { _ in nil } }, currentLocation: { input }, deliver: { held = $0 })
        shortTrip.prepareRoute(other)
        input = RouteLocationSample.make(coordinate: point(1000), course: 92, speed: 0, timestamp: date)
        shortTrip.receive(routeDistance: 1000)
        precondition(held!.verticalAccuracy < 0)
        shortTrip.finishRoute(resumeLookup: true)
        await waitFor { heldReply != nil }
        heldReply!.resume(returning: 33)
        await waitFor { held?.altitude == 33 }
        precondition(held!.speed == 0 && held!.courseAccuracy < 0 && held!.coordinate.longitude == point(1000).longitude)
        input = nil; shortTrip.stop()
        print("PASS: weighted persistent budget, batches <=100, bounded plan, interpolation, 500 km/h continuity, custom/reset, seek/reverse distance, pause, held destination, cache and Stop cancellation")
    }
}
