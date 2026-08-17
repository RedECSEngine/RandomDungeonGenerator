import Geometry

public struct DungeonConnectionPlan {
    public let fromJoint: DungeonJoint
    public let toJoint: DungeonJoint
    public let movingSegmentId: DungeonSegmentID
    public let delta: Point

    public init(
        fromJoint: DungeonJoint,
        toJoint: DungeonJoint,
        movingSegmentId: DungeonSegmentID,
        delta: Point
    ) {
        self.fromJoint = fromJoint
        self.toJoint = toJoint
        self.movingSegmentId = movingSegmentId
        self.delta = delta
    }
}
