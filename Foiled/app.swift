import SwiftUI

@main
struct Foiled: App {
    var body: some Scene {
        WindowGroup {
            Navigation()
        }
        .windowToolbarStyle(.unified)
        .windowResizability(.contentSize)
    }
}
