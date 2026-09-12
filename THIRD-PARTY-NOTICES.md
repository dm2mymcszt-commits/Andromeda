# Map data and software credits

- Apple Maps results use MapKit and Core Location.
- OpenStreetMap contributors supply OSM results under the [Open Database License](https://www.openstreetmap.org/copyright), through [Photon](https://github.com/komoot/photon). Its public service permits moderate use, including search as you type. Andromeda debounces typing, caches repeated queries, and spaces requests by at least 1.25 seconds.
- Bicycle directions use the worldwide [FOSSGIS OSRM service](https://routing.openstreetmap.de/about.html) and OpenStreetMap data. Andromeda identifies its requests, reserves at least 1.1 seconds between requests, and reuses calculated routes when switching modes or changing speed. Maps displaying bicycle routes include attribution and a map-correction link.
- IGN Geoplateforme supplies address data from the Base Adresse Nationale under its applicable [open-data terms](https://geoservices.ign.fr/services-geoplateforme-geocodage). It is an automatic supplemental source.
- `PlaceInput.swift` contains a Swift adaptation of the [Open Location Code algorithm](https://github.com/google/open-location-code), licensed under Apache License 2.0. The adaptation implements decoding and short-code recovery. Upstream test vectors retain that license. See [LICENSE-OpenLocationCode.txt](LICENSE-OpenLocationCode.txt).

No Google result pages are downloaded or scraped. Shared short links are expanded using HTTP redirect headers only; name-only links use the same search sources as typed text.
