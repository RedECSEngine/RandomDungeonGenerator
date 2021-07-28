import Foundation
import Geometry
import Graphs

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
    
    public func create2DGrid(size: Size) -> [[Int]] {
        let row: [Int] = Array(repeating: 0, count: Int(size.width))
        var grid: [[Int]] = Array(repeating: row, count: Int(size.height))

        let rects = rooms.map { $0.rect } + hallways.flatMap { $0.rects }

        for rect in rects {
            let initialX = Int(rect.origin.x)
            let maxX = Int(rect.origin.x + rect.size.width)
            let initialY = Int(rect.origin.y)
            let maxY = Int(rect.origin.y + rect.size.height)

            for x in initialX ..< maxX {
                if x >= Int(size.width) {
                    break
                }
                for y in initialY ..< maxY {
                    if y >= Int(size.height) {
                        break
                    }
                    grid[y][x] = 1
                }
            }
        }
        
        return grid
    }
}
