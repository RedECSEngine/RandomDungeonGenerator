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
    public static func == (lhs: DungeonGenerator, rhs: DungeonGenerator) -> Bool {
        return lhs === rhs
    }
    
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
    public var maximumStepsBeforeRetry: Int = 30
    
    public var initialRooms: [RoomType]?
    public var useMinimumSpanningTreeForLayout: Bool = true
    public private(set) var lastSeed: UInt64 = 0
    
    // MARK: Intermediary State during generation
    public private(set) var state: DungeonGeneratorState = .initialState
    public private(set) var groupingGraph: AdjacencyListGraph<DungeonSegmentID, DungeonGrouping> = .init()
    public private(set) var layoutRooms: OrderedDictionary<DungeonSegmentID, RoomType> = [:]
    public private(set) var numberOfStepsTaken = 0
    public private(set) var totalNumberOfStepsTakenAcrossAttempts = 0

    public var groupings: [DungeonGrouping] {
        groupingGraph.edges.map { $0.grouping }
    }

    public var groupedRooms: OrderedSet<DungeonSegmentID> {
        var rooms: OrderedSet<DungeonSegmentID> = []
        for edge in groupingGraph.edges {
            rooms.append(edge.from.data)
            rooms.append(edge.to.data)
        }
        return rooms
    }

    public var connectedJoints: OrderedSet<DungeonJointID> {
        var joints: OrderedSet<DungeonJointID> = []
        for edge in groupingGraph.edges {
            joints.append(edge.grouping.fromJoint)
            joints.append(edge.grouping.toJoint)
        }
        return joints
    }

    public var spatialGroupingCount: Int {
        groupingGraph.edges.count
    }
    
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
        groupingGraph = .init()
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
            let groupingsCount = spatialGroupingCount
            identifyConnections()
            if groupingsCount != spatialGroupingCount {
                state = .fittingUntilNoMoreIntersections
                return
            }
            
            for room in ungroupedRooms() {
                findConnection(for: room, ignoringJointAlignment: true)
            }

            centerAllRoomsInDungeon()

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
    
    // MARK: - Dungeon Prep
    
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
    
    // MARK: - Traversal
    
    public func connectionCount(forRoomId roomId: DungeonSegmentID) -> Int {
        groupingGraph.edges.reduce(into: 0) { total, edge in
            if edge.from.data == roomId || edge.to.data == roomId {
                total += 1
            }
        }
    }

    public func connectedGroups() -> [OrderedSet<DungeonSegmentID>] {
        var unionFind = UnionFind<DungeonSegmentID>()
        for roomId in layoutRooms.keys {
            unionFind.addSetWith(roomId)
        }
        for edge in groupingGraph.edges {
            unionFind.unionSetsContaining(edge.from.data, and: edge.to.data)
        }
        var groupsBySet: OrderedDictionary<Int, OrderedSet<DungeonSegmentID>> = [:]
        for roomId in layoutRooms.keys {
            guard let setId = unionFind.setOf(roomId) else { continue }
            groupsBySet[setId, default: []].append(roomId)
        }
        return Array(groupsBySet.values)
    }

    public func roomIds(connectedTo roomId: DungeonSegmentID) -> OrderedSet<DungeonSegmentID> {
        connectedGroups().first { $0.contains(roomId) } ?? [roomId]
    }

    public func roomCount(connectedTo roomId: DungeonSegmentID) -> Int {
        roomIds(connectedTo: roomId).count
    }

    public func ungroupedRooms() -> [RoomType] {
        let grouped = groupedRooms
        return layoutRooms.values.filter { !grouped.contains($0.id) }
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
    
    // MARK: - Fitting
    
    public func applyFittingStep() {
        if numberOfStepsTaken > maximumStepsBeforeRetry {
            let totalSteps = totalNumberOfStepsTakenAcrossAttempts
            reset()
            totalNumberOfStepsTakenAcrossAttempts = totalSteps
        }
        
        numberOfStepsTaken += 1
        totalNumberOfStepsTakenAcrossAttempts += 1
        reorganizeSegmentsOutOfBounds()
        
        applyFreelanceRoomsFitting()
        applyGroupingsFitting()
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
        for group in connectedGroups() where group.count > 1 {
            var velocityX: Double = 0
            var velocityY: Double = 0
            var neighborCount: Int = 0
            var diagonalLength: Double = 0

            for roomId in group {
                guard let room = layoutRooms[roomId] else { continue }
                let rect = room.rect
                diagonalLength += rect.diagonalLength
                let paddedRect = rect.inset(by: -minimumRoomSpacing)
                for otherRoom in layoutRooms.values where !group.contains(otherRoom.id) {
                    guard paddedRect.intersects(otherRoom.rect) else {
                        continue
                    }
                    let diffPos = rect.origin.diffOf(otherRoom.rect.origin)
                    velocityX += diffPos.x
                    velocityY += diffPos.y
                    neighborCount += 1
                }
            }

            guard neighborCount > 0, diagonalLength > 0 else {
                continue
            }

            translateRooms(
                group,
                by: Point(x: velocityX / diagonalLength, y: velocityY / diagonalLength)
            )
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
    
    public func reorganizeSegmentsOutOfBounds() {
        // inset dungeon rect to prevent rooms on edges
        let dungeonRect = Rect(origin: Point(x: 0, y: 0), size: dungeonSize).inset(by: 1)
        for room in ungroupedRooms() {
            if !dungeonRect.contains(room.rect) {
                // if we are out of bounds, try using this peice on an open joint
                // otherwise position somewhere random within ceation bounds
                if !findConnection(for: room) {
                    let offsetX = (dungeonSize.width - creationBounds.width) / 2
                    let offsetY = (dungeonSize.height - creationBounds.height) / 2
                    let x = offsetX + Double.random(in: 0..<creationBounds.width, using: &randomNumberGenerator)
                    let y = offsetY + Double.random(in: 0..<creationBounds.height, using: &randomNumberGenerator)
                    var newRoom = room
                    newRoom.rect.origin = Point(x: x, y: y)
                    layoutRooms[newRoom.id] = newRoom
                }
            }
        }
        
        // For each connected group of vertices, iterate over rects
        // and make sure they are all within bounds
        for group in connectedGroups() where group.count > 1 {
            guard let anchorRoomId = group.first else {
                continue
            }
            mainLoop: for rect in resolvedRects(forSegmentId: anchorRoomId) {
                // if a rect is out of bounds
                if !dungeonRect.contains(rect) {
                    // Move the whole group to dead center
                    guard let groupCenter = containingRect(forGroupConnectedTo: anchorRoomId)?.center else {
                        continue
                    }
                    let mapCenter = Point(x: dungeonSize.width / 2, y: dungeonSize.height / 2)
                    let diffOffset = mapCenter.diffOf(groupCenter)
                    let randOffsetX = Double.random(in: 0..<creationBounds.width, using: &randomNumberGenerator) - (creationBounds.width / 2)
                    let randOffsetY = Double.random(in: 0..<creationBounds.height, using: &randomNumberGenerator) - (creationBounds.height / 2)

                    translateRooms(
                        group,
                        by: diffOffset.offsetBy(x: randOffsetX, y: randOffsetY)
                    )
                    break mainLoop
                }
            }
        }
    }
    
    // MARK: - Geometry
    
    public func finalRoomRectForRoom(_ room: RoomType) -> Rect {
        room.rect
    }

    public func resolvedRects(forSegmentId segmentId: DungeonSegmentID) -> [Rect] {
        roomIds(connectedTo: segmentId).compactMap { layoutRooms[$0]?.rect }
    }

    public func resolvedJoints(forSegmentId segmentId: DungeonSegmentID) -> [DungeonJoint] {
        roomIds(connectedTo: segmentId).flatMap { layoutRooms[$0]?.joints ?? [] }
    }

    public func containingRectForAllRooms() -> Rect? {
        let rects = layoutRooms.values.map { $0.rect }
        guard let first = rects.first else {
            return nil
        }
        var minX = first.minX
        var minY = first.minY
        var maxX = first.maxX
        var maxY = first.maxY
        for rect in rects.dropFirst() {
            minX = min(minX, rect.minX)
            minY = min(minY, rect.minY)
            maxX = max(maxX, rect.maxX)
            maxY = max(maxY, rect.maxY)
        }
        return Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public func centerAllRoomsInDungeon() {
        guard let layoutRect = containingRectForAllRooms() else {
            return
        }
        let mapCenter = Point(x: dungeonSize.width / 2, y: dungeonSize.height / 2)
        let delta = mapCenter.diffOf(layoutRect.center)
        translateRooms(
            OrderedSet(layoutRooms.keys),
            by: Point(x: delta.x.rounded(), y: delta.y.rounded())
        )
    }

    public func containingRect(forGroupConnectedTo roomId: DungeonSegmentID) -> Rect? {
        let rects = resolvedRects(forSegmentId: roomId)
        guard let first = rects.first else {
            return nil
        }
        var minX = first.minX
        var minY = first.minY
        var maxX = first.maxX
        var maxY = first.maxY
        for rect in rects.dropFirst() {
            minX = min(minX, rect.minX)
            minY = min(minY, rect.minY)
            maxX = max(maxX, rect.maxX)
            maxY = max(maxY, rect.maxY)
        }
        return Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    // MARK: - Connections
    
    public func directlyConnectedRoomPairs() -> Set<[DungeonSegmentID]> {
        Set(groupingGraph.edges.map { [$0.from.data, $0.to.data].sorted() })
    }

    public func containsNoIntersectingRooms() -> Bool {
        let connectedPairs = directlyConnectedRoomPairs()
        for currentRoom in layoutRooms.values {
            for otherRoom in layoutRooms.values {
                guard currentRoom != otherRoom else { continue }
                if connectedPairs.contains([currentRoom.id, otherRoom.id].sorted()) {
                    if finalRoomRectForRoom(currentRoom)
                        .intersects(finalRoomRectForRoom(otherRoom)) {
                        return false
                    }
                    continue
                }
                if doesRoom(currentRoom, intersectWith: otherRoom) {
                    return false
                }
            }
        }
        return true
    }
    
    public func translate(roomId: DungeonSegmentID, by delta: Point) {
        translateRooms(roomIds(connectedTo: roomId), by: delta)
    }

    public func translateRooms(
        _ roomIds: OrderedSet<DungeonSegmentID>,
        by delta: Point
    ) {
        for roomId in roomIds {
            guard var room = layoutRooms[roomId] else { continue }
            room.rect = room.rect.offsetBy(delta)
            layoutRooms[roomId] = room
        }
    }
    
    public func outwardUnitVector(for direction: DungeonJointDirections) -> Point {
        switch direction {
        case .north: return Point(x: 0, y: -1)
        case .south: return Point(x: 0, y: 1)
        case .east:  return Point(x: 1, y: 0)
        case .west:  return Point(x: -1, y: 0)
        default:     return .zero
        }
    }

    public func alignmentDelta(
        moving movingJoint: DungeonJoint,
        onto stationaryJoint: DungeonJoint,
        gap: Double
    ) -> Point {
        let outward = outwardUnitVector(for: stationaryJoint.direction)
        let target = stationaryJoint.position
            .offsetBy(Point(x: outward.x * gap, y: outward.y * gap))
        return target.diffOf(movingJoint.position)
    }
    
    public func isMoveSafe(
        movingSegmentId: DungeonSegmentID,
        by delta: Point,
        abutting abuttingRoomId: DungeonSegmentID
    ) -> Bool {
        let movingRoomIds = roomIds(connectedTo: movingSegmentId)
        guard !movingRoomIds.isEmpty else { return false }
        for movingRoomId in movingRoomIds {
            guard let movingRoom = layoutRooms[movingRoomId] else { continue }
            let movedRect = finalRoomRectForRoom(movingRoom).offsetBy(delta)
            let paddedMovedRect = movedRect.inset(by: -minimumRoomSpacing)
            for otherRoom in layoutRooms.values where !movingRoomIds.contains(otherRoom.id) {
                let otherRect = finalRoomRectForRoom(otherRoom)
                if otherRoom.id == abuttingRoomId {
                    if movedRect.intersects(otherRect) { return false }
                } else if paddedMovedRect.intersects(otherRect) {
                    return false
                }
            }
        }
        return true
    }
    
    @discardableResult
    public func findConnection(
        for room: RoomType,
        ignoringJointAlignment: Bool = false
    ) -> Bool {
        for otherRoomId in layoutRooms.keys {
            guard let currentRoom = layoutRooms[room.id],
                  let otherRoom = layoutRooms[otherRoomId] else {
                continue
            }
            if let plan = planConnection(
                between: currentRoom,
                and: otherRoom,
                ignoringJointAlignment: ignoringJointAlignment
            ) {
                createNewGrouping(
                    between: currentRoom,
                    and: otherRoom,
                    connecting: plan.fromJoint,
                    with: plan.toJoint,
                    applying: plan
                )
                return true
            }
        }
        return false
    }

    public func planConnection(
        between room: RoomType,
        and otherRoom: RoomType,
        ignoringJointAlignment: Bool = false
    ) -> DungeonConnectionPlan? {
        guard room.id != otherRoom.id else { return nil }

        // plan to move the smaller connected group of vertices
        let roomGroupSize = roomCount(connectedTo: room.id)
        let otherGroupSize = roomCount(connectedTo: otherRoom.id)
        let roomMovesFirst = roomGroupSize == otherGroupSize
            ? room.id < otherRoom.id
            : roomGroupSize < otherGroupSize

        let consumedJoints = connectedJoints
        for fromJoint in room.joints {
            guard !consumedJoints.contains(fromJoint.id) else { continue }
            for toJoint in otherRoom.joints {
                guard !consumedJoints.contains(toJoint.id) else { continue }
                guard fromJoint.matchesWith(
                    other: toJoint,
                    ignoringPosition: ignoringJointAlignment
                ) else { continue }
                let options: [(DungeonSegmentID, DungeonJoint, DungeonJoint)] = roomMovesFirst
                    ? [(room.id, fromJoint, toJoint), (otherRoom.id, toJoint, fromJoint)]
                    : [(otherRoom.id, toJoint, fromJoint), (room.id, fromJoint, toJoint)]
                for (movingId, movingJoint, stationaryJoint) in options {
                    let delta = alignmentDelta(
                        moving: movingJoint,
                        onto: stationaryJoint,
                        gap: minimumRoomSpacing
                    )
                    guard isMoveSafe(
                        movingSegmentId: movingId,
                        by: delta,
                        abutting: stationaryJoint.segmentId
                    ) else { continue }
                    return DungeonConnectionPlan(
                        fromJoint: fromJoint,
                        toJoint: toJoint,
                        movingSegmentId: movingId,
                        delta: delta
                    )
                }
            }
        }
        return nil
    }
    
    @discardableResult
    public func createNewGrouping(
        between room: RoomType,
        and otherRoom: RoomType,
        connecting fromJoint: DungeonJoint,
        with toJoint: DungeonJoint,
        applying plan: DungeonConnectionPlan? = nil
    ) -> DungeonGrouping {
        let id = String("\(randomNumberGenerator.next())-\(randomNumberGenerator.next())")

        if let plan {
            translate(roomId: plan.movingSegmentId, by: plan.delta)
        }

        let newGrouping = DungeonGrouping(
            id: id,
            from: room.id,
            to: otherRoom.id,
            fromJoint: fromJoint.id,
            toJoint: toJoint.id
        )

        let fromVertex = groupingGraph.createVertex(room.id)
        let toVertex = groupingGraph.createVertex(otherRoom.id)
        groupingGraph.addEdge(
            fromVertex,
            to: toVertex,
            data: newGrouping,
            withWeight: room.rect.center.distanceFrom(otherRoom.rect.center)
        )

        return newGrouping
    }
    
    public func identifyConnections() {
        identifyFreelanceRoomConnections()
        identifyRoomToGroupingConnections()
        identifyGroupingToGroupingConnections()
    }
    
    /// Pairs two solo vertices, building the smallest groups first.
    @discardableResult
    public func identifyFreelanceRoomConnections() -> Bool {
        var madeConnection = false
        for currentRoomId in layoutRooms.keys {
            guard connectionCount(forRoomId: currentRoomId) == 0 else {
                continue
            }
            for otherRoomId in layoutRooms.keys {
                guard connectionCount(forRoomId: otherRoomId) == 0,
                      let currentRoom = layoutRooms[currentRoomId],
                      let otherRoom = layoutRooms[otherRoomId] else {
                    continue
                }
                guard let plan = planConnection(between: currentRoom, and: otherRoom) else {
                    continue // couldn't find a way to line them up
                }
                createNewGrouping(
                    between: currentRoom,
                    and: otherRoom,
                    connecting: plan.fromJoint,
                    with: plan.toJoint,
                    applying: plan
                )
                madeConnection = true
                break
            }
        }
        return madeConnection
    }

    /// Attaches a solo vertex onto a vertex that is already grouped.
    @discardableResult
    public func identifyRoomToGroupingConnections() -> Bool {
        var madeConnection = false
        for currentRoomId in layoutRooms.keys {
            guard connectionCount(forRoomId: currentRoomId) == 0 else {
                continue
            }
            for otherRoomId in layoutRooms.keys {
                guard connectionCount(forRoomId: otherRoomId) > 0,
                      let currentRoom = layoutRooms[currentRoomId],
                      let otherRoom = layoutRooms[otherRoomId] else {
                    continue
                }
                guard let plan = planConnection(between: currentRoom, and: otherRoom) else {
                    continue // couldn't find a way to line them up
                }
                createNewGrouping(
                    between: currentRoom,
                    and: otherRoom,
                    connecting: plan.fromJoint,
                    with: plan.toJoint,
                    applying: plan
                )
                madeConnection = true
                break
            }
        }
        return madeConnection
    }

    /// Joins two already-grouped vertices that belong to separate groups.
    public func identifyGroupingToGroupingConnections() {
        for currentRoomId in layoutRooms.keys {
            guard connectionCount(forRoomId: currentRoomId) > 0 else {
                continue
            }
            let currentGroup = roomIds(connectedTo: currentRoomId)
            for otherRoomId in layoutRooms.keys {
                guard connectionCount(forRoomId: otherRoomId) > 0,
                      !currentGroup.contains(otherRoomId),
                      let currentRoom = layoutRooms[currentRoomId],
                      let otherRoom = layoutRooms[otherRoomId] else {
                    continue
                }
                guard let plan = planConnection(between: currentRoom, and: otherRoom) else {
                    continue
                }
                createNewGrouping(
                    between: currentRoom,
                    and: otherRoom,
                    connecting: plan.fromJoint,
                    with: plan.toJoint,
                    applying: plan
                )
            }
        }
    }
    
    // MARK: - Graphing

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
    
    // MARK: - Grid

    public func to2DGrid() -> [[Int]] {
        guard self.grid.isEmpty else {
            return self.grid
        }
        
        let grid = dungeon.create2DGrid(size: dungeonSize)
        
        self.grid = grid

        return self.grid
    }
}
