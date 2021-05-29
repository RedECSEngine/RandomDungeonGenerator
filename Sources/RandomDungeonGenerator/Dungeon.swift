import Foundation

public final class Dungeon<RoomType: DungeonRoom & Equatable & Hashable,
    HallwayType>: AdjacencyListGraph<RoomType, HallwayType>
{
    public var rooms: [RoomType] {
        return adjacencyList.map { $0.vertex.data }
    }

    public var hallways: [HallwayType] {
        return edges.map { $0.data }
    }
}

extension Dungeon: Codable where RoomType: Codable, HallwayType: Codable {}
