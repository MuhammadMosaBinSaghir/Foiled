import SwiftUI

struct Content: View {
    @State var model = Model(name: "test", accuracy: 0.01)

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Importer()
            Button("Run") {
                //model.point(at: .zero)
                //model.point(at: .one)
                //try? model.line(from: "A", to: "B")
                //model.update()
                //model.mesh()
                //model.build()
                //processFilesInSubdirectory()
            }
        }
        .padding()
    }
}

#Preview {
    Content()
}
