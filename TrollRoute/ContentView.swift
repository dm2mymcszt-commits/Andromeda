import SwiftUI

struct ContentView: View {
    @AppStorage("mapAppearance") private var appearance = "system"
    var body: some View {
        LocSimView()
            .tint(.indigo)
            .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
    }
}
