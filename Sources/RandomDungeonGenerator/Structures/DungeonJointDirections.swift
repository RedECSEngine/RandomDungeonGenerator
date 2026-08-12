public struct DungeonJointDirections: OptionSet, Codable, Hashable, CustomStringConvertible {
    public let rawValue: Int
    
    public static let north = Self(rawValue: 1 << 0)
    public static let east = Self(rawValue: 1 << 2)
    public static let south = Self(rawValue: 1 << 3)
    public static let west = Self(rawValue: 1 << 4)
    
    public static let eastWest: Self = [.east, .west]
    public static let northSouth: Self = [.north, .south]
    
    public static let cornerNorthEast: Self = [.north, .east]
    public static let cornerSouthEast: Self = [.south, .east]
    public static let cornerSouthWest: Self = [.south, .west]
    public static let cornerNorthWest: Self = [.north, .west]
    
    public static let none: Self = []
    public static let all: Self = [.north, .east, .south, .west]
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public extension DungeonJointDirections {
    var description: String {
        switch self {
        case .north: return "north"
        case .east: return "east"
        case .south: return "south"
        case .west: return "west"
        case .eastWest: return "eastWest"
        case .northSouth: return "northSouth"
        case .cornerNorthEast: return "cornerNorthEast"
        case .cornerSouthEast: return "cornerSouthEast"
        case .cornerSouthWest: return "cornerSouthWest"
        case .cornerNorthWest: return "cornerNorthWest"
        case .all: return "all"
        case []: return "none"
        default:
            return "???"
        }
    }
}
