import Foundation

public typealias DungeonGrid = [[Int]]

public class DungeonGenerator<RoomType: DungeonRoom & Equatable & Hashable, HallwayType: DungeonHallway> {
    
    public var dungeonSize: Size = Size(width: 64, height: 64)
    public var creationBounds: Size = Size(width: 64, height: 64)
    
    public var minimumRoomWidth: Double = 5
    public var maximumRoomWidth: Double = 14
    public var minimumRoomHeight: Double = 5
    public var maximumRoomHeight: Double = 14
    public var minimumRoomSpacing: Double = 2
    public var maxRoomSpacing: Double = 8
    public var hallwayWidth: Double = 4.0
    
    public var initialRoomCreationCount: Int = 30
    public var maximumStepsBeforeRetry: Int = 50
    
    public var dungeon: Dungeon<RoomType, HallwayType>!
    
    public var layoutRooms: [RoomType] = []
    fileprivate var grid: [[Int]] = []
    
    fileprivate(set) var numberOfStepsTaken = 0
    
    public init() {
        
    }
    
    public func runCompleteGeneration() {
        let startTime = Date()
        generateRooms()
        
        while false == containsNoIntersectingRooms() {
            applyFittingStep()
        }
        
        roundRoomPositions()
        
        while false == containsNoIntersectingRooms() {
            applyFittingStep()
            roundRoomPositions()
        }
        
        generateHallways()
        
        let endTime = Date()
        
        let difference = endTime.timeIntervalSince(startTime)
        print("Dungeon generated in \(difference) seconds")
    }

    public func generateRooms() {
        
        numberOfStepsTaken = 0
        layoutRooms = (0..<initialRoomCreationCount).map {
            _ in
            
            let offsetX = (dungeonSize.width - creationBounds.width) / 2
            let offsetY = (dungeonSize.height - creationBounds.height) / 2
            
            let x = offsetX + Double(arc4random_uniform(UInt32(creationBounds.width)))
            let y = offsetY + Double(arc4random_uniform(UInt32(creationBounds.height)))
            let width = floor(minimumRoomWidth + Double(arc4random_uniform(UInt32(maximumRoomWidth - minimumRoomWidth))))
            let height = floor(minimumRoomHeight + Double(arc4random_uniform(UInt32(maximumRoomHeight - minimumRoomHeight))))
            
            let position = Point(x: x, y: y)
            let size = Size(width: width, height: height)
            let rect = Rect(origin: position, size: size)
            return RoomType.init(rect: rect)
        }
        dungeon = nil
    }
    
    public func applyFittingStep() {
    
        if numberOfStepsTaken > maximumStepsBeforeRetry {
            generateRooms()
        }
        
        numberOfStepsTaken += 1
        removeRoomsOutOfBounds()
        layoutRooms = layoutRooms.map {
            currentRoom in
            
            var velocityX: Double = 0
            var velocityY: Double = 0
            var neighborCount:Int = 0
            
            layoutRooms.forEach {
                otherRoom in
                
                guard currentRoom !== otherRoom else {
                    return
                }
                
                let paddedRect = currentRoom.rect.inset(by: -minimumRoomSpacing)
                guard paddedRect.intersects(otherRoom.rect) else {
                    return
                }
                
                let diffPos = paddedRect.origin.diffOf(otherRoom.rect.origin)
                
                velocityX += diffPos.x
                velocityY += diffPos.y
                neighborCount += 1
            }
            
            guard neighborCount > 0 else {
                return currentRoom
            }
            
            velocityX /= Double(neighborCount)
            velocityY /= Double(neighborCount)
            
            velocityX = velocityX / currentRoom.rect.diagonalLength
            velocityY = velocityY / currentRoom.rect.diagonalLength
            
            let newX = currentRoom.rect.origin.x + velocityX
            let newY = currentRoom.rect.origin.y + velocityY
            let newPosition = Point(x: newX, y: newY)
            let newRect = Rect(origin: newPosition, size: currentRoom.rect.size)
            return RoomType(rect: newRect)
        }
    }
    
    public func roundRoomPositions() {
        layoutRooms.forEach {
            room in
            let newX = ceil(room.rect.origin.x)
            let newY = ceil(room.rect.origin.y)
            room.rect.origin = Point(x: newX, y: newY)
        }
    }
    
    public func containsNoIntersectingRooms() -> Bool {
   
        for currentRoom in layoutRooms {
            for otherRoom in layoutRooms {
            
                guard currentRoom !== otherRoom else {
                    continue
                }
                
                let paddedRect = currentRoom.rect.inset(by: -minimumRoomSpacing)
                if paddedRect.intersects(otherRoom.rect) {
                    return false
                }
            }
        }
        
        return true
    }
    
    public func removeRoomsOutOfBounds() {
    
        //inset dungeon rect to prevent rooms on edges
        let dungeonRect = Rect(origin: Point(x: 0, y: 0), size: dungeonSize).inset(by: 1)
        layoutRooms = layoutRooms.filter {
            room -> Bool in
            return dungeonRect.contains(room.rect)
        }
    }
    
    public func getRoomsDictionary() -> [String: RoomType] {
    
        return layoutRooms.reduce([:], {
            (dict, room) -> [String: RoomType] in
            var new = dict
            new[room.rect.center.description] = room
            return new
        })
    }
    
