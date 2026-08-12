import Geometry


public protocol DungeonRoom: DungeonSegment {
    var rect: Rect { get set }
    var joints: [DungeonJoint] { get }

    init(rect: Rect)
}

public extension DungeonRoom where Self: CustomStringConvertible {
    var description: String {
        return rect.center.description
    }
}

public struct DefaultDungeonRoom: DungeonRoom, CustomStringConvertible {
    
    public var joints: [DungeonJoint] {
        [
            .init(position: .init(x: rect.midX, y: rect.minY), direction: .north),
            .init(position: .init(x: rect.maxX, y: rect.midY), direction: .east),
            .init(position: .init(x: rect.midX, y: rect.maxY), direction: .south),
            .init(position: .init(x: rect.minX, y: rect.midY), direction: .west),
        ]
    }
    
    public var rect: Rect
    public var rects: [Rect] { [rect] }

    public init(rect: Rect) {
        self.rect = rect
    }
}

public func == (_ lhs: DefaultDungeonRoom, _ rhs: DefaultDungeonRoom) -> Bool {
    return lhs.rect == rhs.rect
}

