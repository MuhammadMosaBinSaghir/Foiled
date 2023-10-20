import SwiftUI

func NACA(camber: Int, position: Int, thickness: Int, density: Int) {
    let c: Double = 0.01*Double(camber)
    let p: Double = 0.1*Double(position)
    let t: Double = 0.01*Double(thickness)
    let trailing: Int = 2*density - 2
    let constants: [Double] = [ 0.2969, -0.126, -0.3516, 0.2843, -0.1036 ]
    
    func CamberOrdinate(x: Double) -> (base: Double, gradient: Double) {
        let base: Double = x < p ?
        c*(2.0*p*x - (pow(x, 2))) / (pow(p, 2)) : c*(1 - 2*p + 2*p*x - (pow(x, 2))) / (pow(1-p, 2))
        let gradient: Double = x < p ?
        2.0*c*(p - x) / (pow(p, 2)) : 2*c*(p - x) / (pow(1-p, 2))
        return (base: base, gradient: gradient)
    }
    
    func ThicknessOrdinate(x: Double) -> Double {
        let argument: [Double] = [ constants[0]*(pow(x, 0.5)), constants[1]*x, constants[2]*(pow(x, 2)), constants[3]*(pow(x, 3)), constants[4]*(pow(x, 4)) ]
        return 5*t*(argument[0] + argument[1] + argument[2] + argument[3] + argument[4])
    }
    
    var upper = [CGPoint]()
    var lower = [CGPoint]()
    
    for i in 1...density+1 {
        let alpha: Double = Double.pi*Double(i - 1) / Double(density - 1)
        let x: Double = 0.5*(1 - cos(alpha))
        let camber = CamberOrdinate(x: x)
        let base = camber.base
        let gradient = camber.gradient
        let layer = ThicknessOrdinate(x: x)
        let theta = atan(gradient)
        let absciss =  layer*sin(theta)
        let ordinate = layer*cos(theta)
        upper.append(CGPoint(x: CGFloat(x-absciss), y: CGFloat(base + ordinate)))
        lower.append(CGPoint(x: CGFloat(x + absciss), y: CGFloat(base - ordinate)))
    }
    upper.removeAll(where: {$0.x == 1} )
    lower.removeAll(where: {$0.x == 1} )
    upper.append(CGPoint(x: 1, y: 0))
    lower.append(CGPoint(x: 1, y: 0))
    lower.removeFirst()
    let contour = upper.reversed() + lower
    var text = """
    {
        "name": "NACA 0012",
        "coordinates": [\n
    """
    for i in 0...contour.count-2 {
        text.append("       {\"x\": \(contour[i].x), \"y\": \(contour[i].y)},\n")
    }
    guard let last = contour.last else { return }
    text.append("       {\"x\": \(last.x), \"y\": \(last.y)}\n")
    text.append("   ]\n")
    text.append("},\n")
    print(text)
}
