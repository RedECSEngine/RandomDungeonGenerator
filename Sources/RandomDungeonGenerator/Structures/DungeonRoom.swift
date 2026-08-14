import Geometry

public protocol DungeonRoom: DungeonSegment {
    var rect: Rect { get set }
    var joints: [DungeonJoint] { get }
    init(id: DungeonSegmentID, rect: Rect)
}

public extension DungeonRoom where Self: CustomStringConvertible {
    var description: String {
        return rect.center.description
    }
}

public struct DefaultDungeonRoom: DungeonRoom, CustomStringConvertible {
    public var id: String
    public var rect: Rect

    public init(id: String, rect: Rect) {
        self.id = id
        self.rect = rect
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

public func == (_ lhs: DefaultDungeonRoom, _ rhs: DefaultDungeonRoom) -> Bool {
    return lhs.rect == rhs.rect
}

