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
    public private(set) var layoutRooms: OrderedDictionary<DungeonSegmentID, RoomType> = [:]
    public private(set) var numberOfStepsTaken = 0
    public private(set) var totalNumberOfStepsTakenAcrossAttempts = 0
    public private(set) var groupingGraphRoot: DungeonSegmentID?
    
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
        layoutRooms = [:]
        groupedRooms = []
        groupings = [:]
        groupingGraphRoot = nil
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
        layoutRooms = [:]
        if let initialRooms {
            initialRooms.forEach { room in
                layoutRooms[room.id] = room
            }
        } else {
            for index in (0 ..< initialRoomCreationCount) {
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
                let room = RoomType(id: "room-\(index)", rect: rect)
                layoutRooms[room.id] = room
            }
        }
    }
    
    public func randomizeRoomPositions() {
        for room in ungroupedRooms() {
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
            layoutRooms[newRoom.id] = newRoom
        }
    }
    
    public func groupingPathToSegment(_ segmentId: DungeonSegmentID, from rootSegmentId: DungeonSegmentID) -> [DungeonGrouping] {
        if let grouping = groupings[rootSegmentId] {
            if grouping.from == segmentId || grouping.to == segmentId {
                return [grouping]
            } else {
                let fromPath = groupingPathToSegment(segmentId, from: grouping.from)
                if !fromPath.isEmpty {
                    return [grouping] + fromPath
                }
                let toPath = groupingPathToSegment(segmentId, from: grouping.to)
                if !toPath.isEmpty {
                    return [grouping] + toPath
                }
                return []
            }
        } else {
            return []
        }
    }
    
    public func ungroupedRooms() -> [RoomType] {
        layoutRooms.values.filter { !groupedRooms.contains($0.id) }
    }
    
    public func iterateRoomWithAllRooms(
        _ roomId: DungeonSegmentID,
        using body: (RoomType) -> Void
    ) {
        layoutRooms.keys.forEach {
            otherRoomId in
            guard roomId != otherRoomId,
                  let otherRoom = layoutRooms[otherRoomId] else {
               return
            }
            body(otherRoom)
        }
    }
    
    // TODO: Useful ?
    public func iterateUngroupedRoomsWithAllRooms(
        using body: (RoomType, RoomType) -> Void
    ) {
        layoutRooms.keys.forEach { roomId in
            guard !groupedRooms.contains(roomId) else { return }
            layoutRooms.keys.forEach {
                otherRoomId in
                guard roomId != otherRoomId else { return }
                guard let room = layoutRooms[roomId],
                        let otherRoom = layoutRooms[otherRoomId] else {
                    assertionFailure("one or more rooms doesnt exist")
                   return
                }
                body(room, otherRoom)
            }
        }
    }
    
    public func detachedChildGroupingIds(from parentSegmentId: DungeonSegmentID? = nil) -> [DungeonSegmentID] {
        let topId = parentSegmentId ?? groupingGraphRoot
        guard let rootGroupId = topId,
              let rootGrouping = groupings[rootGroupId] else {
            return []
        }
        var childGroupings: [DungeonSegmentID] = []
        if rootGrouping.toJoint == .nonSpatial || rootGrouping.fromJoint == .nonSpatial {
            if let childA = groupings[rootGrouping.to] {
                let childAParentGroupings = detachedChildGroupingIds(from: childA.id)
                childGroupings.append(contentsOf: childAParentGroupings)
            }
            if let childB = groupings[rootGrouping.from] {
                let childBParentGroupings = detachedChildGroupingIds(from: childB.id)
                childGroupings.append(contentsOf: childBParentGroupings)
            }
        } else {
            // our topId is the root of this tree
            childGroupings.append(rootGroupId)
        }
        return childGroupings
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
        
        applyFreelanceRoomsFitting()
        applyGroupingsFitting()
        
        identifyConnections()
    }
    
    public func isSegment<A: DungeonSegment, B: DungeonSegment>(
        _ segment: A,
        sufficientlySpacedFrom otherSegment: B
    ) -> Bool {
        for rect in segment.rects {
            for otherRect in otherSegment.rects {
                let paddedRect = rect.inset(by: -minimumRoomSpacing)
                guard paddedRect.intersects(otherRect) else {
                    continue
                }
               return false
            }
        }
        return true
    }
    
    public func applyFreelanceRoomsFitting() {
        for currentRoom in ungroupedRooms() {
            var velocityX: Double = 0
            var velocityY: Double = 0
            var neighborCount: Int = 0
            iterateRoomWithAllRooms(currentRoom.id) { otherRoom in
                guard doesRoom(currentRoom, intersectWith: otherRoom) else {
                    return
                }
                let diffPos = currentRoom.rect.origin.diffOf(otherRoom.rect.origin)
                velocityX += diffPos.x
                velocityY += diffPos.y
                neighborCount += 1
            }
            guard neighborCount > 0 else {
                continue
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
            layoutRooms[newRoom.id] = newRoom
        }
    }
        
    public func applyGroupingsFitting() {
        // TODO: Confirm this fixes groupings checking against their children
        let detachedGroupings = detachedChildGroupingIds()
        detachedGroupings.forEach { groupingId in
            guard let grouping = groupings[groupingId] else {
                return
            }
            var velocityX: Double = 0
            var velocityY: Double = 0
            var neighborCount: Int = 0
            
            detachedGroupings.forEach { otherGroupingId in
                guard groupingId != otherGroupingId,
                let otherGrouping = groupings[otherGroupingId] else {
                    return
                }
                for rect in grouping.rects {
                    for otherRect in otherGrouping.rects {
                        let paddedRect = rect.inset(by: -minimumRoomSpacing)
                        guard paddedRect.intersects(otherRect) else {
                            continue
                        }
                        let diffPos = rect.origin.diffOf(otherRect.origin)
                        velocityX += diffPos.x
                        velocityY += diffPos.y
                        neighborCount += 1
                    }
                }
            }
            
            guard neighborCount > 0 else {
                return
            }
            
            let diagonalLength = grouping.rects.reduce(0) { $0 + $1.diagonalLength }
            velocityX = velocityX / diagonalLength
            velocityY = velocityY / diagonalLength
            
            let newX = grouping.offset.x + velocityX
            let newY = grouping.offset.y + velocityY
            let newOffset = Point(x: newX, y: newY)
            var newGrouping = grouping
            newGrouping.offset = newOffset
            groupings.updateValue(newGrouping, forKey: newGrouping.id)
        }
    }
    
    public func roundRoomPositions() {
        for room in ungroupedRooms() {
            var newRoom = room
            let newX = room.rect.origin.x.rounded(.up)
            let newY = room.rect.origin.y.rounded(.up)
            newRoom.rect.origin = Point(x: newX, y: newY)
            layoutRooms[newRoom.id] = newRoom
        }
    }
    
    /// Assumes room rect position is already fully resolved before calling
    /// Only resolve
    public func doesRoom(
        _ currentRoom: RoomType,
        intersectWith otherRoom: RoomType
    ) -> Bool {
        let rect = finalRoomRectForRoom(currentRoom)
        let roomRect = finalRoomRectForRoom(otherRoom)
        let paddedRect = rect.inset(by: -minimumRoomSpacing)
        return paddedRect.intersects(roomRect)
    }
    
    public func finalRoomRectForRoom(_ room: RoomType) -> Rect {
        var offsetForRoom = Point.zero
        if groupedRooms.contains(room.id), let rootGroupingId = groupingGraphRoot {
            groupingPathToSegment(room.id, from: rootGroupingId)
                .forEach { grouping in
                    offsetForRoom = offsetForRoom.offsetBy(grouping.offset)
                }
        }
        return room.rect.offset(by: offsetForRoom)
    }
    
    public func parentOffsetForGroupingId(_ groupingId: DungeonSegmentID) -> Point {
        var offsetForGrouping = Point.zero
        if let rootGroupingId = groupingGraphRoot {
            groupingPathToSegment(groupingId, from: rootGroupingId)
                .forEach { grouping in
                    offsetForGrouping = offsetForGrouping.offsetBy(grouping.offset)
                }
        }
        return offsetForGrouping
    }
    
    public func containsNoIntersectingRooms() -> Bool {
        for currentRoom in layoutRooms.values {
            for otherRoom in layoutRooms.values {
                guard currentRoom != otherRoom else { continue }
                if doesRoom(currentRoom, intersectWith: otherRoom) {
                    return false
                }
            }
        }
        return true
    }
    
    public func removeRoomsOutOfBounds() {
        // inset dungeon rect to prevent rooms on edges
        let dungeonRect = Rect(origin: Point(x: 0, y: 0), size: dungeonSize).inset(by: 1)
        for room in ungroupedRooms() {
            if !dungeonRect.contains(room.rect) {
                let offsetX = (dungeonSize.width - creationBounds.width) / 2
                let offsetY = (dungeonSize.height - creationBounds.height) / 2
                let x = offsetX + Double.random(in: 0..<creationBounds.width, using: &randomNumberGenerator)
                let y = offsetY + Double.random(in: 0..<creationBounds.height, using: &randomNumberGenerator)
                var newRoom = room
                newRoom.rect.origin = Point(x: x, y: y)
                layoutRooms[newRoom.id] = newRoom
            }
        }
        
        let detachedGroupings = detachedChildGroupingIds()
        for detachedGroupingId in detachedGroupings {
            guard let grouping = groupings[detachedGroupingId] else {
                continue
            }
            mainLoop: for rect in grouping.rects {
                if !dungeonRect.contains(rect) {
                    // Move group to dead center
                    let groupCenter = grouping.containingRect.center
                    let mapCenter = Point(x: dungeonSize.width / 2, y: dungeonSize.height / 2)
                    let diffOffset = mapCenter.diffOf(groupCenter)
                    groupings[detachedGroupingId]?.offset = grouping.offset.offsetBy(diffOffset)
                    break mainLoop
                }
            }
        }
    }
    
    public func checkForConnectionOpportunity<A: DungeonSegment, B: DungeonSegment>(
        between segment: A,
        and otherSegment: B
    ) -> (DungeonJoint, DungeonJoint)? {
        guard segment.id != otherSegment.id,
              isSegment(segment, sufficientlySpacedFrom: otherSegment) else {
            return nil
        }
        var fromJoint: DungeonJoint?
        var toJoint: DungeonJoint?
        mainLoop: for fromJointTemp in segment.joints {
            guard fromJointTemp != .nonSpatial else { continue }
            for toJointTemp in otherSegment.joints {
                guard toJointTemp != .nonSpatial else { continue }
                if fromJointTemp.matchesWith(other: toJointTemp) {
                    fromJoint = fromJointTemp
                    toJoint = toJointTemp
                    break mainLoop
                }
            }
        }
        guard let fromJoint, let toJoint else {
            return nil // couldn't find a way to line them up
        }
        return (fromJoint, toJoint)
    }
    
    @discardableResult
    public func createNewGrouping<A: DungeonSegment, B: DungeonSegment>(
        between segment: A,
        and otherSegment: B,
        connecting fromJoint: DungeonJoint,
        with toJoint: DungeonJoint
    ) -> DungeonGrouping {
        let id = String("\(randomNumberGenerator.next())-\(randomNumberGenerator.next())")
        let newGrouping = DungeonGrouping(
            id: id,
            from: segment,
            to: otherSegment,
            fromJoint: fromJoint,
            toJoint: toJoint
        )
        if segment is RoomType {
            groupedRooms.append(segment.id)
        }
        if otherSegment is RoomType {
            groupedRooms.append(otherSegment.id)
        }
        groupings[newGrouping.id] = newGrouping
        if let groupingGraphRoot {
            if groupingGraphRoot == segment.id || groupingGraphRoot == otherSegment.id {
                self.groupingGraphRoot = newGrouping.id
            } else if let rootSegment = groupings[groupingGraphRoot] {
                createNewGrouping(
                    between: newGrouping,
                    and: rootSegment,
                    connecting: .nonSpatial,
                    with: .nonSpatial
                )
            }
        } else {
            groupingGraphRoot = newGrouping.id
        }
        return newGrouping
    }
    
    public func identifyConnections() {
        identifyFreelanceRoomConnections()
        identifyRoomToGroupingConnections()
        identifyGroupingToGroupingConnections()
    }
    
    public func identifyFreelanceRoomConnections() {
        for currentRoom in layoutRooms.values {
            // continously check we cant use cached ungrouped array here
            guard !groupedRooms.contains(currentRoom.id) else {
                continue
            }
            for otherRoom in layoutRooms.values {
                guard !groupedRooms.contains(otherRoom.id) else {
                    continue
                }
                guard let (fromJoint, toJoint) = checkForConnectionOpportunity(between: currentRoom, and: otherRoom) else {
                    continue // couldn't find a way to line them up
                }
                createNewGrouping(
                    between: currentRoom,
                    and: otherRoom,
                    connecting: fromJoint,
                    with: toJoint
                )
                break
            }
        }
    }
    
    public func hasParent(segmentId: DungeonSegmentID) -> Bool {
        groupings.values.contains { $0.from == segmentId || $0.to == segmentId }
    }
    
    public func identifyRoomToGroupingConnections() {
        for currentRoom in layoutRooms.values {
            // continously check got grouped room changes, we cant use cached ungrouped array here
            guard !groupedRooms.contains(currentRoom.id) else {
                continue
            }
            // First look for connections between freelance rooms
            let groupings = self.groupings
            for (id, grouping) in groupings {
                guard !hasParent(segmentId: id) else {
                    continue
                }
                guard let (fromJoint, toJoint) = checkForConnectionOpportunity(
                    between: currentRoom,
                    and: grouping
                ) else {
                    continue // couldn't find a way to line them up
                }
                createNewGrouping(
                    between: currentRoom,
                    and: grouping,
                    connecting: fromJoint,
                    with: toJoint
                )
                break
            }
        }
    }
    
    @discardableResult
    public func identifyGroupingToGroupingConnections() -> Bool {
        let detachedChildGroupings = detachedChildGroupingIds()
        for i in 0..<detachedChildGroupings.count {
            let groupingId = detachedChildGroupings[i]
            guard !hasParent(segmentId: groupingId) else {
                continue
            }
            for otherGroupingId in detachedChildGroupings where groupingId != otherGroupingId {
                guard !hasParent(segmentId: otherGroupingId) else {
                    continue
                }
                guard let grouping = groupings[groupingId],
                      let otherGrouping = groupings[otherGroupingId] else {
                    continue
                }
                guard let (fromJoint, toJoint) = checkForConnectionOpportunity(
                    between: grouping,
                    and: otherGrouping
                ) else {
                    continue
                }
                
                // clear the tree
                groupingGraphRoot = nil
                // delete all non-spatial groupings, because we will recreate these now
                for grouping in groupings.values {
                    if grouping.toJoint == .nonSpatial || grouping.fromJoint == .nonSpatial {
                        groupings.removeValue(forKey: grouping.id)
                    }
                }
                var latestGrouping = createNewGrouping(
                    between: grouping,
                    and: otherGrouping,
                    connecting: fromJoint,
                    with: toJoint
                )
                
                for remainingGroupingId in detachedChildGroupings where remainingGroupingId != groupingId && remainingGroupingId != otherGroupingId {
                    guard let remainingGrouping = groupings[remainingGroupingId] else {
                        continue
                    }
                    latestGrouping = createNewGrouping(
                        between: latestGrouping,
                        and: remainingGrouping,
                        connecting: .nonSpatial,
                        with: .nonSpatial
                    )
                }
                return true
            }
        }
        
        return false
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
        for currentRoom in layoutRooms.values {
            guard connectedRooms.contains(where: { $0.room == currentRoom }) == false else {
                continue
            }
            
            var currentRoomReach = Circle(fittedTo: currentRoom.rect)
            currentRoomReach.radius += connectableRoomRadius
            let pairings: [RoomType] = layoutRooms.values.compactMap {
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
        
        var index: Int = 0
        var keepRooms: OrderedSet<DungeonSegmentID> = []
        for (currentRoom, pairings) in connectedRooms {
            let currentVertex = dungeon.graph.createVertex(currentRoom)
            for otherRoom in pairings {
                index += 1
                let otherVertex = dungeon.graph.createVertex(otherRoom)
                // start with abstract hallways that aren't sized or connected to anything yet
                let hallway = HallwayType(
                    id: "hallway-\(currentRoom.id)-\(otherRoom.id)-\(index)",
                    type: .corner,
                    from: .nonSpatial,
                    to: .nonSpatial
                )
                dungeon.graph.addEdge(
                    currentVertex,
                    to: otherVertex,
                    data: hallway,
                    withWeight: currentRoom.rect.center.distanceFrom(otherRoom.rect.center)
                )
            }
            keepRooms.append(currentRoom.id)
            layoutRooms[currentRoom.id] = currentRoom
        }
        
        for key in layoutRooms.keys {
            if keepRooms.contains(key) {
                continue
            }
            layoutRooms[key] = nil
        }

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
                    guard fromJointTemp != .nonSpatial else { continue }
                    for toJointTemp in toRoom.joints {
                        guard toJointTemp != .nonSpatial else { continue }
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
