import SwiftUI

@main
struct Foiled: App {
    var body: some Scene {
        WindowGroup {
            Navigation()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
