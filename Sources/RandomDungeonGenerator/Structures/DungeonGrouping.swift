import Geometry
import Graphs

public extension Edge where VertexType == DungeonSegmentID, EdgeType == DungeonGrouping {
    var grouping: EdgeType {
        get { data }
        set { data = newValue }
    }
}

public struct DungeonGrouping: DungeonSegment {
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

/*
 
 public struct DungeonGrouping: Codable, Hashable {
     public let id: DungeonSegmentID
     public var offset: Point = .zero
     
     public let fromJoint: DungeonJoint
     public let toJoint: DungeonJoint
     
     public init(
         id: DungeonSegmentID,
         fromJoint: DungeonJoint,
         toJoint: DungeonJoint
     ) {
         self.id = id
         self.fromJoint = fromJoint
         self.toJoint = toJoint
     }
 }

 */
