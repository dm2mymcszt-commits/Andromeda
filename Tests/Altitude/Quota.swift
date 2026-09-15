import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

@main struct QuotaTests {
    static func main() throws {
        let instant = Date(timeIntervalSince1970: 1_800_000_000)
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--reserve" {
            let store = ElevationBudgetStore(url: URL(fileURLWithPath: CommandLine.arguments[2]))
            let delay = try store.reserve(100, at: instant)
            exit(delay == 0 ? 0 : 2)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("budget.json")
        var writers: [Process] = []
        for _ in 0..<12 {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
            process.arguments = ["--reserve", url.path]
            try process.run(); writers.append(process)
        }
        for writer in writers { writer.waitUntilExit() }
        require(writers.filter { $0.terminationStatus == 0 }.count == 6, "Only six 100-coordinate batches fit the shared minute quota")
        require(writers.filter { $0.terminationStatus == 2 }.count == 6, "Other processes must wait, not overspend quota")
        let store = ElevationBudgetStore(url: url)
        let wait = try store.reserve(1, at: instant)
        require(wait == 60, "Fresh process reads other processes' reservations")
        let afterWindow = try store.reserve(100, at: instant.addingTimeInterval(60))
        require(afterWindow == 0, "Reservation succeeds when the first window expires")
        let suite = "trollroute.quota.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let old = ElevationRequestBudget(reservations: [.init(time: instant, count: 600)])
        defaults.set(try JSONEncoder().encode(old), forKey: "elevationRequestBudget.v1")
        let migrated = ElevationBudgetStore(url: directory.appendingPathComponent("migrated.json"), legacyDefaults: defaults)
        let legacyWait = try migrated.reserve(1, at: instant)
        require(legacyWait == 60, "Upgrade must preserve already spent quota")
        defaults.removeObject(forKey: "elevationRequestBudget.v1")
        let persistedWait = try migrated.reserve(1, at: instant)
        require(persistedWait == 60, "The shared file remains authoritative after migration")
        try Data("corrupt".utf8).write(to: url)
        var rejected = false
        do { _ = try store.reserve(1, at: instant) } catch { rejected = true }
        require(rejected, "Corrupt quota must never reset to an empty allowance")
        print("PASS: 12 competing processes, shared weighted quota, expiry, legacy migration and corrupt-ledger refusal")
    }
}
