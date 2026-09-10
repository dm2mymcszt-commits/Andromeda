import Foundation
import CoreLocation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

let query = "125 Cr Gambetta, 33400 Talence"
require(FrenchAddressLookup.isAddress(query), "French abbreviated postal address not recognized")
require(FrenchAddressLookup.normalized(query) == "125 Cours Gambetta, 33400 Talence", "Cours abbreviation")
require(!FrenchAddressLookup.isAddress("10 Downing Street London"), "Worldwide address must stay with Apple")
require(FrenchAddressLookup.normalized("Grand Central New York") == "Grand Central New York", "POI modified")
let url = FrenchAddressLookup.url(for: query)
let parameters = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
require(url.host == "data.geopf.fr", "Wrong IGN service")
require(parameters.map(\.name).sorted() == ["index", "limit", "q"], "Must not transmit device location")

// Synthetic fixture checks precision labels, unrelated postcode rejection, and invalid coordinates.
let json = """
{"features":[
 {"geometry":{"coordinates":[-0.58,44.81]},"properties":{"label":"10 Cours Exemple 33400 Talence","name":"10 Cours Exemple","score":0.92,"type":"housenumber","postcode":"33400"}},
 {"geometry":{"coordinates":[-0.581,44.812]},"properties":{"label":"Cours Exemple 33400 Talence","score":0.7,"type":"street","postcode":"33400"}},
 {"geometry":{"coordinates":[2.35,48.85]},"properties":{"label":"Different postcode","score":0.9,"type":"housenumber","postcode":"75001"}},
 {"geometry":{"coordinates":[400,200]},"properties":{"label":"Invalid coordinate","score":0.9,"type":"housenumber","postcode":"33400"}},
 {"geometry":{"coordinates":[-0.58,44.81]},"properties":{"label":"Poor match","score":0.2,"type":"locality","postcode":"33400"}}
]}
""".data(using: .utf8)!
let results = try FrenchAddressLookup.decode(json, query: query)
require(results.count == 2, "Invalid/weak/unrelated matches were not filtered")
require(results[0].source == "IGN / BAN", "Exact address must identify its source")
require(results[1].source?.contains("street-level") == true, "Approximate result must be identified")
require(results[0].latitude == 44.81 && results[0].longitude == -0.58, "GeoJSON axis order")
let legacy = """
{"id":"D03ED10A-FE78-4CBD-8104-C5E4B1981C21","name":"Saved place","address":"","latitude":44.81,"longitude":-0.58}
""".data(using: .utf8)!
let savedPlace = try JSONDecoder().decode(RoutePlace.self, from: legacy)
require(savedPlace.source == nil, "Old recent places must remain readable")
print("PASS: French abbreviation, provider URL, coordinates, result precision, filtering, and existing recents")

let search = RoutePlaceSearch()
search.query = query
search.query = ""
RunLoop.main.run(until: Date().addingTimeInterval(1))
require(search.results.isEmpty && search.suggestions.isEmpty && !search.isSearching, "Cleared query revived stale results")
print("PASS: canceled search cannot revive results")

if ProcessInfo.processInfo.environment["LIVE_ADDRESS_LOOKUP"] == "1" {
    UserDefaults.standard.set(true, forKey: "frenchAddressLookup")
    search.query = query
    let deadline = Date().addingTimeInterval(35)
    while Date() < deadline && !search.results.contains(where: {
        $0.name == "125 Cours Gambetta" && $0.address.contains("33400 Talence") && $0.source == "IGN / BAN"
    }) {
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }
    require(search.results.contains {
        $0.name == "125 Cours Gambetta" && $0.address.contains("33400 Talence") && $0.source == "IGN / BAN"
    }, "Live address lookup did not return the exact Talence address")
    search.cancel()
    print("PASS: production search returned 125 Cours Gambetta 33400 Talence through IGN / BAN")
}
