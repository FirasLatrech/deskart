import SwiftUI

@main
struct DeskArtApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("DeskArt", systemImage: "sparkles.rectangle.stack") {
            ContentView().environmentObject(model)
        }
        .menuBarExtraStyle(.window)
    }
}
