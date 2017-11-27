import Foundation

public class Dungeon<RoomType: DungeonRoom & Equatable & Hashable & CustomStringConvertible
                    , HallwayType>: AdjacencyListGraph<RoomType, HallwayType> {
    
    public var rooms: [RoomType] {
        return self.adjacencyList.map { $0.vertex.data }
    }
    
    public var hallways: [HallwayType] {
        return self.edges.map { $0.data }
    }
    
}
