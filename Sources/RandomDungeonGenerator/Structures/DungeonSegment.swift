import Geometry

public protocol DungeonSegment: Hashable, Codable {
    var joints: [DungeonJoint] { get }
    var rects: [Rect] { get }
}

public extension DungeonSegment {
    var cornerSupport: Bool {
        let directions = joints.reduce(into: DungeonJointDirections.none) {
            $0.insert($1.direction)
        }
        return (
            directions == .cornerNorthWest
            || directions == .cornerSouthEast
            || directions == .cornerSouthWest
            || directions == .cornerNorthEast
        )
    }
}
