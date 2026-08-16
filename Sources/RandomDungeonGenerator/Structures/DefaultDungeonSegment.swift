import Geometry

public struct DefaultDungeonSegment: DungeonSegment, CustomStringConvertible {
    public var id: String
    public var rect: Rect
    public var layoutCategory: DungeonSegmentLayoutCategory

    public init(
        id: String,
        rect: Rect,
        layoutCategory: DungeonSegmentLayoutCategory
    ) {
        self.id = id
        self.rect = rect
        self.layoutCategory = layoutCategory
    }
    
    public var joints: [DungeonJoint] {
        [
            .init(
                id: DungeonJointID(stringLiteral: "\(id)-1"),
                segmentId: id,
                position: .init(x: rect.midX, y: rect.minY),
                direction: .north
            ),
            .init(
                id: DungeonJointID(stringLiteral: "\(id)-2"),
                segmentId: id,
                position: .init(x: rect.maxX, y: rect.midY),
                direction: .east
            ),
            .init(
                id: DungeonJointID(stringLiteral: "\(id)-3"),
                segmentId: id,
                position: .init(x: rect.midX, y: rect.maxY),
                direction: .south
            ),
            .init(
                id: DungeonJointID(stringLiteral: "\(id)-4"),
                segmentId: id,
                position: .init(x: rect.minX, y: rect.midY),
                direction: .west
            ),
        ]
    }
}
