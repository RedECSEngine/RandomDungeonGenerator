import Geometry

public struct DungeonJoint: Hashable, Codable {
    public var position: Point
    public var direction: DungeonJointDirections
    
    public static let closed = DungeonJoint(position: .zero, direction: .none)
    
    public init(position: Point, direction: DungeonJointDirections) {
        self.position = position
        self.direction = direction
    }
    
    public func matchesWith(other: DungeonJoint) -> Bool {
        switch (self.direction, other.direction) {
        case (.north, .south):
            return self.position.y > other.position.y
        case (.south, .north):
            return self.position.y < other.position.y
        case (.east, .west):
            return self.position.x < other.position.x
        case (.west, .east):
            return self.position.x > other.position.x
        default:
            return false
        }
    }
}
