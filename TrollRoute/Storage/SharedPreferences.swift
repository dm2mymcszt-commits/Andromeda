import Foundation

/// The new app and its extensions keep preferences in one stable group domain.
/// This also survives the later removal of the app's no-container entitlement.
enum SharedPreferences {
    static let suite = "group.com.dm2mymcszt.trollroute"
    static let defaults: UserDefaults = {
        let group = UserDefaults(suiteName: suite)!
        // Preserve any preferences created by the intermediate new-identity
        // build, before group storage was introduced. This is TrollRoute's own
        // domain, never the old app's domain.
        let ownKeys = ["TSBypass", "isFirstRun", "languageCode", "routeFinishAction",
            "routeFinishDestination", "routeRecentPlaces.v1", "routeSpeedKmh.walking",
            "routeSpeedKmh.cycling", "routeSpeedKmh.driving", "altitudeProfile",
            "mapAppearance", "mapStyle", "mapButtonLabels", "mapHaptics",
            "tapMapToSetLocation", "askBeforeMoving"]
        for key in ownKeys where group.object(forKey: key) == nil {
            if let value = UserDefaults.standard.object(forKey: key) { group.set(value, forKey: key) }
        }
        return group
    }()
}
