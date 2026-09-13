//
//  TrollRouteApp.swift
//  TrollRoute
//
//  Developed by son3ra1n.
//

import SwiftUI
@main
struct TrollRouteApp: App {
    var body: some Scene { WindowGroup { MigrationLaunchView() } }
}

struct ReadyAppView: View {
    @StateObject private var appSettings = AppSettings()
    var body: some View {
            ContentView()
                .onAppear {
                    if checkSandbox(), !appSettings.tsBypass, !appSettings.isFirstRun {
                        UIApplication.shared.alert(title:"TrollRoute wasn't installed with TrollStore", body:"Unable to create test file. The app cannot work without the correct entitlements. Please use TrollStore to install it.", withButton:true)
                    }
                    _ = RootHelper.loadMCM()
                }
                .sheet(isPresented: $appSettings.isFirstRun) {
                    if #available(iOS 16.0, *) {
                        NavigationStack {
                            WelcomeView()
                        }
                    } else {
                        NavigationView {
                            WelcomeView()
                        }
                    }
                }
    }
}

class AppSettings: ObservableObject {
    @AppStorage("TSBypass", store: SharedPreferences.defaults) var tsBypass = false
    @AppStorage("isFirstRun", store: SharedPreferences.defaults) var isFirstRun = true
    @AppStorage("languageCode", store: SharedPreferences.defaults) var languageCode = ""
    @AppStorage("mapAppearance", store: SharedPreferences.defaults) var mapAppearance = "system"
    @AppStorage("mapStyle", store: SharedPreferences.defaults) var mapStyle = "standard"
    @AppStorage("mapButtonLabels", store: SharedPreferences.defaults) var mapButtonLabels = true
    @AppStorage("mapHaptics", store: SharedPreferences.defaults) var mapHaptics = true
}

var langaugee: String = {
    if AppSettings().languageCode.isEmpty {
        return "\(Locale.current.languageCode ?? "en-US")"
    }
    else {
        return "\(Locale.current.languageCode ?? "en")-\(AppSettings().languageCode)"
    }
}()
