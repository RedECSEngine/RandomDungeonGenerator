import Foundation

public class DefaultDungeonRoom: DungeonRoom, Equatable, Hashable, CustomStringConvertible {
    
    public var rect: Rect
    
    public required init(rect: Rect) {
        self.rect = rect
    }
}

public func == (_ lhs: DefaultDungeonRoom, _ rhs: DefaultDungeonRoom) -> Bool {
    return lhs.rect == rhs.rect
}

public class DefaultDungeonHallway: DungeonHallway {

    public var points: [Point]
    public var rects: [Rect] = []
    
    public required init(points: [Point]) {
        self.points = points
    }
    
}
