import Geometry
import Graphs
import OrderedCollections
import Randomization

public typealias DungeonGrid = [[Int]]

public enum DungeonGeneratorState: Int, Codable {
    case initialState
    case regenerateRoomsAndPositions
    case fittingUntilNoMoreIntersections
    case roundingRoomPositions
    case refittingAndRounding
    case generatingHallways
    case finished
}

public class DungeonGenerator<
    RoomType: DungeonRoom,
    HallwayType: DungeonHallway
>: Equatable {
    
    private var randomNumberGenerator: any RandomNumberGenerator = SystemRandomNumberGenerator()
    
    // MARK: Settings
    public var dungeonSize = Size(width: 64, height: 64)
    public var creationBounds = Size(width: 64, height: 64)
    public var minimumRoomWidth: Double = 5
    public var maximumRoomWidth: Double = 14
    public var minimumRoomHeight: Double = 5
    public var maximumRoomHeight: Double = 14
    public var minimumRoomSpacing: Double = 2
    public var maxRoomSpacing: Double = 8
    public var hallwayWidth: Double = 4.0

    public var initialRoomCreationCount: Int = 30
    public var maximumStepsBeforeRetry: Int = 200

    public var initialRooms: [RoomType]?
    public var useMinimumSpanningTreeForLayout: Bool = true
    public private(set) var lastSeed: UInt64 = 0

    // MARK: Intermediary State during generation
    public private(set) var state: DungeonGeneratorState = .initialState
    public private(set) var groupedRooms: OrderedSet<DungeonSegmentID> = []
    public private(set) var groupings: OrderedDictionary<DungeonSegmentID, DungeonGrouping> = [:]
    public private(set) var layoutRooms: [RoomType] = [] // TODO: make ordered set
    public private(set) var numberOfStepsTaken = 0
    public private(set) var totalNumberOfStepsTakenAcrossAttempts = 0
    public private(set) var groupingGraph: AdjacencyListGraph<DungeonSegmentID, Int> = .init()
    public private(set) var groupingGraphRootIndex: Int?

    // MARK: Final outcome data
    public var dungeon: Dungeon<RoomType, HallwayType>!
    fileprivate var grid: [[Int]] = []

    public init(_ seed: UInt64? = nil) {
        if let seed {
            setSeed(seed)
        } else {
            setSeed(randomNumberGenerator.next()) // Pick a random number, but use our SeededNumberGenerator so it's reproducible always, if we record the seed used
        }
    }
    
    public func setSeed(_ seed: UInt64) {
        lastSeed = seed
        randomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
        reset()
    }
    
    public func reset() {
        numberOfStepsTaken = 0
        totalNumberOfStepsTakenAcrossAttempts = 0
        dungeon = nil
        state = .initialState
        layoutRooms = []
    }

    public func nextGenerationStep() {
        switch state {
        case .initialState:
            state = .regenerateRoomsAndPositions
        case .regenerateRoomsAndPositions:
            regenerateRooms()
            randomizeRoomPositions()
            state = .fittingUntilNoMoreIntersections
        case .fittingUntilNoMoreIntersections:
            guard containsNoIntersectingRooms() else {
                applyFittingStep()
                return
            }
            state = .roundingRoomPositions
        case .roundingRoomPositions:
            roundRoomPositions()
            state = .refittingAndRounding
        case .refittingAndRounding:
            guard containsNoIntersectingRooms() else {
                applyFittingStep()
                roundRoomPositions()
                return
            }
            state = .generatingHallways
        case .generatingHallways:
            generateHallways()
            state = .finished
        case .finished:
            break
        }
    }

    public func runCompleteGeneration(withRooms rooms: [RoomType]? = nil) {
        if let rooms = rooms {
            initialRooms = rooms
        }
        
        reset()
        
        while state != .finished {
            nextGenerationStep()
        }
    }

    public func regenerateRooms() {
        if let initialRooms {
            layoutRooms = initialRooms
        } else {
            layoutRooms = (0 ..< initialRoomCreationCount).map {
                index in
                let width = (
                    minimumRoomWidth +
                    Double.random(in: 0..<maximumRoomWidth - minimumRoomWidth, using: &randomNumberGenerator)
                ).rounded(.down)
                let height = (
                    minimumRoomHeight +
                    Double.random(in: 0..<maximumRoomHeight - minimumRoomHeight, using: &randomNumberGenerator)
                ).rounded(.down)
                let size = Size(width: width, height: height)
                let rect = Rect(origin: .zero, size: size)
                return RoomType(id: "room-\(index)", rect: rect)
            }
        }
    }
    
    public func randomizeRoomPositions() {
        layoutRooms = layoutRooms.map {
            room in
            var newRoom = room
            let offsetX = (dungeonSize.width - creationBounds.width) / 2
            let offsetY = (dungeonSize.height - creationBounds.height) / 2
            let x = offsetX + Double.random(in: 0..<creationBounds.width, using: &randomNumberGenerator)
            let y = offsetY + Double.random(in: 0..<creationBounds.height, using: &randomNumberGenerator)
            let width = (
                minimumRoomWidth +
                Double.random(in: 0..<maximumRoomWidth - minimumRoomWidth, using: &randomNumberGenerator)
            ).rounded(.down)
            let height = (
                minimumRoomHeight +
                Double.random(in: 0..<maximumRoomHeight - minimumRoomHeight, using: &randomNumberGenerator)
            ).rounded(.down)
            newRoom.rect.origin = Point(x: x, y: y)
            return newRoom
        }
    }

    public func applyFittingStep() {
        if numberOfStepsTaken > maximumStepsBeforeRetry {
            let totalSteps = totalNumberOfStepsTakenAcrossAttempts
            reset()
            totalNumberOfStepsTakenAcrossAttempts = totalSteps
        }

        numberOfStepsTaken += 1
        totalNumberOfStepsTakenAcrossAttempts += 1
        removeRoomsOutOfBounds()
        layoutRooms = layoutRooms.map {
            currentRoom in
            
//            guard !groupedRooms.contains(currentRoom.id) else {
//                return currentRoom // dont modify room position once it is grouped
//            }

            var velocityX: Double = 0
            var velocityY: Double = 0
            var neighborCount: Int = 0

            layoutRooms.forEach {
                otherRoom in

                guard currentRoom != otherRoom else {
                    return
                }
                
//                var offsetForOtherRoom = Point.zero
//                if !groupedRooms.contains(otherRoom.id), let rootIndex = groupingGraphRootIndex {
//                    let edgeList = groupingGraph.adjacencyList[rootIndex]
//                    let rootGroupingId = edgeList.vertex.data
//                    if let grouping = groupings[rootGroupingId] {
//                        offsetForOtherRoom += grouping.offset
//                        if grouping.from == otherRoom.id {
//                            groupings[grouping.from] != nil
//                        } else if grouping.to == otherRoom.id {
//                            
//                        }
//                    }
//                }

                let paddedRect = currentRoom.rect.inset(by: -minimumRoomSpacing)
                guard paddedRect.intersects(otherRoom.rect) else {
                    return
                }

                let diffPos = currentRoom.rect.origin.diffOf(otherRoom.rect.origin)

                velocityX += diffPos.x
                velocityY += diffPos.y
                neighborCount += 1
            }

            guard neighborCount > 0 else {
                return currentRoom
            }

            velocityX = velocityX / currentRoom.rect.diagonalLength
            velocityY = velocityY / currentRoom.rect.diagonalLength

            let newX = currentRoom.rect.origin.x + velocityX
            let newY = currentRoom.rect.origin.y + velocityY
            let newPosition = Point(
                x: newX < 0 ? 0 : newX,
                y: newY < 0 ? 0 : newY
            )
            let newRect = Rect(origin: newPosition, size: currentRoom.rect.size)
            var newRoom = currentRoom
            newRoom.rect = newRect
            return newRoom
        }
    }

    public func roundRoomPositions() {
        layoutRooms = layoutRooms.map { room in
            var newRoom = room
            let newX = room.rect.origin.x.rounded(.up)
            let newY = room.rect.origin.y.rounded(.up)
            newRoom.rect.origin = Point(x: newX, y: newY)
            return newRoom
        }
    }

    public func containsNoIntersectingRooms() -> Bool {
        for currentRoom in layoutRooms {
            for otherRoom in layoutRooms {
                guard currentRoom != otherRoom else {
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
        // inset dungeon rect to prevent rooms on edges
        let dungeonRect = Rect(origin: Point(x: 0, y: 0), size: dungeonSize).inset(by: 1)
        layoutRooms = layoutRooms.map { room in
            if !dungeonRect.contains(room.rect) {
                let offsetX = (dungeonSize.width - creationBounds.width) / 2
                let offsetY = (dungeonSize.height - creationBounds.height) / 2
                let x = offsetX + Double.random(in: 0..<creationBounds.width, using: &randomNumberGenerator)
                let y = offsetY + Double.random(in: 0..<creationBounds.height, using: &randomNumberGenerator)
                var newRoom = room
                newRoom.rect.origin = Point(x: x, y: y)
                return newRoom
            }
            return room
        }
    }
    
    public func identifyConnections() {
        // TODO:
    }

    public func generateDungeonGraph() {
        guard dungeon == nil else { return }
        let originalGraph = generateUnoptimizedDungeon().graph
        if useMinimumSpanningTreeForLayout {
            let minimumSpanningGraph = minimumSpanningTreeKruskal(graph: originalGraph).tree
            dungeon = Dungeon(fromGraph: minimumSpanningGraph)
        } else {
            dungeon = Dungeon(fromGraph: originalGraph)
        }
    }

    public func generateUnoptimizedDungeon() -> Dungeon<RoomType, HallwayType> {
        var dungeon = Dungeon<RoomType, HallwayType>()
        let connectableRoomRadius = (maxRoomSpacing / 2)
        var connectedRooms: [(room: RoomType, pairings: [RoomType])] = []
        connectedRooms.reserveCapacity(layoutRooms.count)
        for currentRoom in layoutRooms {
            guard connectedRooms.contains(where: { $0.room == currentRoom }) == false else {
                continue
            }

            var currentRoomReach = Circle(fittedTo: currentRoom.rect)
            currentRoomReach.radius += connectableRoomRadius
            let pairings: [RoomType] = layoutRooms.compactMap {
                otherRoom in

                guard currentRoom != otherRoom else { return nil }

                var otherRoomReach = Circle(fittedTo: otherRoom.rect)
                otherRoomReach.radius += connectableRoomRadius

                if currentRoomReach.intersects(otherRoomReach) {
                    return otherRoom
                }
                return nil
            }

            guard pairings.isEmpty == false else {
                continue
            }

            connectedRooms.append((currentRoom, pairings))
        }

        var finalRooms: [RoomType] = []
        finalRooms.reserveCapacity(connectedRooms.count)
        var index: Int = 0
        for (currentRoom, pairings) in connectedRooms {
            finalRooms.append(currentRoom)
            let currentVertex = dungeon.graph.createVertex(currentRoom)
            for otherRoom in pairings {
                index += 1
                let otherVertex = dungeon.graph.createVertex(otherRoom)
                // start with abstract hallways that aren't sized or connected to anything yet
                let hallway = HallwayType(
                    id: "hallway-\(currentRoom.id)-\(otherRoom.id)-\(index)",
                    type: .corner,
                    from: .closed,
                    to: .closed
                )
                dungeon.graph.addEdge(
                    currentVertex,
                    to: otherVertex,
                    data: hallway,
                    withWeight: currentRoom.rect.center.distanceFrom(otherRoom.rect.center)
                )
            }
        }
        layoutRooms = finalRooms

        return dungeon
    }

    public func generateHallways() {
        generateDungeonGraph()
        generateLineHallways()
        
        let newList = dungeon.graph.adjacencyList.map { edgeList in
            var newEdgeList = edgeList
            newEdgeList.edges = newEdgeList.edges?.map { edge in
                var newHallway = edge.hallway
                var newEdge = edge
                
                let lineSet = newHallway.joints.map { $0.position }

                guard lineSet.count >= 2 else { return edge }

                let firstLine = (lineSet[0].roundedUp(), lineSet[1].roundedUp())
                let verticalDiff = firstLine.0.diffOf(firstLine.1)
                let verticalDirection = Direction.fromPoint(verticalDiff)
                let roundedHalfWidth = (hallwayWidth / 2).rounded(.up)

                // vertical hallways are first
                if verticalDirection == .down {
                    let origin = firstLine.0.offsetBy(x: -roundedHalfWidth, y: 0)
                    let rect = Rect(origin: origin, size: Size(width: hallwayWidth, height: firstLine.0.distanceFrom(firstLine.1)))
                    newHallway.rects.append(rect)
                } else {
                    let origin = firstLine.1.offsetBy(x: -roundedHalfWidth, y: 0)
                    let rect = Rect(origin: origin, size: Size(width: hallwayWidth, height: firstLine.0.distanceFrom(firstLine.1)))
                    newHallway.rects.append(rect)
                }
                
                guard lineSet.count >= 3 else {
                    newEdge.hallway = newHallway
                    return newEdge
                }

                let secondLine = (lineSet[1].roundedUp(), lineSet[2].roundedUp())
                let horizontalDiff = secondLine.0.diffOf(secondLine.1)
                let horizontalDirection = Direction.fromPoint(horizontalDiff)

                // horizontal comes second
                if horizontalDirection == .left {
                    let origin = secondLine.0.offsetBy(x: 0, y: -roundedHalfWidth)
                    let rect = Rect(origin: origin, size: Size(width: secondLine.0.distanceFrom(secondLine.1), height: hallwayWidth))
                    newHallway.rects.append(rect)
                } else {
                    let origin = secondLine.1.offsetBy(x: 0, y: -roundedHalfWidth)
                    let rect = Rect(origin: origin, size: Size(width: secondLine.0.distanceFrom(secondLine.1), height: hallwayWidth))
                    newHallway.rects.append(rect)
                }
                
                newEdge.hallway = newHallway
                
                return newEdge
            }
            return newEdgeList
        }
        dungeon.graph.adjacencyList = newList
    }

    public func generateLineHallways() {
        var index = 0
        dungeon.graph.adjacencyList = dungeon.graph.adjacencyList.map { edgeList in
            var newEdgeList = edgeList
            newEdgeList.edges = newEdgeList.edges?.map { edge in
                index += 1
                var newEdge = edge
                
                let fromRoom = edge.from.room
                let toRoom = edge.to.room
                
                var fromJoint: DungeonJoint?
                var toJoint: DungeonJoint?
                mainLoop: for fromJointTemp in fromRoom.joints {
                    guard fromJointTemp != .closed else { continue }
                    for toJointTemp in toRoom.joints {
                        guard toJointTemp != .closed else { continue }
                        if fromJointTemp.matchesWith(other: toJointTemp) {
                            fromJoint = fromJointTemp
                            toJoint = toJointTemp
                            break mainLoop
                        }
                    }
                }
                
                guard let fromJoint, let toJoint else {
                    return edge // couldn't find a way to line them up
                }
                
                let id = "\(index)-hallway-\(fromRoom.id)-\(toRoom.id)"
                let positionDiff = fromJoint.position.diffOf(toJoint.position)
                if positionDiff.x != 0 && positionDiff.y != 0 {
                    // we need a corner hallway
                    newEdge.hallway = HallwayType(
                        id: id,
                        type: .corner,
                        from: fromJoint,
                        to: toJoint
                    )
                }
                else if positionDiff.y > 0 {
                    // north joint on origin must have Y > south joint
                    newEdge.hallway = HallwayType(id: id, type: .northSouth, from: fromJoint, to: toJoint)
                } else if positionDiff.x < 0 {
                    // east joint on origin must have X < west joint
                    newEdge.hallway = HallwayType(id: id, type: .eastWest, from: fromJoint, to: toJoint)
                }
                else if positionDiff.y < 0 {
                   // south < north
                    newEdge.hallway = HallwayType(id: id, type: .northSouth, from: toJoint, to: fromJoint)
                } else if positionDiff.x > 0 {
                    // west > east
                    newEdge.hallway = HallwayType(id: id, type: .eastWest, from: toJoint, to: fromJoint)
                }
                
                return newEdge
            }
            return newEdgeList
        }
    }

    public func to2DGrid() -> [[Int]] {
        guard self.grid.isEmpty else {
            return self.grid
        }
        
        let grid = dungeon.create2DGrid(size: dungeonSize)
        
        self.grid = grid

        return self.grid
    }
    
    public static func == (lhs: DungeonGenerator, rhs: DungeonGenerator) -> Bool {
        return lhs === rhs
    }
}
