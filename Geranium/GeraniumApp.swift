//
//  AndromedaApp.swift
//  Andromeda
//
//  Developed by son3ra1n.
//

import SwiftUI
@main
struct GeraniumApp: App {
    @StateObject private var appSettings = AppSettings()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    if checkSandbox(), !appSettings.tsBypass, !appSettings.isFirstRun {
                        UIApplication.shared.alert(title:"Andromeda wasn't installed with TrollStore", body:"Unable to create test file. The app cannot work without the correct entitlements. Please use TrollStore to install it.", withButton:true)
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
}

class AppSettings: ObservableObject {
    @AppStorage("TSBypass") var tsBypass = false
    @AppStorage("isFirstRun") var isFirstRun = true
    @AppStorage("languageCode") var languageCode = ""
    @AppStorage("mapAppearance") var mapAppearance = "system"
    @AppStorage("mapStyle") var mapStyle = "standard"
    @AppStorage("mapButtonLabels") var mapButtonLabels = true
    @AppStorage("mapHaptics") var mapHaptics = true
}

var langaugee: String = {
    if AppSettings().languageCode.isEmpty {
        return "\(Locale.current.languageCode ?? "en-US")"
    }
    else {
        return "\(Locale.current.languageCode ?? "en")-\(AppSettings().languageCode)"
    }
}()
