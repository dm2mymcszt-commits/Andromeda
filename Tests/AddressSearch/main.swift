import Foundation
import CoreLocation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
}
func close(_ coordinate: CLLocationCoordinate2D?, _ lat: Double, _ lon: Double, _ message: String) {
    require(coordinate != nil, message + " missing coordinate")
    require(distance(coordinate!, CLLocationCoordinate2D(latitude: lat, longitude: lon)) < 0.2, message)
}
let abbreviations = [
    ("125 Cr Gambetta, 33400 Talence", "125 Cours Gambetta, 33400 Talence"),
    ("1600 Amphitheatre Pkwy, Mountain View", "1600 Amphitheatre Parkway, Mountain View"),
    ("10 Downing St, London SW1A 2AA", "10 Downing Street, London SW1A 2AA"),
    ("C/ de Mallorca, 401, Barcelona", "Carrer de Mallorca, 401, Barcelona"),
    ("Av. Paulista, 1578 - Bela Vista", "Avenida Paulista, 1578 - Bela Vista"),
    ("12 Bd Victor Hugo, Lyon", "12 Boulevard Victor Hugo, Lyon"),
    ("Friedrichstr. 10, Berlin", "Friedrichstraße 10, Berlin"),
    ("5 P.za del Duomo, Milano", "5 Piazza del Duomo, Milano"),
    ("1 Chome-1-2 Oshiage, Tokyo", "1-1-2 Oshiage, Tokyo"),
    ("ул. Ленина 1, Москва", "улица Ленина 1, Москва")
]
for (original, expanded) in abbreviations {
    let variants = AddressQuery.variants(original)
    require(variants.first == original, "Original query was lost: \(original)")
    require(variants.contains(expanded), "Expansion missing: \(original): \(variants)")
}
require(AddressQuery.variants("St Pancras International").first == "St Pancras International", "POI input changed")
require(AddressQuery.isAddress("10 Downing St, London SW1A 2AA, UK"), "Worldwide address must use unrestricted full search")
require(AddressQuery.isAddress("Oshiage 1-1-2 Tokyo 131-0045"), "Compact block address misclassified as a place name")
require(AddressQuery.matchesHouse("1-2", query: "1 Chome-1-2 Oshiage, Tokyo", address: "1-2, Oshiage 1-Chōme, Tokyo"), "Split district/block/building match")
require(!AddressQuery.matchesHouse("1-2", query: "1 Chome-1-2 Oshiage, Tokyo", address: "1-2, Oshiage 2-Chōme, Tokyo"), "Wrong district accepted")
require(!AddressQuery.matchesHouse("3-2", query: "1 Chome-1-2 Oshiage, Tokyo", address: "3-2, Oshiage 1-Chōme, Tokyo"), "Wrong block accepted")
require(!AddressQuery.matchesAddressText(query: "10 Downing St, London", result: "10 Pentland Street, London"), "Same number on a different street must be approximate")
require(AddressQuery.matchesAddressText(query: "10 Downing St, London", result: "10 Downing Street, London"), "Street suffix expansion comparison")
require(AddressQuery.matchesAddressText(query: "1 Chome-1-2 Oshiage, Tokyo", result: "1-2, Oshiage 1-Chōme, Tokyo"), "Split block text comparison")
close(PlaceInput.coordinates("44.817059, -0.585746"), 44.817059, -0.585746, "Decimal")
close(PlaceInput.coordinates("44°49'01.4\"N 0°35'08.7\"W"), 44.81705556, -0.58575, "DMS")
close(PlaceInput.coordinates("44°49′01,4″N 0°35′08,7″W"), 44.81705556, -0.58575, "DMS typographic/comma")
require(PlaceInput.coordinates("91, 2") == nil && PlaceInput.coordinates("44°60'01\"N 0°35'08\"W") == nil, "Invalid coordinates accepted")

let pinURL = URL(string: "https://www.google.com/maps/place/Test/@48.0,2.0,15z/data=!3d44.817059!4d-0.585746?q=47,3&ll=46,4")!
close(MapPlaceLink.parse(pinURL).coordinate, 44.817059, -0.585746, "Place pin must win over q, ll and camera")
close(MapPlaceLink.parse(URL(string: "https://maps.google.com/?q=44.817059,-0.585746&ll=45,1")!).coordinate,
      44.817059, -0.585746, "q priority")
close(MapPlaceLink.parse(URL(string: "https://maps.apple.com/?ll=44.817059,-0.585746")!).coordinate,
      44.817059, -0.585746, "Apple ll support")
