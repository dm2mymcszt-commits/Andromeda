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

let mainStop = MainStopController()
var stopped = 0
for running in [false, true] {
    mainStop.request(confirm: true, routeRunning: running) { stopped += 1 }
    let request = mainStop.presentedRequest!
    require(stopped == 0, "Main Stop must not stop or pause before confirmation")
    require(request.message.contains("running route") == running, "Main Stop warning must reflect the route")
    mainStop.cancel()
    mainStop.confirm(request)
    require(stopped == 0, "Cancel must preserve spoofing and invalidate confirmation")
}
mainStop.request(confirm: true, routeRunning: true) { stopped += 1 }
let obsolete = mainStop.presentedRequest!
mainStop.request(confirm: true, routeRunning: false) { stopped += 1 }
let current = mainStop.presentedRequest!
mainStop.confirm(obsolete)
require(stopped == 0, "A stale Stop prompt must not stop a new session")
mainStop.presentedRequest = nil // SwiftUI dismisses before dispatching the button.
mainStop.confirm(current)
mainStop.confirm(current)
require(stopped == 1, "Main Stop must commit once after dismissal")
for running in [false, true] {
    mainStop.request(confirm: false, routeRunning: running) { stopped += 1 }
    require(mainStop.presentedRequest == nil, "Disabled main Stop confirmation must be immediate")
}
require(stopped == 3, "Immediate main Stop must stop exactly once per request")
print("PASS: main Stop ON/OFF, route warning, Cancel, stale prompt and exact-once confirmation")

let routePress = LongPressRouteController()
var lookups: [(Result<CLLocation, Error>) -> Void] = []
var created: [LongPressRouteEndpoints] = []
let chinaWGS = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
let destination = CLLocationCoordinate2D(latitude: 44.9, longitude: -0.6)
func press(enabled: Bool = true, confirm: Bool = false, auto: Bool = false,
           spoof: CLLocationCoordinate2D? = nil, running: Bool = false) {
    routePress.request(destination: destination, enabled: enabled, confirm: confirm, autoStart: auto,
        spoofedStart: spoof, routeRunning: running,
        lookup: { lookups.append($0); return {} }, create: { created.append($0) })
}
press(enabled: false, auto: true, spoof: point)
press(auto: true, spoof: point, running: true)
require(created.isEmpty && lookups.isEmpty && routePress.presentedRequest == nil,
        "Disabled/running-route long press must not calculate, locate or start")
require(routePress.error?.contains("Stop the current route") == true, "Running route needs guidance")
for ask in [false, true] {
    for auto in [false, true] {
        for spoof in [false, true] {
            let count = created.count
            let lookupCount = lookups.count
            press(confirm: ask, auto: auto, spoof: spoof ? chinaWGS : nil)
            if ask {
                let pending = routePress.presentedRequest!
                require(created.count == count && lookups.count == lookupCount,
                        "No route preparation or location access before long-press confirmation")
                routePress.presentedRequest = nil
                routePress.confirmRequest(pending)
                routePress.confirmRequest(pending) // Already resolved spoof must be exactly once.
            }
            if !spoof {
                require(routePress.isLocating && created.count == count, "Real start must wait for a fix")
                lookups.last!(.success(CLLocation(latitude: point.latitude, longitude: point.longitude)))
            }
            require(created.count == count + 1 && !routePress.isLocating, "Exactly one preview per long press")
            let endpoints = created.last!
            let expected = CoordTransform.wgs84ToGcj02(spoof ? chinaWGS : point)
            require(endpoints.start.latitude == expected.latitude && endpoints.start.longitude == expected.longitude,
                    "Current spoof/real WGS start must convert to map coordinates exactly once")
            require(endpoints.destination.latitude == destination.latitude && endpoints.autoStart == auto,
                    "Preview destination and explicit auto-start choice must survive resolution")
        }
    }
}
let count = created.count
press(confirm: true, auto: true)
let canceledPress = routePress.presentedRequest!
routePress.cancel()
routePress.confirmRequest(canceledPress)
require(created.count == count && !routePress.isLocating, "Cancel confirmation must not create or move")
press(auto: true)
let oldLookup = lookups.last!
routePress.cancel()
oldLookup(.success(CLLocation(latitude: 1, longitude: 2)))
require(created.count == count, "Canceled current-location lookup must never auto-start")
press()
lookups.last!(.failure(NSError(domain: "test", code: 1,
    userInfo: [NSLocalizedDescriptionKey: "Precise Location is off."])))
require(created.count == count && routePress.error == "Precise Location is off." && !routePress.isLocating,
        "Denied/reduced/failed current location must explain the problem without creating a route")
print("PASS: long press real/spoof start, coordinate transforms, confirmation/auto-start matrix, disabled/running guard, cancellation and failed location")

let preparation = RoutePreparationController()
var calculations: [(Bool, String?) -> Void] = []
var events: [String] = []
func prepare(_ auto: Bool) {
    preparation.prepare(autoStart: auto, calculate: { calculations.append($0) },
        ready: { events.append("preview") }, start: { events.append("start") },
        failure: { events.append($0 ?? "failure") })
}
prepare(false)
require(events.isEmpty, "Route preparation must wait for directions")
calculations.last!(true, nil)
calculations.last!(true, nil)
require(events == ["preview"], "Default long press prepares once and must never auto-start")
events = []
prepare(true)
calculations.last!(true, nil)
require(events == ["preview", "start"], "Auto-start must occur once, after successful preparation")
events = []
prepare(true)
calculations.last!(false, "No route")
require(events == ["No route"], "Failed directions must never start")
events = []
prepare(true)
let closedCalculation = calculations.last!
preparation.cancel()
closedCalculation(true, nil)
require(events.isEmpty, "Closing Navigation must invalidate pending auto-start")
prepare(true)
let replacedCalculation = calculations.last!
prepare(false)
replacedCalculation(true, nil)
calculations.last!(true, nil)
require(events == ["preview"], "An obsolete calculation must not auto-start a newer preview")
print("PASS: actual preparation-to-start workflow, default preview only, errors, duplicates, closure and replacement")
