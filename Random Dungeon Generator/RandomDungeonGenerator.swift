import Foundation

class RandomDungeonGenerator {
    
    var dungeonSize: Size = Size(width: 64, height: 64)
    var creationBounds: Size = Size(width: 64, height: 64)
    
    var minimumRoomWidth: Double = 5
    var maximumRoomWidth: Double = 14
    var minimumRoomHeight: Double = 5
    var maximumRoomHeight: Double = 14
    var minimumRoomSpacing: Double = 2
    var maxRoomSpacing: Double = 8
    
    var initialRoomCreationCount: Int = 30
    var maximumStepsBeforeRetry: Int = 50
    
    var rooms: [DungeonRoom] = []
    
    fileprivate(set) var numberOfStepsTaken = 0

    func generateRooms() {
        
        numberOfStepsTaken = 0
        rooms = (0..<initialRoomCreationCount).map {
            _ in
            
            let offsetX = (dungeonSize.width - creationBounds.width) / 2
            let offsetY = (dungeonSize.height - creationBounds.height) / 2
            
            let x = offsetX + Double(arc4random_uniform(UInt32(creationBounds.width)))
            let y = offsetY + Double(arc4random_uniform(UInt32(creationBounds.height)))
            let width = minimumRoomWidth + Double(arc4random_uniform(UInt32(maximumRoomWidth - minimumRoomWidth)))
            let height = minimumRoomHeight + Double(arc4random_uniform(UInt32(maximumRoomHeight - minimumRoomHeight)))
            
            let position = Point(x: x, y: y)
            let size = Size(width: width, height: height)
            let rect = Rect(origin: position, size: size)
            return DungeonRoom(rect: rect)
        }
    }
    
    func applyFittingStep(rounded: Bool = false) {
    
        if numberOfStepsTaken > maximumStepsBeforeRetry {
            generateRooms()
        }
        
        numberOfStepsTaken += 1
        removeRoomsOutOfBounds()
        rooms = rooms.map {
            currentRoom in
            
            var velocityX: Double = 0
            var velocityY: Double = 0
            var neighborCount:Int = 0
            
            rooms.forEach {
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
            
            var newX = currentRoom.rect.origin.x + velocityX
            var newY = currentRoom.rect.origin.y + velocityY
            
            if rounded {
                newX = ceil(newX)
                newY = ceil(newY)
            }
            
            let newPosition = Point(x: newX, y: newY)
            let newRect = Rect(origin: newPosition, size: currentRoom.rect.size)
            return DungeonRoom(rect: newRect)
        }
        
    }
    
    func containsNoIntersectingRooms() -> Bool {
   
        for currentRoom in rooms {
            for otherRoom in rooms {
            
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
    
    func removeRoomsOutOfBounds() {
    
        let dungeonRect = Rect(origin: Point(x: 0, y: 0), size: dungeonSize)
        rooms = rooms.filter {
            room -> Bool in
            return dungeonRect.contains(room.rect)
        }
    }
    
    func getRoomsDictionary() -> [String: DungeonRoom] {
    
        return rooms.reduce([:], {
            (dict, room) -> [String: DungeonRoom] in
            var new = dict
            new[room.rect.center.description] = room
            return new
        })
    }
    
    func generateGraph() -> AdjacencyListGraph<DungeonRoom> {
   
        let graph = AdjacencyListGraph<DungeonRoom>()
        let connectableRoomRadius = (maxRoomSpacing / 2)
        let connectedRooms = rooms.reduce([:]) {
            connections, currentRoom -> [DungeonRoom: [DungeonRoom]] in
            
            var currentRoomReach = Circle(fittedTo: currentRoom.rect)
            currentRoomReach.radius += connectableRoomRadius
            let pairings: [DungeonRoom] = rooms.flatMap {
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
        
        var finalRooms: [DungeonRoom] = []
        finalRooms.reserveCapacity(connectedRooms.count)
        connectedRooms.forEach {
            (currentRoom, connectedRooms) in
            
            finalRooms.append(currentRoom)
            let currentVertex = graph.createVertex(currentRoom)
            connectedRooms.forEach {
                otherRoom in
                let otherVertex = graph.createVertex(otherRoom)
                graph.addUndirectedEdge((currentVertex, otherVertex), withWeight: currentRoom.rect.center.distanceFrom(otherRoom.rect.center))
            }
        }
        rooms = finalRooms
        
        return graph
    }
    
    func generateMinimumEdges() -> AdjacencyListGraph<DungeonRoom> {
        return minimumSpanningTreeKruskal(graph: generateGraph()).tree
    }
    
    func generateHallways() -> [[Point]] {
        let edges = generateMinimumEdges().edges
        return edges.map {
            (edge) -> [Point] in
            
            let fromRoom = edge.from.data
            let toRoom = edge.to.data
            
            var linePoints = [Point]()
            let lineOrigin = fromRoom.rect.center
            linePoints.append(lineOrigin)
            
            let positionDiff = toRoom.rect.center.diffOf(lineOrigin)
            let verticalLinePoint = lineOrigin.offsetBy(Point(x: 0, y: positionDiff.y))
            linePoints.append(verticalLinePoint)
            
            if toRoom.rect.intersects(line: (lineOrigin, verticalLinePoint)) {
                return linePoints
            }
            
            let horizontalLinePoint = verticalLinePoint.offsetBy(Point(x: positionDiff.x, y: 0))
            linePoints.append(horizontalLinePoint)
            
            return linePoints
        }
        
    }
}
