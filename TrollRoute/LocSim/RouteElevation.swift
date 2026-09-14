import Foundation
import CoreLocation

struct ElevationRoutePoint: Equatable {
    let distance: Double
    let latitude: Double
    let longitude: Double
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

struct ElevationRoutePlan: Equatable {
    let points: [ElevationRoutePoint]
    init(length: Double, position: (Double) -> CLLocationCoordinate2D) {
        guard length.isFinite, length > 0 else { points = []; return }
        // Match the 90 m DEM on ordinary trips. Bound memory/network work on
        // long trips by increasing spacing, while retaining both endpoints.
        let segments = Int(min(999, max(1, ceil(length / 90))))
        points = (0...segments).map { index in
            let distance = length * Double(index) / Double(segments)
            let coordinate = position(distance)
            return ElevationRoutePoint(distance: distance, latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }
}

struct RouteElevationProfile {
    let plan: ElevationRoutePlan
    var heights: [Double?]
    init(plan: ElevationRoutePlan) {
        self.plan = plan
        heights = Array(repeating: nil, count: plan.points.count)
    }
    func meters(at distance: Double) -> Double? {
        guard distance.isFinite else { return nil }
        let known = heights.indices.filter { heights[$0]?.isFinite == true }
        guard let first = known.first, let last = known.last else { return nil }
        if distance <= plan.points[first].distance { return heights[first] }
        if distance >= plan.points[last].distance { return heights[last] }
        guard let upper = known.firstIndex(where: { plan.points[$0].distance >= distance }), upper > 0 else { return nil }
        let left = known[upper - 1], right = known[upper]
        let span = plan.points[right].distance - plan.points[left].distance
        let fraction = (distance - plan.points[left].distance) / span
        return heights[left]! + (heights[right]! - heights[left]!) * fraction
    }
}

/// Open-Meteo's DemResponder weights a request by its coordinate count, not
/// its HTTP request count. Reserve that weight across all four free windows.
struct ElevationRequestBudget: Codable {
    struct Reservation: Codable { let time: Date; let count: Int }
    var reservations: [Reservation] = []
    static let windows: [(seconds: TimeInterval, limit: Int)] = [
        (60, 600), (3600, 5000), (86400, 10000), (31 * 86400, 300000)
    ]
    mutating func prune(at now: Date) {
        reservations.removeAll { now.timeIntervalSince($0.time) >= 31 * 86400 }
    }
    func delay(for count: Int, at now: Date) -> TimeInterval {
        var delay: TimeInterval = 0
        for window in Self.windows {
            let active = reservations.filter { now.timeIntervalSince($0.time) < window.seconds }
                .sorted { $0.time < $1.time }
            var total = active.reduce(count) { $0 + $1.count }
            for entry in active where total > window.limit {
                total -= entry.count
                delay = max(delay, entry.time.addingTimeInterval(window.seconds).timeIntervalSince(now))
            }
        }
        return max(0, delay)
    }
}

actor ElevationRequestLimiter {
    static let shared = ElevationRequestLimiter()
    private let defaults = SharedPreferences.defaults
    private var budget: ElevationRequestBudget
    init() {
        budget = SharedPreferences.defaults.data(forKey: "elevationRequestBudget.v1")
            .flatMap { try? JSONDecoder().decode(ElevationRequestBudget.self, from: $0) } ?? ElevationRequestBudget()
    }
    func reserve(_ count: Int) async -> Bool {
        guard (1...100).contains(count) else { return false }
        while !Task.isCancelled {
            let now = Date()
            budget.prune(at: now)
            let delay = budget.delay(for: count, at: now)
            if delay <= 0 {
                budget.reservations.append(.init(time: now, count: count))
                defaults.set(try? JSONEncoder().encode(budget), forKey: "elevationRequestBudget.v1")
                return true
            }
            do { try await Task.sleep(nanoseconds: UInt64(min(60, delay) * 1_000_000_000)) }
            catch { return false }
            // Recheck after suspension: another caller may have reserved first.
        }
        return false
    }
}

/// One cancellable selected-route request, with an eight-route in-memory cache.
/// Partial results become usable immediately; failures retry with a backoff.
final class RouteElevationLoader {
    private let lookup: ([CLLocationCoordinate2D]) async -> [Double?]?
    private let changed: (RouteElevationProfile) -> Void
    private let retryInterval: TimeInterval
    private var cache: [RouteElevationProfile] = []
    private var task: Task<Void, Never>?
    private var token = UUID()
    private(set) var profile: RouteElevationProfile?

    init(retryInterval: TimeInterval = 60,
         lookup: @escaping ([CLLocationCoordinate2D]) async -> [Double?]? = ElevationLookup.fetchBatch,
         changed: @escaping (RouteElevationProfile) -> Void) {
        self.retryInterval = retryInterval
        self.lookup = lookup
        self.changed = changed
    }
    func prepare(_ plan: ElevationRoutePlan) {
        guard !plan.points.isEmpty else { cancel(); profile = nil; return }
        if profile?.plan == plan, task != nil { return }
        cancel()
        if let cached = cache.first(where: { $0.plan == plan }) {
            profile = cached; changed(cached); return
        }
        profile = RouteElevationProfile(plan: plan)
        changed(profile!)
        let generation = token
        task = Task { @MainActor [weak self] in
            guard let self = self else { return }
            var offset = 0
            while offset < plan.points.count, !Task.isCancelled, self.token == generation {
                let end = min(offset + 100, plan.points.count)
                let points = Array(plan.points[offset..<end].map(\.coordinate))
                let values = await self.lookup(points)
                guard !Task.isCancelled, self.token == generation else { return }
                guard let values = values, values.count == points.count else {
                    do { try await Task.sleep(nanoseconds: UInt64(self.retryInterval * 1_000_000_000)) }
                    catch { return }
                    continue
                }
                self.profile!.heights.replaceSubrange(offset..<end,
                    with: values.map { value in value.flatMap { $0.isFinite && $0 != -9999 ? $0 : nil } })
                self.changed(self.profile!)
                offset = end
            }
            guard !Task.isCancelled, self.token == generation, let profile = self.profile else { return }
            self.cache.append(profile)
            if self.cache.count > 8 { self.cache.removeFirst() }
            self.task = nil
        }
    }
    func cancel() { token = UUID(); task?.cancel(); task = nil }
}
