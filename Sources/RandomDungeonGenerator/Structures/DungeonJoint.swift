import Geometry

public struct DungeonJointID: ExpressibleByStringLiteral, Hashable, Codable {
    public typealias StringLiteralType = String
    public typealias ExtendedGraphemeClusterLiteralType = String
    public typealias UnicodeScalarLiteralType = String
    
    public var rawValue: String
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
    
    public static let nonSpatial: DungeonJointID = "non-spatial"
}

public struct DungeonJoint: Hashable, Codable {
    public var id: DungeonJointID
    public var segmentId: DungeonSegmentID
    public var position: Point
    public var direction: DungeonJointDirections
    
    /// Representation of a joint that is occupies no space, functions like a glue for relationships.
    /// Evaluated like a special case
    public static let nonSpatial = DungeonJoint(id: .nonSpatial, segmentId: "", position: .zero, direction: .none)
    
    public init(
        id: DungeonJointID,
        segmentId: DungeonSegmentID,
        position: Point,
        direction: DungeonJointDirections
    ) {
        self.id = id
        self.segmentId = segmentId
        self.position = position
        self.direction = direction
    }
    
    public func matchesWith(other: DungeonJoint, ignoringPosition: Bool = false) -> Bool {
        switch (self.direction, other.direction) {
        case (.north, .south):
            return ignoringPosition || self.position.y > other.position.y
        case (.south, .north):
            return ignoringPosition || self.position.y < other.position.y
        case (.east, .west):
            return ignoringPosition || self.position.x < other.position.x
        case (.west, .east):
            return ignoringPosition || self.position.x > other.position.x
        default:
            return false
        }
    }
    
    public func offsetBy(_ by: Point) -> DungeonJoint {
        DungeonJoint(
            id: id,
            segmentId: segmentId,
            position: position.offsetBy(by),
            direction: direction
        )
    }
}
