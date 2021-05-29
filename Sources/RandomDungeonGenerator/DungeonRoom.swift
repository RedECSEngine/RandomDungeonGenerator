import Foundation
import SpriteKit

public protocol DungeonRoom: AnyObject {
    var rect: Rect { get set }
    init(rect: Rect)
}

public protocol DungeonHallway: AnyObject {
    var points: [Point] { get set }
    var rects: [Rect] { get set }
    init(points: [Point])
}

public extension DungeonRoom where Self: CustomStringConvertible {
    var description: String {
        return rect.center.description
    }
}

public extension DungeonRoom where Self: Hashable {
    var hashValue: Int {
        return rect.center.description.hashValue
    }
}
