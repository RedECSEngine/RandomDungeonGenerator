import Foundation
import Geometry

public struct DefaultDungeonRoom: DungeonRoom, CustomStringConvertible {
    public var rect: Rect

    public init(rect: Rect) {
        self.rect = rect
    }
}

public func == (_ lhs: DefaultDungeonRoom, _ rhs: DefaultDungeonRoom) -> Bool {
    return lhs.rect == rhs.rect
}

public class DefaultDungeonHallway: DungeonHallway, Equatable, Hashable, Codable {
    public static func == (lhs: DefaultDungeonHallway, rhs: DefaultDungeonHallway) -> Bool {
        lhs.points == rhs.points && lhs.rects == rhs.rects
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(points)
        hasher.combine(rects)
    }
    
    public var points: [Point]
    public var rects: [Rect] = []

    public required init(points: [Point]) {
        self.points = points
    }
}
