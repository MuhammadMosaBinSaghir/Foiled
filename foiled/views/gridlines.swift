import SwiftUI
import Foundation

struct Gridlines {
    let style: (minor: StrokeStyle, major: StrokeStyle)
    let domain: (abscissa: ClosedRange<Double>, ordinate: ClosedRange<Double>)
    let quantity: (minor: Double, major: Double)
    var size: (minor: (abscissa: Double, ordinate: Double), major: (abscissa: Double, ordinate: Double)) {
        (minor: (abscissa: (domain.abscissa.upperBound - domain.abscissa.lowerBound)/quantity.minor,
                 ordinate: (domain.ordinate.upperBound - domain.ordinate.lowerBound)/quantity.minor),
         major: (abscissa: (domain.abscissa.upperBound - domain.abscissa.lowerBound)/quantity.major,
                 ordinate: (domain.ordinate.upperBound - domain.ordinate.lowerBound)/quantity.major))
    }
    var stride: (minor: (abscissa: StrideTo<Double>, ordinate: StrideTo<Double>), major: (abscissa: StrideTo<Double>, ordinate: StrideTo<Double>)) {
        (minor:
            (abscissa: Swift.stride(from: domain.abscissa.lowerBound + size.minor.abscissa, to: domain.abscissa.upperBound, by: size.minor.abscissa),
             ordinate: Swift.stride(from: domain.ordinate.lowerBound + size.minor.ordinate, to: domain.ordinate.upperBound, by: size.minor.ordinate)),
         major:
            (abscissa: Swift.stride(from: domain.abscissa.lowerBound + size.major.abscissa, to: domain.abscissa.upperBound, by: size.major.abscissa),
             ordinate: Swift.stride(from: domain.ordinate.lowerBound + size.major.ordinate, to: domain.ordinate.upperBound, by: size.major.ordinate))
        )
    }
    var minor: (abscissa: [Double], ordinate: [Double]) {
        var minor = (abscissa: [Double](), ordinate: [Double]())
        for gridline in stride.minor.abscissa { minor.abscissa.append(gridline) }
        for gridline in stride.minor.ordinate { minor.ordinate.append(gridline) }
        return minor
    }
    var major: (abscissa: [Double], ordinate: [Double]) {
        var major = (abscissa: [Double](), ordinate: [Double]())
        for gridline in stride.major.abscissa { major.abscissa.append(gridline) }
        for gridline in stride.major.ordinate { major.ordinate.append(gridline) }
        return major
    }
}
