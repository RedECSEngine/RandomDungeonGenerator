import Geometry
import Graphs

public extension Edge where VertexType == DungeonSegmentID, EdgeType == DungeonGrouping {
    var grouping: EdgeType {
        get { data }
        set { data = newValue }
    }
}

public struct DungeonGrouping: Hashable, Codable, Identifiable {
    public let id: DungeonSegmentID
    
    public let from: DungeonSegmentID
    public let to: DungeonSegmentID
    public let fromJoint: DungeonJointID
    public let toJoint: DungeonJointID

    public var segmentIDs: [DungeonSegmentID] { [from, to] }

    public init(
        id: DungeonSegmentID,
        from: DungeonSegmentID,
        to: DungeonSegmentID,
        fromJoint: DungeonJointID,
        toJoint: DungeonJointID
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.fromJoint = fromJoint
        self.toJoint = toJoint
    }
}
