import Geometry

public enum DungeonHallwayType: String, Codable {
    case northSouth
    case eastWest
    case corner
}

public protocol DungeonHallway: DungeonSegment {
    var rects: [Rect] { get set }
    var joints: [DungeonJoint] { get } // implicitly exists as assuming center of each edge
    var stretchEastWest: [Rect]? { get } // implicitly true for each direction
    var stretchNorthSouth: [Rect]? { get } // implicitly handled via multiple rects going different directions
    
    init(id: String, type: DungeonHallwayType, from: DungeonJoint, to: DungeonJoint)
}

public struct DefaultDungeonHallway: DungeonHallway, Equatable, Hashable, Codable {
    public var id: String
    public var rects: [Rect] = []
    public var joints: [DungeonJoint] = []
    public var stretchEastWest: [Rect]?
    public var stretchNorthSouth: [Rect]?
    
    public static func == (lhs: DefaultDungeonHallway, rhs: DefaultDungeonHallway) -> Bool {
        lhs.joints == rhs.joints && lhs.rects == rhs.rects
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(joints)
        hasher.combine(rects)
    }

    public init(id: String, type: DungeonHallwayType, from: DungeonJoint, to: DungeonJoint) {
        self.id = id
        self.joints = [from, to]
        switch type {
        case .northSouth:
            stretchNorthSouth = [
                Rect(origin: from.position, size: .init(width: 1, height: 1)),
                Rect(origin: to.position, size: .init(width: 1, height: 1))
            ]
        case .eastWest:
            stretchEastWest = [
                Rect(origin: from.position, size: .init(width: 1, height: 1)),
                Rect(origin: to.position, size: .init(width: 1, height: 1))
            ]
        case .corner:
            break
        }
    }
}
