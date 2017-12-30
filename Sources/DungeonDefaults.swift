import Foundation

public class DefaultDungeonRoom: DungeonRoomProtocolRequirements, CustomStringConvertible {
    
    enum CodingKeys: String, CodingKey {
        case rect
    }
    
    public var rect: Rect
    
    public required init(rect: Rect) {
        self.rect = rect
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        rect = try values.decode(Rect.self, forKey: .rect)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rect, forKey: .rect)
    }
    
}

public func == (_ lhs: DefaultDungeonRoom, _ rhs: DefaultDungeonRoom) -> Bool {
    return lhs.rect == rhs.rect
}

public class DefaultDungeonHallway: DungeonHallwayProtocolRequirements {

    enum CodingKeys: String, CodingKey {
        case points
        case rects
    }
    
    public var points: [Point]
    public var rects: [Rect] = []
    
    public var hashValue: Int {
        return points
            .map({ String(describing: $0) })
            .joined()
            .hashValue
    }
    
    public required init(points: [Point]) {
        self.points = points
    }
    
    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        points = try values.decode([Point].self, forKey: .points)
        rects = try values.decode([Rect].self, forKey: .rects)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(points, forKey: .points)
        try container.encode(rects, forKey: .rects)
    }
}


public func == (_ lhs: DefaultDungeonHallway, _ rhs: DefaultDungeonHallway) -> Bool {
    return lhs.points == rhs.points
}

