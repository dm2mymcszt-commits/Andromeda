import Foundation
import CoreLocation

// Swift implementation of the Open Location Code algorithm, adapted from
// google/open-location-code (Apache-2.0). See THIRD-PARTY-NOTICES.md.
enum OpenLocationCode {
    static let alphabet = Array("23456789CFGHJMPQRVWX")
    struct Area {
        let south: Double, west: Double, north: Double, east: Double
        var center: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: min(90, (south + north) / 2),
                                   longitude: min(180, (west + east) / 2))
        }
    }

    static func isValid(_ code: String) -> Bool {
        let chars = Array(code.uppercased())
        guard let separator = chars.firstIndex(of: "+"), separator <= 8,
              separator % 2 == 0, chars.filter({ $0 == "+" }).count == 1,
              chars.count > 1, chars.count - separator - 1 != 1 else { return false }
        if let pad = chars.firstIndex(of: "0") {
            guard separator == 8, pad > 0, pad % 2 == 0, chars.last == "+",
                  (separator - pad) % 2 == 0,
                  chars[pad..<separator].allSatisfy({ $0 == "0" }) else { return false }
        }
        return chars.allSatisfy { alphabet.contains($0) || $0 == "+" || $0 == "0" }
    }

    static func isShort(_ code: String) -> Bool {
        isValid(code) && Array(code).firstIndex(of: "+")! < 8
    }

    static func decode(_ code: String) -> Area? {
        guard isValid(code), !isShort(code) else { return nil }
        let digits = Array(code.uppercased().filter { $0 != "+" && $0 != "0" }.prefix(15))
        guard digits.count >= 2, let firstLat = alphabet.firstIndex(of: digits[0]), firstLat < 9,
              let firstLon = alphabet.firstIndex(of: digits[1]), firstLon < 18 else { return nil }
        let values = digits.map { alphabet.firstIndex(of: $0)! }
        var latitude = -90.0, longitude = -180.0
        var latSize = 20.0, lonSize = 20.0
        let pairs = min(10, values.count)
        for index in stride(from: 0, to: pairs, by: 2) {
            latSize = 20 / pow(20, Double(index / 2))
            lonSize = latSize
            latitude += Double(values[index]) * latSize
            longitude += Double(values[index + 1]) * lonSize
        }
        if values.count > 10 {
            for index in 10..<values.count {
                latSize /= 5
                lonSize /= 4
                latitude += Double(values[index] / 4) * latSize
                longitude += Double(values[index] % 4) * lonSize
            }
        }
        return Area(south: latitude, west: longitude, north: latitude + latSize, east: longitude + lonSize)
    }

    static func recover(_ short: String, near reference: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
        if let area = decode(short) { return area.center }
        guard isShort(short), CLLocationCoordinate2DIsValid(reference) else { return nil }
        let missing = 8 - Array(short).firstIndex(of: "+")!
        let resolution = pow(20, Double(2 - missing / 2))
        let prefix = String(encodePairs(reference).prefix(missing))
        guard let area = decode(prefix + short.uppercased()) else { return nil }
        var center = area.center
        if reference.latitude + resolution / 2 < center.latitude && center.latitude - resolution >= -90 {
            center.latitude -= resolution
        } else if reference.latitude - resolution / 2 > center.latitude && center.latitude + resolution <= 90 {
            center.latitude += resolution
        }
        if reference.longitude + resolution / 2 < center.longitude { center.longitude -= resolution }
        else if reference.longitude - resolution / 2 > center.longitude { center.longitude += resolution }
        center.longitude = normalizedLongitude(center.longitude)
        return center
    }

    private static func normalizedLongitude(_ longitude: Double) -> Double {
        let remainder = (longitude + 180).truncatingRemainder(dividingBy: 360)
        return (remainder < 0 ? remainder + 360 : remainder) - 180
    }

    private static func encodePairs(_ coordinate: CLLocationCoordinate2D) -> String {
        let latitude = min(90 - 0.00000004, max(-90, coordinate.latitude))
        var lat = Int(floor(latitude * 25_000_000)) + 90 * 25_000_000
        var lon = Int(floor(normalizedLongitude(coordinate.longitude) * 8_192_000)) + 180 * 8_192_000
        lat /= 3125
        lon /= 1024
        var code = ""
        for divisor in [160000, 8000, 400, 20, 1] {
            code.append(alphabet[(lat / divisor) % 20])
            code.append(alphabet[(lon / divisor) % 20])
            if code.count == 8 { code.append("+") }
        }
        return code
    }
}

enum PlaceInput {
    case coordinate(CLLocationCoordinate2D)
    case plusCode(String, town: String)
    case link(URL)
    case text(String)