var consent = URLComponents(string: "https://consent.google.com/m")!
consent.queryItems = [URLQueryItem(name: "continue", value: pinURL.absoluteString)]
close(MapPlaceLink.parse(consent.url!).coordinate, 44.817059, -0.585746, "Consent continue URL")
let textLink = MapPlaceLink.parse(URL(string: "https://www.google.com/maps?q=Name%2C%20address&ftid=example")!)
require(textLink.coordinate == nil && textLink.query == "Name, address", "Name-only link lost its query")
require(MapPlaceLink.parse(URL(string: "https://www.google.com/maps?q=8FVC9G8F%2B6X")!).query == "8FVC9G8F+6X", "Escaped plus code must retain its separator")
require(MapPlaceLink.parse(URL(string: "https://www.google.com/maps?q=RQ88%2BR7+Talence")!).query == "RQ88+R7 Talence", "Form spaces must not erase a short plus code")
require(MapPlaceLink.parse(URL(string: "https://www.google.com/maps/place/8FVC9G8F%2B6X/")!).query == "8FVC9G8F+6X", "Path plus code must retain its separator")
let camera = MapPlaceLink.parse(URL(string: "https://www.google.com/maps/@44.817059,-0.585746,15z")!)
require(camera.coordinate == nil, "Camera center must remain a last resort")
close(camera.camera, 44.817059, -0.585746, "Camera fallback")
require(!MapPlaceLink.isSupported(URL(string: "https://google.com.example.org/maps")!), "Lookalike host accepted")
if case .link = PlaceInput.parse("A shared place https://maps.app.goo.gl/Example") {} else { fatalError("Shared URL not recognized") }

func rows(_ name: String) -> [[String]] {
    try! String(contentsOfFile: "Tests/AddressSearch/\(name)", encoding: .utf8)
        .split(whereSeparator: \.isNewline).filter { !$0.hasPrefix("#") }
        .map { $0.split(separator: ",", omittingEmptySubsequences: false).map(String.init) }
}
for row in rows("olc-validity.csv") {
    require(OpenLocationCode.isValid(row[0]) == (row[1] == "true"), "OLC validity \(row[0])")
    require(OpenLocationCode.isShort(row[0]) == (row[2] == "true"), "OLC short validity \(row[0])")
    require((OpenLocationCode.decode(row[0]) != nil) == (row[3] == "true"), "OLC full validity \(row[0])")
}
for row in rows("olc-decoding.csv") {
    guard let area = OpenLocationCode.decode(row[0]) else { fatalError("OLC decoding \(row[0])") }
    for (actual, expected) in zip([area.south, area.west, area.north, area.east], row[2...5]) {
        require(abs(actual - Double(expected)!) < 1e-9, "OLC bounds \(row[0]): \(actual) != \(expected)")
    }
}
for row in rows("olc-short.csv") where row[4] != "S" {
    let reference = CLLocationCoordinate2D(latitude: Double(row[1])!, longitude: Double(row[2])!)
    let expected = OpenLocationCode.decode(row[0])!.center
    close(OpenLocationCode.recover(row[3], near: reference), expected.latitude, expected.longitude, "Short OLC \(row[3])")
}
if case .plusCode(_, let town) = PlaceInput.parse("RQ88+R7 Talence") { require(town == "Talence", "Town lost") }
else { fatalError("Short plus code not recognized") }
if case .coordinate = PlaceInput.parse("8FVC9G8F+6X") {} else { fatalError("Full plus code not resolved offline") }

