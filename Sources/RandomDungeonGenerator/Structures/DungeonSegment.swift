import Geometry

public typealias DungeonSegmentID = String

public protocol DungeonSegment: Hashable, Codable, Identifiable {
    var id: DungeonSegmentID { get }
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
