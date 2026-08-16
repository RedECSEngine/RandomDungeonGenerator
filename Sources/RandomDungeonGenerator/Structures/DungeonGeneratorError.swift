public enum DungeonGeneratorError: Error, Hashable {
    case segmentDoesNotAllowCopies(DungeonSegmentID)
    case segmentCannotStretch(DungeonSegmentID, DungeonJointDirections)
    case stretchExceedsMaximum(
        DungeonSegmentID,
        DungeonJointDirections,
        requested: Double,
        maximum: Double
    )
    case missingSegment(DungeonSegmentID)
    case missingJoint(DungeonJointID)
    case fillerJointsMisaligned(DungeonSegmentID)
}
