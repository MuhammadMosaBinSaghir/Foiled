import SwiftUI

struct Columns: View {
    @State var cord: CGFloat = 1000
    
    var body: some View {
        VStack(alignment: .leading) {
            Slider(value: $cord, in: 50...2000, step: 50)
            Airfoil(id: "74-130 WP2", cord: cord)
        }
        .padding()
        .toolbar {
            Parser(to: .documentDirectory, as: "library")
        }
    }
}

#Preview {
    Columns()
}
