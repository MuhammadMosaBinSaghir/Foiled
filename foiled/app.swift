import SwiftUI

@main
struct Foiled: App {
    var body: some Scene {
        WindowGroup {
            Navigation(selected: library.first(where: {$0.name == "20-32C"})!)
        }
        .windowToolbarStyle(.unified)
    }
}
