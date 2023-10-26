import Foundation
import Charts

extension CGFloat: Plottable {
    public var primitivePlottable: Double { Double(self) }
    public init?(primitivePlottable: Double) {
        self.init(CGFloat(primitivePlottable))
    }
}
