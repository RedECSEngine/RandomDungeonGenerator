import Geometry
import Graphs

public struct DungeonGrouping: DungeonSegment {
    public let id: DungeonSegmentID
    public let from: DungeonSegmentID
    public let to: DungeonSegmentID

    public let fromJoint: DungeonJoint
    public let toJoint: DungeonJoint
    private let originalJoints: [DungeonJoint]
    private let originalFromRects: [Rect]
    private let originalToRects: [Rect]

    public var offset: Point = .zero
    
    public var containingRect: Rect {
        var minX: Double = .greatestFiniteMagnitude
        var minY: Double = .greatestFiniteMagnitude
        var maxX: Double = 0
        var maxY: Double = 0
        for rect in (originalFromRects + originalToRects) {
            minX = min(minX, rect.origin.x)
            minY = min(minY, rect.origin.y)
            maxX = max(maxX, rect.origin.x + rect.size.width)
            maxY = max(maxY, rect.origin.y + rect.size.height)
        }
        return Rect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        ).offset(by: offset)
    }
    
    public var rects: [Rect] {
        let rects = (originalFromRects + originalToRects)
        if offset == .zero {
            return rects
        }
        return rects
            .map { $0.offset(by: offset) }
    }
    
    public var joints: [DungeonJoint] {
        if offset == .zero {
            return originalJoints        }
        return originalJoints
            .map {
                DungeonJoint(
                    position: $0.position.offsetBy(offset),
                    direction: $0.direction
                )
            }
    }
    
    public var segmentIDs: [DungeonSegmentID] { [from, to] }

    public init<FromSegment: DungeonSegment, ToSegment: DungeonSegment>(
        id: String,
        from: FromSegment,
        to: ToSegment,
        fromJoint: DungeonJoint,
        toJoint: DungeonJoint
    ) {
        self.id = id
        self.from = from.id
        self.to = to.id
        self.fromJoint = fromJoint
        self.toJoint = toJoint
        self.originalJoints = from.joints + to.joints
        self.originalFromRects = from.rects
        self.originalToRects = to.rects
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
