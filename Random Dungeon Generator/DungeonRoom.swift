import Foundation
import SpriteKit

public class DungeonRoom {

    public var rect: Rect
    
    public init(rect: Rect) {
        self.rect = rect
    }
}

extension DungeonRoom: CustomStringConvertible {

    public var description: String {
        return rect.center.description
    }
}

extension DungeonRoom: Equatable {  }

public func == (_ lhs: DungeonRoom, _ rhs: DungeonRoom) -> Bool {
    return lhs.rect == rhs.rect
}

extension DungeonRoom: Hashable {

    public var hashValue: Int {
        return description.hashValue
    }
    
}