    static func parse(_ input: String) -> PlaceInput {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let coordinate = coordinates(text) { return .coordinate(coordinate) }
        if let match = captures(#"^([23456789CFGHJMPQRVWX0]*\+[23456789CFGHJMPQRVWX]*)(?:\s+(.+))?$"#, text),
           OpenLocationCode.isValid(match[0]) {
            if let full = OpenLocationCode.decode(match[0]) { return .coordinate(full.center) }
            return .plusCode(match[0], town: match.count > 1 ? match[1] : "")
        }
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
           let match = detector.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let url = match.url, MapPlaceLink.isSupported(url) { return .link(url) }
        return .text(text)
    }

    static func coordinates(_ text: String) -> CLLocationCoordinate2D? {
        if let parts = captures(#"^\s*\(?([+-]?\d{1,3}(?:\.\d+)?)\s*[,;\s]\s*([+-]?\d{1,3}(?:\.\d+)?)\)?\s*$"#, text),
           let lat = Double(parts[0]), let lon = Double(parts[1]) { return valid(lat, lon) }
        let normalized = text.replacingOccurrences(of: "′", with: "'")
            .replacingOccurrences(of: "″", with: "\"").replacingOccurrences(of: "’", with: "'")
        let pattern = #"^\s*(\d{1,3})\s*[°º]\s*(\d{1,2})\s*'\s*(\d{1,2}(?:[.,]\d+)?)\s*\"?\s*([NS])\s*[,;]?\s*(\d{1,3})\s*[°º]\s*(\d{1,2})\s*'\s*(\d{1,2}(?:[.,]\d+)?)\s*\"?\s*([EW])\s*$"#
        guard let p = captures(pattern, normalized) else { return nil }
        func number(_ index: Int) -> Double { Double(p[index].replacingOccurrences(of: ",", with: "."))! }
        guard number(1) < 60, number(2) < 60, number(5) < 60, number(6) < 60 else { return nil }
        let lat = (number(0) + number(1) / 60 + number(2) / 3600) * (p[3].uppercased() == "S" ? -1 : 1)
        let lon = (number(4) + number(5) / 60 + number(6) / 3600) * (p[7].uppercased() == "W" ? -1 : 1)
        return valid(lat, lon)
    }

    static func valid(_ lat: Double, _ lon: Double) -> CLLocationCoordinate2D? {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }

    static func captures(_ pattern: String, _ text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
        }
    }
}

struct MapPlaceLink {
    var coordinate: CLLocationCoordinate2D?
    var query: String?
    var camera: CLLocationCoordinate2D?

    static func isSupported(_ url: URL) -> Bool {
        guard ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host?.lowercased() else { return false }
        return ["maps.app.goo.gl", "goo.gl", "maps.apple.com"].contains(host)
            || host.range(of: #"^(?:(?:www|maps|consent)\.)?google\.(?:com|[a-z]{2}|(?:com|co)\.[a-z]{2})$"#,
                          options: .regularExpression) != nil
    }

    static func unwrapped(_ url: URL) -> URL {
        var current = url
        for _ in 0..<8 {
            guard current.host?.hasPrefix("consent.google.") == true,
                  let value = URLComponents(url: current, resolvingAgainstBaseURL: false)?.queryItems?
                    .first(where: { $0.name == "continue" })?.value,
                  let next = URL(string: value), isSupported(next), next != current else { break }
            current = next
        }
        return current
    }

    static func parse(_ input: URL) -> MapPlaceLink {
        let url = unwrapped(input)
        let text = url.absoluteString.removingPercentEncoding ?? url.absoluteString
        func value(_ key: String) -> String? {
            // Decode form spaces before percent escapes: %2B is the plus-code
            // separator, whereas a literal + in a query means a space.
            guard let encoded = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .percentEncodedQueryItems?.first(where: { $0.name == key })?.value else { return nil }
            return encoded.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
        }
        var result = MapPlaceLink()
        if let pair = PlaceInput.captures(#"!3d([+-]?\d+(?:\.\d+)?)!4d([+-]?\d+(?:\.\d+)?)"#, text),
           let lat = Double(pair[0]), let lon = Double(pair[1]) { result.coordinate = PlaceInput.valid(lat, lon) }
        for key in ["q", "query", "ll", "coordinate"] where result.coordinate == nil {
            if let value = value(key), let coordinate = PlaceInput.coordinates(value) { result.coordinate = coordinate }
        }
        if let pair = PlaceInput.captures(#"@([+-]?\d+(?:\.\d+)?),([+-]?\d+(?:\.\d+)?)"#, text),
           let lat = Double(pair[0]), let lon = Double(pair[1]) { result.camera = PlaceInput.valid(lat, lon) }
        result.query = [value("q"), value("query")].compactMap { $0 }
            .first { !$0.isEmpty && PlaceInput.coordinates($0) == nil }
        if result.query == nil,
           let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath,
           let name = PlaceInput.captures(#"/maps/place/([^/]+)"#, path)?.first {
            result.query = name.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
        }
        return result
    }
}

// Redirect headers only: never download or scrape a Google result page.
final class MapLinkResolver: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }

    func resolve(_ original: URL) async throws -> MapPlaceLink {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var url = MapPlaceLink.unwrapped(original)
        var visited = Set<String>()
        for _ in 0..<8 {
            try Task.checkCancellation()
            guard MapPlaceLink.isSupported(url), visited.insert(url.absoluteString).inserted else { break }
            let parsed = MapPlaceLink.parse(url)
            if parsed.coordinate != nil || parsed.query != nil || parsed.camera != nil { return parsed }
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            let (_, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse,
                  (300..<400).contains(response.statusCode), let location = response.value(forHTTPHeaderField: "Location"),
                  let next = URL(string: location, relativeTo: url)?.absoluteURL else { return parsed }
            url = MapPlaceLink.unwrapped(next)
        }
        throw URLError(.cannotParseResponse)
    }
}