let fixture = """
{"features":[
 {"geometry":{"coordinates":[-0.58,44.81]},"properties":{"label":"125 Cours Gambetta 33400 Talence","name":"125 Cours Gambetta","score":0.92,"type":"housenumber","postcode":"33400"}},
 {"geometry":{"coordinates":[-0.581,44.812]},"properties":{"label":"Cours Gambetta 33400 Talence","score":0.7,"type":"street","postcode":"33400"}},
 {"geometry":{"coordinates":[2.35,48.85]},"properties":{"label":"Different postcode","score":0.9,"type":"housenumber","postcode":"75001"}},
 {"geometry":{"coordinates":[400,200]},"properties":{"label":"Invalid","score":0.9,"type":"housenumber","postcode":"33400"}}
]}
""".data(using: .utf8)!
let decoded = try PlaceProvider.decode(fixture, query: "125 Cours Gambetta, 33400 Talence", national: true)
require(decoded.count == 2 && !decoded[0].place.isApproximate && decoded[1].place.isApproximate, "Precision/postcode filtering")
require(WorldwidePlaceSearch.merge(decoded + decoded).count == 2, "Cross-provider duplicates")
let buildingEntrance = PlaceMatch(place: RoutePlace(name: "125 Cours Gambetta", address: "125 Cours Gambetta, 33400 Talence, France", coordinate: CLLocationCoordinate2D(latitude: 44.81, longitude: -0.5808)), houseNumber: "125", query: "125 Cours Gambetta, 33400 Talence", exact: true, order: 10)
let mergedEntrances = WorldwidePlaceSearch.merge(decoded + [buildingEntrance])
require(mergedEntrances.count == 2 && mergedEntrances.first?.longitude == decoded.first?.place.longitude, "Different provider pins for one numbered building must retain the highest-ranked location once")
let legacy = """
{"id":"D03ED10A-FE78-4CBD-8104-C5E4B1981C21","name":"Saved place","address":"","latitude":44.81,"longitude":-0.58,"source":"old source"}
""".data(using: .utf8)!
let legacyPlace = try JSONDecoder().decode(RoutePlace.self, from: legacy)
require(!legacyPlace.isApproximate, "Existing recents compatibility")
let search = RoutePlaceSearch()
search.query = "44.817059, -0.585746"
require(search.results.count == 1 && !search.isSearching, "Pasted coordinate must resolve immediately")
search.query = "125 Cr Gambetta, 33400 Talence"
search.query = ""
RunLoop.main.run(until: Date().addingTimeInterval(1))
require(search.results.isEmpty && search.suggestions.isEmpty && !search.isSearching, "Cleared query revived stale results")
print("PASS: worldwide expansions, decimal/DMS, Google/Apple/consent/name-only links, upstream OLC vectors, approximation, deduplication, recents and cancellation")

if ProcessInfo.processInfo.environment["LIVE_ADDRESS_LOOKUP"] == "1" {
    // Geographic targets for the user's seven named sites. These coordinates
    // are test expectations only and never included in search code.
    let addresses: [(String, Double, Double)] = [
        ("125 Cr Gambetta, 33400 Talence, France", 44.817059, -0.585746),
        ("1600 Amphitheatre Pkwy, Mountain View, CA 94043, USA", 37.4220, -122.0841),
        ("10 Downing St, London SW1A 2AA, UK", 51.50336, -0.12762),
        ("Unter den Linden 77, 10117 Berlin, Germany", 52.5160, 13.3802),
        ("C/ de Mallorca, 401, L'Eixample, 08013 Barcelona, Spain", 41.40363, 2.17436),
        ("Av. Paulista, 1578 - Bela Vista, São Paulo - SP, 01310-200, Brazil", -23.56142, -46.65588),
        ("1 Chome-1-2 Oshiage, Sumida City, Tokyo 131-0045, Japan", 35.710063, 139.8107)
    ]
    var finished = false
    var failures: [String] = []
    Task {
        for (query, lat, lon) in addresses {
            let places = await WorldwidePlaceSearch.search(query)
            await MainActor.run {
                let target = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let meters = places.first.map { distance(CoordTransform.gcj02ToWgs84($0.coordinate), target) } ?? .infinity
                print("LIVE \(query): first result \(Int(min(meters, 999999))) m; \(places.prefix(4).map { "\($0.name) [\($0.latitude),\($0.longitude)] approximate=\($0.isApproximate)" })")
                fflush(stdout)
                if meters > 50 { failures.append("\(query): \(meters) m") }
            }
        }
        do {
            // Real short URL published by Tokyo Skytree's official access page.
            // Production resolver issues HEAD requests only, never Google HTML.
            let shared = try await WorldwidePlaceSearch.resolve(.link(URL(string: "https://maps.app.goo.gl/NS5hFF6WctREcTmV9")!))
            let meters = shared.first.map { distance($0.coordinate, CLLocationCoordinate2D(latitude: 35.710063, longitude: 139.8107)) } ?? .infinity
            await MainActor.run {
                if meters > 50 { failures.append("Official Google short link: \(meters) m") }
                print("LIVE official Google short link: \(meters) m"); fflush(stdout)
            }
        } catch { await MainActor.run { failures.append("Official Google short link: \(error)") } }
        await MainActor.run { finished = true }
    }
    let deadline = Date().addingTimeInterval(240)
    while !finished && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
    require(finished, "Live worldwide search timed out")
    require(failures.isEmpty, "50 m address checks failed: \(failures)")
    print("PASS: every user-specified address resolves within 50 m in the production worldwide search")
}
