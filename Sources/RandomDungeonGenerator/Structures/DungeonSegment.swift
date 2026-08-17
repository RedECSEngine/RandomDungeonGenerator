import Geometry

public typealias DungeonSegmentID = String

public enum DungeonSegmentLayoutCategory: String, Codable, Hashable {
    case room
    case hallway
}

public protocol DungeonSegment: Hashable, Codable, Identifiable {
    var id: DungeonSegmentID { get set }
    var rect: Rect { get set }
    var joints: [DungeonJoint] { get }

    var allowsCopies: Bool { get }
    var layoutCategory: DungeonSegmentLayoutCategory { get }

    var maxStretchEastWest: Double? { get }
    var maxStretchNorthSouth: Double? { get }

    init(
        id: DungeonSegmentID,
        rect: Rect,
        layoutCategory: DungeonSegmentLayoutCategory
    )

    func makeCopy(withId newId: DungeonSegmentID) throws -> Self

    func stretched(
        by amount: Double,
        along axis: DungeonJointDirections,
        anchoredAt anchor: Point
    ) throws -> Self
}

public extension DungeonSegment where Self: CustomStringConvertible {
    var description: String {
        return rect.center.description
    }
}

public extension DungeonSegment {
    var allowsCopies: Bool { false }
    var maxStretchEastWest: Double? { nil }
    var maxStretchNorthSouth: Double? { nil }

    func makeCopy(withId newId: DungeonSegmentID) throws -> Self {
        guard allowsCopies else {
            throw DungeonGeneratorError.segmentDoesNotAllowCopies(id)
        }
        var copy = self
        copy.id = newId
        return copy
    }

    func stretched(
        by amount: Double,
        along axis: DungeonJointDirections,
        anchoredAt anchor: Point
    ) throws -> Self {
        var copy = self
        copy.rect = try stretchedRect(by: amount, along: axis, anchoredAt: anchor)
        return copy
    }

    func maximumStretchedLength(along axis: DungeonJointDirections) -> Double? {
        axis == .eastWest ? maxStretchEastWest : maxStretchNorthSouth
    }

    func length(along axis: DungeonJointDirections) -> Double {
        axis == .eastWest ? rect.size.width : rect.size.height
    }

    func stretchGrowsPositively(
        along axis: DungeonJointDirections,
        anchoredAt anchor: Point
    ) -> Bool {
        axis == .eastWest ? anchor.x <= rect.midX : anchor.y <= rect.midY
    }

    func stretchedJoints(
        by amount: Double,
        along axis: DungeonJointDirections,
        anchoredAt anchor: Point
    ) -> [DungeonJoint] {
        let isHorizontal = axis == .eastWest
        let growsPositively = stretchGrowsPositively(along: axis, anchoredAt: anchor)
        let growth = growsPositively ? amount : -amount
        let shift = Point(
            x: isHorizontal ? growth : 0,
            y: isHorizontal ? 0 : growth
        )
        let anchorPosition = isHorizontal ? anchor.x : anchor.y
        return joints.map { joint in
            let jointPosition = isHorizontal ? joint.position.x : joint.position.y
            let isBeyondAnchor = growsPositively
                ? jointPosition > anchorPosition
                : jointPosition < anchorPosition
            return isBeyondAnchor ? joint.offsetBy(shift) : joint
        }
    }

    func stretchedRect(
        by amount: Double,
        along axis: DungeonJointDirections,
        anchoredAt anchor: Point
    ) throws -> Rect {
        guard let maximum = maximumStretchedLength(along: axis) else {
            throw DungeonGeneratorError.segmentCannotStretch(id, axis)
        }
        let stretchedLength = length(along: axis) + amount
        guard stretchedLength <= maximum else {
            throw DungeonGeneratorError.stretchExceedsMaximum(
                id,
                axis,
                requested: stretchedLength,
                maximum: maximum
            )
        }
        let horizontal = axis == .eastWest
        let growsPositively = stretchGrowsPositively(along: axis, anchoredAt: anchor)
        let origin = growsPositively
            ? rect.origin
            : Point(
                x: horizontal ? rect.origin.x - amount : rect.origin.x,
                y: horizontal ? rect.origin.y : rect.origin.y - amount
            )
        let size = Size(
            width: horizontal ? stretchedLength : rect.size.width,
            height: horizontal ? rect.size.height : stretchedLength
        )
        return Rect(origin: origin, size: size)
    }
}
