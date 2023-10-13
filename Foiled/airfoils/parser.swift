import SwiftUI

struct Parser: View {
    @State private var show = false
    @State var file: String
    @State var path: FileManager.SearchPathDirectory
    
    var body: some View {
        Button {
            show.toggle()
        } label: {
            Label("Parse", systemImage: "square.and.arrow.down")
        }
        .fileImporter(
            isPresented:
                $show,
            allowedContentTypes: [.directory]) { result in
                process(result)
            }
    }
    
    init(to path: FileManager.SearchPathDirectory, as file: String) {
        self.show = false
        self.file = file
        self.path = path
    }
    
    private func process(_ result: Result<URL, Error>) {
        switch result {
        case .success(let directory):
            let access = directory.startAccessingSecurityScopedResource()
            if !access { return }
            guard let contours = try? Set<Contour>.extract(from: directory, format: ".dat") else { return }
            try? contours.write(
                to: FileManager.default.urls(for: path, in: .userDomainMask).first!,
                as: file
            )
            directory.stopAccessingSecurityScopedResource()
        case .failure(let error): print(error)
        }
    }
}
