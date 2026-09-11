import Foundation

enum AddressQuery {
    static func isAddress(_ text: String) -> Bool {
        text.rangeOfCharacter(from: .decimalDigits) != nil &&
            (text.contains(",") || text.range(of: #"\b\d+-\d+-\d+\b|\b(?:st|rd|cr|av|bd|pkwy|street|road|rue|str|avenue|chome)\b|丁目|番地|улица|شارع"#,
                                            options: [.regularExpression, .caseInsensitive]) != nil)
    }

    // Keep the pasted spelling as the first query. Ambiguous abbreviations get
    // alternatives, rather than a country selector or a replacement of the input.
    static func variants(_ input: String) -> [String] {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var expanded = text
        let rules: [(String, String)] = [
            (#"\b(?:cr|crs)\.?\s+(?=\p{L})"#, "Cours "),
            (#"\bpkwy\.?\b"#, "Parkway"), (#"\brd\.?\b"#, "Road"),
            (#"\bblvd\.?\b"#, "Boulevard"), (#"\bbd\.?\s+"#, "Boulevard "),
            (#"\bave\.?\s+"#, "Avenue "), (#"\bav\.?\s+"#, "Avenida "),
            (#"\bdr\.?\s*(?=,|$)"#, "Drive"), (#"\bln\.?\s*(?=,|$)"#, "Lane"),
            (#"\bhwy\.?\b"#, "Highway"), (#"\bct\.?\s*(?=,|$)"#, "Court"),
            (#"\bst\.?\s*(?=,|$)"#, "Street "),
            (#"\bstr\.\s*"#, "Straße "), (#"(?<=\p{L})str\.(?=\s|,|$)"#, "straße"),
            (#"\bplz\.\s*"#, "Platz "), (#"\bp\.za\s+"#, "Piazza "),
            (#"\bv\.le\s+"#, "Viale "), (#"\bctra\.?\s+"#, "Carretera "),
            (#"\bc\/\s*"#, "Calle "), (#"\bpg\.?\s+"#, "Passeig "),
            (#"\btrav\.?\s+"#, "Travessa "), (#"\bestr\.?\s+"#, "Estrada "),
            (#"\br\.\s+"#, "Rua "), (#"\bul\.\s+"#, "ulica "),
            (#"\bal\.\s+"#, "aleja "),
            (#"\bcd\.\s+"#, "Caddesi "), (#"\bsk\.\s+"#, "Sokak "),
            (#"\bmah\.\s+"#, "Mahallesi "), (#"\bstraat\b"#, "straat"),
            (#"\bул\.\s*"#, "улица "), (#"\bпр-т\s*"#, "проспект "),
            (#"\bпер\.\s*"#, "переулок "), (#"\bнаб\.\s*"#, "набережная "),
            (#"\bвул\.\s*"#, "вулиця "), (#"\bбул\.\s*"#, "бульвар "),
            (#"\b(\d+)\s+Chome[-\s]+(\d+)[-\s]+(\d+)\b"#, "$1-$2-$3")
        ]
        for (pattern, replacement) in rules {
            expanded = expanded.replacingOccurrences(of: pattern, with: replacement,
                options: [.regularExpression, .caseInsensitive])
        }
        // A street suffix followed by a town (not only a comma) is common in
        // copied English addresses. Avoid changing leading Saint names.
        expanded = expanded.replacingOccurrences(of: #"^(\d+\s+.+?)\s+St\.?\s+"#,
            with: "$1 Street ", options: [.regularExpression, .caseInsensitive])
        var candidates = [text, expanded]
        if expanded.contains("Avenida ") { candidates.append(expanded.replacingOccurrences(of: "Avenida ", with: "Avenue ")) }
        if expanded.contains("Calle ") { candidates.append(expanded.replacingOccurrences(of: "Calle ", with: "Carrer ")) }
        if let parts = PlaceInput.captures(#"^(\d+)-(\d+)-(\d+)\s+([^,]+),.*?([^,]+?)\s+(\d{3}-\d{4}),\s*Japan$"#, expanded) {
            candidates.append("\(parts[3]) \(parts[0])-\(parts[1])-\(parts[2]) \(parts[4]) \(parts[5])")
        }
        var unique: [String] = []
        for candidate in candidates {
            let value = candidate.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\s+,"#, with: ",", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !unique.contains(value) { unique.append(value) }
        }
        return unique
    }

    static func canonical(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func houseNumber(_ text: String) -> String? {
        if let japanese = PlaceInput.captures(#"\b\d+(?:\s+Chome)?-\d+-(\d+)\b"#, text) { return japanese[0] }
        if let first = PlaceInput.captures(#"^\s*(\d+[a-z]?(?:\s+(?:bis|ter))?)\s+"#, text) { return first[0] }
        return PlaceInput.captures(#"(?:,\s*|\s)(\d+[a-z]?)\s*(?:,|\s+-)"#, text)?.first
    }

    static func matchesHouse(_ house: String?, query: String, address: String) -> Bool {
        guard let house = house, let expected = houseNumber(query) else { return false }
        let folded = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        if let parts = PlaceInput.captures(#"\b(\d+)(?:\s+chome)?-(\d+)-(\d+)\b"#, folded) {
            let actual = canonical(house)
            if actual == parts.joined(separator: " ") { return true }
            // Apple separates the chome (district) from its block-building
            // subThoroughfare. Compare both, instead of discarding a valid pin.
            let detail = address.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            if actual == parts[1...2].joined(separator: " ") {
                return detail.range(of: "\\b" + parts[0] + #"\s*[- ]?chome\b"#, options: .regularExpression) != nil
                    || detail.contains(parts[0] + "丁目")
            }
        }
        return canonical(house) == canonical(expected)
    }
}
