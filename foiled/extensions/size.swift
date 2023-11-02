import SwiftUI

extension CGSize {
    func relative(to rect: CGRect) -> Self {
        CGSize(
            width: self.width*rect.width,
            height: self.height*rect.height
        )
    }
}
