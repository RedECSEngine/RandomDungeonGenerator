import Geometry

public typealias DungeonSegmentID = String

public enum DungeonSegmentLayoutCategory: String, Codable, Hashable {
    case room
    case hallway
}

public protocol DungeonSegment: Hashable, Codable, Identifiable {
    var id: DungeonSegmentID { get }
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
}
