
import Foundation

struct Circle {

    var center: Point
    var radius: Double
    
    init(fittedTo rect: Rect) {
        radius = rect.diagonalLength / 2
        center = rect.center
    }
    
    func intersects(_ circle2: Circle) -> Bool {
        
        let radiusDiff = pow(radius - circle2.radius, 2)
        let centerXDiff = pow(center.x - circle2.center.x, 2)
        let centerYDiff = pow(center.y - circle2.center.y, 2)
        let radiusCombine = pow(radius + circle2.radius, 2)
        
        let centerDiffCombine = centerXDiff + centerYDiff
            
        return radiusDiff <= centerDiffCombine
            && centerDiffCombine <= radiusCombine
    }
}