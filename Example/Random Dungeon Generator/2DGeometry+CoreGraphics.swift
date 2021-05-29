import SpriteKit
import RandomDungeonGenerator

extension Point {
    var cgPoint: CGPoint {
        return CGPoint(x: x, y: y)
    }
}

extension Rect {
    var cgRect: CGRect {
        return CGRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
    }
}
