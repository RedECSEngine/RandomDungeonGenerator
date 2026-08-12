import Geometry
import Graphs

public struct DungeonGrouping: DungeonSegment {
    public let id: DungeonSegmentID
    public let from: DungeonSegmentID
    public let to: DungeonSegmentID

    public let fromJoint: DungeonJoint
    public let toJoint: DungeonJoint
    public let joints: [DungeonJoint]

    public let fromRects: [Rect]
    public let toRects: [Rect]

    public var offset: Point = .zero
    
    public var rects: [Rect] {
        fromRects + toRects
    }
    
    public var segmentIDs: [DungeonSegmentID] { [from, to] }

    public init<FromSegment: DungeonSegment, ToSegment: DungeonSegment>(
        id: String,
        from: FromSegment,
        to: ToSegment,
        fromJoint: DungeonJoint,
        toJoint: DungeonJoint,
        fromRects: [Rect],
        toRects: [Rect]
    ) {
        self.id = id
        self.from = from.id
        self.to = to.id
        self.fromJoint = fromJoint
        self.toJoint = toJoint
        self.joints = from.joints + to.joints
        self.fromRects = fromRects
        self.toRects = toRects
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
