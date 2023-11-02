import SwiftUI

struct Mover: View {
    @State private var moving = false
    
    let file: URL
    
    private let folder = "/Users/administrator/Library/Containers/Shimmer.Foiled/Data"
    
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
