import SwiftUI

struct MovingExampleView: View {
    @State private var moving = false
    let file: URL
    
    
    var body: some View {
        Button("Move files") {
            moving = true
        }
        .fileMover(isPresented: $moving, file: file) { result in
            switch result {
            case .success(let file):
                print(file.absoluteString)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
}
