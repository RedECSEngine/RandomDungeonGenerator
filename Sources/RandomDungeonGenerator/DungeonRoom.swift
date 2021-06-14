import Foundation
import SpriteKit
import Geometry

public protocol DungeonRoom: Equatable, Hashable, Codable {
    var rect: Rect { get set }
    init(rect: Rect)
}

public protocol DungeonHallway: Equatable, Hashable, Codable {
    var points: [Point] { get set }
    var rects: [Rect] { get set }
    init(points: [Point])
}

public extension DungeonRoom where Self: CustomStringConvertible {
    var description: String {
        return rect.center.description
    }
}
