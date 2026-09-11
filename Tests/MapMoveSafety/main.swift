import Foundation
import CoreLocation

func require(_ value: @autoclosure () -> Bool, _ message: String) {
    if !value() { fatalError(message) }
}
let point = CLLocationCoordinate2D(latitude: 44.817059, longitude: -0.585746)
var moves: [CLLocationCoordinate2D] = []
var callbacks: [(String?) -> Void] = []
var cancellations = 0
let controller = MapMoveController(addressWait: 0.03) { _, completion in
    callbacks.append(completion)
    return { cancellations += 1 }
}
func tap(enabled: Bool, ask: Bool, running: Bool = false) {
    controller.request(point, displayCoordinate: point, enabled: enabled, ask: ask,
                       routeRunning: running) { moves.append($0) }
}

for ask in [true, false] {
    tap(enabled: false, ask: ask, running: true)
    require(moves.isEmpty && controller.pendingRequest == nil && callbacks.isEmpty,
            "Disabled taps must not move, geocode, or create a pin for either confirmation preference")
}
tap(enabled: true, ask: false, running: true)
require(moves.count == 1 && controller.pendingRequest == nil && callbacks.isEmpty,
        "Enabled immediate tap did not move exactly once")
moves.removeAll()

tap(enabled: true, ask: true, running: true)
let first = controller.pendingRequest!
require(moves.isEmpty && controller.presentedRequest == nil, "A proposed pin must not move location")
callbacks[0]("125 Cours Gambetta, Talence")
require(controller.presentedRequest?.message.contains("125 Cours Gambetta") == true, "Fast address omitted")
require(controller.presentedRequest?.message.contains("44.81706, -0.58575") == true, "Coordinates omitted")
require(controller.presentedRequest?.message.contains("stop the running route") == true, "Route warning omitted")
controller.cancel()
require(controller.pendingRequest == nil && controller.presentedRequest == nil && moves.isEmpty,
        "Cancel must remove the pin and leave location unchanged")
callbacks[0]("Late response")
controller.confirm(first)
require(controller.pendingRequest == nil && controller.presentedRequest == nil && moves.isEmpty,
        "Canceled geocoding or confirmation revived an old move")

tap(enabled: true, ask: true)
let second = controller.pendingRequest!
tap(enabled: true, ask: true)
let third = controller.pendingRequest!
callbacks[1]("Obsolete address")
controller.confirm(second)
require(moves.isEmpty && controller.pendingRequest?.id == third.id, "Old request replaced the latest pin")
callbacks[2]("Current address")
require(controller.presentedRequest?.address == "Current address", "Latest address not displayed")
require(!controller.presentedRequest!.message.contains("stop the running route"), "Idle tap warned about a route")
// SwiftUI can clear the presentation binding before dispatching the alert button.
controller.presentedRequest = nil
controller.confirm(third)
controller.confirm(third)
require(moves.count == 1 && controller.pendingRequest == nil, "Move must commit once after presentation dismissal")
require(moves[0].latitude == point.latitude && moves[0].longitude == point.longitude, "Move changed coordinates")
moves.removeAll()

tap(enabled: true, ask: true)
RunLoop.main.run(until: Date().addingTimeInterval(0.06))
require(controller.presentedRequest != nil && controller.presentedRequest?.address == nil,
        "Slow lookup blocked coordinates-only confirmation")
callbacks.last!("Too late")
require(controller.presentedRequest?.address == nil, "Late address changed an already visible alert")
controller.cancel()
tap(enabled: true, ask: true)
controller.cancel() // Settings change / Stop while a pin is pending.
RunLoop.main.run(until: Date().addingTimeInterval(0.06))
require(controller.presentedRequest == nil && controller.pendingRequest == nil && moves.isEmpty,
        "Cancel did not invalidate the scheduled prompt")
require(cancellations >= 5, "Pending address work was not canceled")
controller.request(CLLocationCoordinate2D(latitude: 1000, longitude: 0), displayCoordinate: point,
                   enabled: true, ask: false, routeRunning: false) { moves.append($0) }
require(moves.isEmpty, "Invalid tap injected a location")
print("PASS: every toggle combination; no movement before confirmation; Cancel; stale requests; exact-once Move; fast/slow addresses; route warning; invalid input")