    public func generateGraph() -> Dungeon<RoomType, HallwayType> {
   
        let graph = Dungeon<RoomType, HallwayType>()
        let connectableRoomRadius = (maxRoomSpacing / 2)
        let connectedRooms = layoutRooms.reduce([:]) {
            connections, currentRoom -> [RoomType: [RoomType]] in
            
            var currentRoomReach = Circle(fittedTo: currentRoom.rect)
            currentRoomReach.radius += connectableRoomRadius
            let pairings: [RoomType] = layoutRooms.flatMap {
                otherRoom in
                
                guard currentRoom !== otherRoom else { return nil }
                
                var otherRoomReach = Circle(fittedTo: otherRoom.rect)
                otherRoomReach.radius += connectableRoomRadius
                
                if currentRoomReach.intersects(otherRoomReach) {
                    return otherRoom
                }
                return nil
            }
            
            guard false == pairings.isEmpty else {
                return connections
            }
            
            var new = connections
            new[currentRoom] = pairings
            return new
        }
        
        var finalRooms: [RoomType] = []
        finalRooms.reserveCapacity(connectedRooms.count)
        connectedRooms.forEach {
            (currentRoom, connectedRooms) in
            
            finalRooms.append(currentRoom)
            let currentVertex = graph.createVertex(currentRoom)
            connectedRooms.forEach {
                otherRoom in
                let otherVertex = graph.createVertex(otherRoom)
                let hallway = HallwayType.init(points: [])
                graph.addEdge(currentVertex, to: otherVertex, data: hallway, withWeight: currentRoom.rect.center.distanceFrom(otherRoom.rect.center))
            }
        }
        layoutRooms = finalRooms
        
        return graph
    }
    
    public func generateDungeonGraph() {
        guard dungeon == nil else { return }
        
        let tree = minimumSpanningTreeKruskal(graph: generateGraph()).tree
        self.dungeon = Dungeon(fromGraph: tree)
    }
    
    public func generateHallways() {
        
        generateDungeonGraph()
        generateLineHallways()
        dungeon.hallways.forEach {
            (hallway) in
            
            let lineSet = hallway.points
           
            guard lineSet.count >= 2 else { return }
            
            let firstLine = (lineSet[0].roundedUp(), lineSet[1].roundedUp())
            let verticalDiff = firstLine.0.diffOf(firstLine.1)
            let verticalDirection = Direction.fromPoint(verticalDiff)
            let roundedHalfWidth = ceil(hallwayWidth/2)
            
            //vertical hallways are first
            if verticalDirection == .down {
                let origin = firstLine.0.offsetBy(x: -roundedHalfWidth, y: 0)
                let rect = Rect(origin: origin, size: Size(width: hallwayWidth, height: firstLine.0.distanceFrom(firstLine.1)))
                hallway.rects.append(rect)
            } else {
                let origin = firstLine.1.offsetBy(x: -roundedHalfWidth, y: 0)
                let rect = Rect(origin: origin, size: Size(width: hallwayWidth, height: firstLine.0.distanceFrom(firstLine.1)))
                hallway.rects.append(rect)
            }
            
            guard lineSet.count >= 3 else {
                return
            }
            
            let secondLine = (lineSet[1].roundedUp(), lineSet[2].roundedUp())
            let horizontalDiff = secondLine.0.diffOf(secondLine.1)
            let horizontalDirection = Direction.fromPoint(horizontalDiff)
            
            //horizontal comes second
            if horizontalDirection == .left {
                let origin = secondLine.0.offsetBy(x: 0, y: -roundedHalfWidth)
                let rect = Rect(origin: origin, size: Size(width: secondLine.0.distanceFrom(secondLine.1), height: hallwayWidth))
                hallway.rects.append(rect)
            } else {
                let origin = secondLine.1.offsetBy(x: 0, y: -roundedHalfWidth)
                let rect = Rect(origin: origin, size: Size(width: secondLine.0.distanceFrom(secondLine.1), height: hallwayWidth))
                hallway.rects.append(rect)
            }
        }
        
    }
    
    public func generateLineHallways() {

        dungeon.edges.forEach {
            (edge) in
            
            let fromRoom = edge.from.data
            let toRoom = edge.to.data
            
            let lineOrigin = fromRoom.rect.center
            edge.data.points.append(lineOrigin)
            
            let positionDiff = toRoom.rect.center.diffOf(lineOrigin)
            let verticalLinePoint = lineOrigin.offsetBy(Point(x: 0, y: positionDiff.y))
            edge.data.points.append(verticalLinePoint)
            
            if toRoom.rect.intersects(line: (lineOrigin, verticalLinePoint)) {
                return
            }
            
            let horizontalLinePoint = verticalLinePoint.offsetBy(Point(x: positionDiff.x, y: 0))
            edge.data.points.append(horizontalLinePoint)
        }
    }
    
    public func to2DGrid() -> [[Int]] {
        
        guard self.grid.isEmpty else {
            return self.grid
        }
        
        let row: [Int] = Array(repeating: 0, count: Int(dungeonSize.width))
        var grid: [[Int]] = Array(repeating: row, count: Int(dungeonSize.height))
        
        let rects = layoutRooms.map({ $0.rect }) + dungeon.hallways.flatMap({ $0.rects })
        
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
        
        self.grid = grid
        
        return self.grid
    }
    
}
