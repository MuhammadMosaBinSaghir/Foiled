import SwiftUI

@main
struct Foiled: App {
    var body: some Scene {
        WindowGroup {
            Navigation(selected: library.first(where: {$0.name == "NACA 0012"})!)
        }
        .windowToolbarStyle(.unified)
    }
}
