import Foundation

public class Dungeon<R: DungeonRoomProtocolRequirements
                   , H: DungeonHallwayProtocolRequirements>: AdjacencyListGraph<R, H> {
    
    public typealias RoomType = R
    public typealias HallwayType = H
    
    public var rooms: [RoomType] {
        return self.adjacencyList.map { $0.vertex.data }
    }
    
    public var hallways: [HallwayType] {
        return self.edges.map { $0.data }
    }
    
    public required init() {
        super.init()
    }
    
    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    public required init(fromGraph graph: AdjacencyListGraph<RoomType, HallwayType>) {
        super.init(fromGraph: graph)
    }
    
    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    public func to2DGrid(canvasSize: Size) -> [[Int]] {
        
        let row: [Int] = Array(repeating: 0, count: Int(canvasSize.width))
        var grid: [[Int]] = Array(repeating: row, count: Int(canvasSize.height))
        
        let roomRects = rooms.map({ $0.rect })
        let hallwayRects = hallways.flatMap({ $0.rects })
        let rects = roomRects + hallwayRects
        
        for rect in rects {
            
            let initialX = Int(rect.origin.x)
            let maxX = Int(rect.origin.x + rect.size.width)
            let initialY = Int(rect.origin.y)
            let maxY = Int(rect.origin.y + rect.size.height)
            
            for x in (initialX..<maxX) {
                for y in (initialY..<maxY) {
                    grid[y][x] = 1
                }
            }
            
        }
        return grid
    }
    
}
