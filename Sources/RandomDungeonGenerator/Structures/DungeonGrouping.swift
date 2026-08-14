import Geometry
import Graphs

public struct DungeonGrouping: DungeonSegment {
    public let id: DungeonSegmentID
    
    public let from: DungeonSegmentID
    public let to: DungeonSegmentID
    public let fromJoint: DungeonJointID
    public let toJoint: DungeonJointID

    public var offset: Point = .zero
    

    
//    public var rects: [Rect] {
//        let rects = (originalFromRects + originalToRects)
//        if offset == .zero {
//            return rects
//        }
//        return rects
//            .map { $0.offset(by: offset) }
//    }
    
//    public var joints: [DungeonJoint] {
//        if offset == .zero {
//            return originalJoints        }
//        return originalJoints
//            .map {
//                DungeonJoint(
//                    position: $0.position.offsetBy(offset),
//                    direction: $0.direction
//                )
//            }
//    }
    
    public var segmentIDs: [DungeonSegmentID] { [from, to] }

    public init<FromSegment: DungeonSegment, ToSegment: DungeonSegment>(
        id: DungeonSegmentID,
        from: FromSegment,
        to: ToSegment,
        fromJoint: DungeonJointID,
        toJoint: DungeonJointID
    ) {
        self.id = id
        self.from = from.id
        self.to = to.id
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
