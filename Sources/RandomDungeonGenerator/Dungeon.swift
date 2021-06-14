import Foundation

public struct Dungeon<
    RoomType: DungeonRoom,
    HallwayType: DungeonHallway
>: Equatable & Hashable & Codable {
    
    public var graph: AdjacencyListGraph<RoomType, HallwayType>
    
    public subscript(room roomIndex: Int) -> RoomType {
        graph.adjacencyList[roomIndex].vertex.data
    }
    
    public var rooms: [RoomType] {
        return graph.adjacencyList.map { $0.vertex.data }
    }

    public var hallways: [HallwayType] {
        return graph.edges.map { $0.data }
    }
    
    public var firstRoomIndex: Int {
        graph.adjacencyList.startIndex
    }
    
    public var lastRoomIndex: Int {
        graph.adjacencyList.index(before: graph.adjacencyList.endIndex)
    }
    
    public init() {
        graph = .init()
    }
    
    public init(fromGraph graph: AdjacencyListGraph<RoomType, HallwayType>) {
        self.graph = graph
    }
    
    public mutating func modifyRoomData(at index: Int, modifier: (inout RoomType) -> Void) {
        modifier(&graph.adjacencyList[index].vertex.data)
    }
    
    public func randomRoomIndex() -> Int? {
        graph.adjacencyList.indices.randomElement()
    }
}
