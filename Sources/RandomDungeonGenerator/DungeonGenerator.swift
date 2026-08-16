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
    case refining
    case finished
}

public class DungeonGenerator<SegmentType: DungeonSegment>: Equatable {
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
    
    public var segmentPool: [SegmentType]?
    
    public var useMinimumSpanningTreeForLayout: Bool = true
    public private(set) var lastSeed: UInt64 = 0
    
    // MARK: Intermediary State during generation
    public private(set) var state: DungeonGeneratorState = .initialState
    public private(set) var groupingGraph: AdjacencyListGraph<DungeonSegmentID, DungeonGrouping> = .init()
    public private(set) var layoutRooms: OrderedDictionary<DungeonSegmentID, SegmentType> = [:]
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
            guard containsNoIntersectingRooms() || connectedGroups().count == 1 else {
                applyFittingStep()
                return
            }
            state = .roundingRoomPositions
        case .roundingRoomPositions:
            roundRoomPositions()
            state = .refittingAndRounding
        case .refittingAndRounding:
            guard containsNoIntersectingRooms() || connectedGroups().count == 1 else {
                applyFittingStep()
                roundRoomPositions()
                return
            }
            if connectedGroups().count != 1 {
                let groupingsCount = groupingGraph.edges.count
                identifyConnections()
                if groupingsCount != groupingGraph.edges.count {
                    state = .fittingUntilNoMoreIntersections
                    return
                }
            }
            // reevaluate connected groups count again
            if connectedGroups().count != 1 {
                for room in ungroupedRooms() {
                    if findConnection(for: room, ignoringJointAlignment: true) {
                        state = .fittingUntilNoMoreIntersections
                        return
                    }
                }
            }
            
            // reevaluate connected groups count agai
            if connectedGroups().count != 1 {
                for group in connectedGroups() {
                    if findConnection(for: group, ignoringJointAlignment: true) {
                        state = .fittingUntilNoMoreIntersections
                        return
                    }
                }
            }
           
            centerAllRoomsInDungeon()

            state = .refining
        case .refining:
            addSingleLoopConnection()
            state = .finished
        case .finished:
            break
        }
    }
    
    public func runCompleteGeneration(withSegmentPool segmentPool: [SegmentType]? = nil) {
        if let segmentPool {
            self.segmentPool = segmentPool
        }
        
        reset()
        
        while state != .finished {
            nextGenerationStep()
        }
    }
    
    // MARK: - Dungeon Prep
    
    public func regenerateRooms() {
        layoutRooms = [:]
        if let segmentPool {
            segmentPool
                .filter { $0.layoutCategory == .room }
                .forEach { room in
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
                let room = SegmentType(id: "room-\(index)", rect: rect, layoutCategory: .room)
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

    public func ungroupedRooms() -> [SegmentType] {
        let grouped = groupedRooms
        return layoutRooms.values.filter { !grouped.contains($0.id) }
    }
    
    public func iterateRoomWithAllRooms(
        _ roomId: DungeonSegmentID,
        using body: (SegmentType) -> Void
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

            translateRoomsOnly(
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
        _ currentRoom: SegmentType,
        intersectWith otherRoom: SegmentType
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

                    translateRoomsOnly(
                        group,
                        by: diffOffset.offsetBy(x: randOffsetX, y: randOffsetY)
                    )
                    break mainLoop
                }
            }
        }
    }
    
    // MARK: - Geometry
    
    public func finalRoomRectForRoom(_ room: SegmentType) -> Rect {
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
        translateRoomsOnly(
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

    /// Rooms within the same connected group only have to avoid overlapping: they move as a
    /// unit, so their separation cannot be changed by fitting and demanding
    /// `minimumRoomSpacing` between them would never be satisfiable. Rooms in different
    /// groups still have to respect the spacing, since fitting can push those apart.
    public func containsNoIntersectingRooms() -> Bool {
        var groupIndexByRoom: [DungeonSegmentID: Int] = [:]
        for (index, group) in connectedGroups().enumerated() {
            for roomId in group {
                groupIndexByRoom[roomId] = index
            }
        }
        for currentRoom in layoutRooms.values {
            for otherRoom in layoutRooms.values {
                guard currentRoom.id != otherRoom.id else { continue }
                let currentGroup = groupIndexByRoom[currentRoom.id]
                if currentGroup != nil, currentGroup == groupIndexByRoom[otherRoom.id] {
                    if currentRoom.rect.intersects(otherRoom.rect) {
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
    
    /// The single connection a room holds, as the room's own joint and the joint it meets.
    /// Returns nil unless the room has exactly one connection.
    public func singleConnection(
        forRoomId roomId: DungeonSegmentID
    ) -> (own: DungeonJoint, partner: DungeonJoint)? {
        guard connectionCount(forRoomId: roomId) == 1,
              let edge = groupingGraph.edges.first(where: {
                  $0.from.data == roomId || $0.to.data == roomId
              }) else {
            return nil
        }
        let roomIsFrom = edge.from.data == roomId
        let ownJointId = roomIsFrom ? edge.grouping.fromJoint : edge.grouping.toJoint
        let partnerJointId = roomIsFrom ? edge.grouping.toJoint : edge.grouping.fromJoint
        let partnerRoomId = roomIsFrom ? edge.to.data : edge.from.data
        guard let room = layoutRooms[roomId],
              let partnerRoom = layoutRooms[partnerRoomId],
              let own = room.joints.first(where: { $0.id == ownJointId }),
              let partner = partnerRoom.joints.first(where: { $0.id == partnerJointId }) else {
            return nil
        }
        return (own, partner)
    }

    public func freeSlideAxisForRoom(_ roomId: DungeonSegmentID) -> DungeonJointDirections? {
        guard let connection = singleConnection(forRoomId: roomId) else {
            return nil
        }
        switch connection.own.direction {
        case .north, .south: return .northSouth
        case .east, .west: return .eastWest
        default: return nil
        }
    }

    /// Sliding along a connection's axis lengthens it, but slide far enough and the room
    /// crosses its partner, which flips the joint ordering and turns the corridor back on
    /// itself. This applies the same rule used when the connection was first made.
    public func slidePreservesConnection(
        _ connection: (own: DungeonJoint, partner: DungeonJoint),
        by delta: Point
    ) -> Bool {
        let movedOwnJoint = connection.own.offsetBy(delta)
        guard movedOwnJoint.matchesWith(other: connection.partner) else {
            return false
        }
        let gap = max(
            abs(movedOwnJoint.position.x - connection.partner.position.x),
            abs(movedOwnJoint.position.y - connection.partner.position.y)
        )
        return gap >= minimumRoomSpacing
    }

    public func canSlideRoom(
        _ room: SegmentType,
        by delta: Point,
        abutting abuttingRoomId: DungeonSegmentID
    ) -> Bool {
        let movedRect = room.rect.offsetBy(delta)
        let paddedRect = movedRect.inset(by: -minimumRoomSpacing)
        for otherRoom in layoutRooms.values where otherRoom.id != room.id {
            if otherRoom.id == abuttingRoomId {
                if movedRect.intersects(otherRoom.rect) { return false }
            } else if paddedRect.intersects(otherRoom.rect) {
                return false
            }
        }
        return true
    }

    /// Final polish. Looks for a room with exactly one connection that can slide along that
    /// connection's axis until a second pair of joints lines up, adding one extra edge to the
    /// graph. The existing connection survives because sliding along its axis only lengthens
    /// it, so this trades a longer corridor for one loop in the dungeon.
    @discardableResult
    public func addSingleLoopConnection() -> Bool {
        let consumedJoints = connectedJoints
        for roomId in layoutRooms.keys {
            guard let slideAxis = freeSlideAxisForRoom(roomId),
                  let existingConnection = singleConnection(forRoomId: roomId),
                  let room = layoutRooms[roomId] else {
                continue
            }
            let slidesVertically = slideAxis == .northSouth
            for newJoint in room.joints where !consumedJoints.contains(newJoint.id) {
                let newPairIsHorizontal = newJoint.direction == .east
                    || newJoint.direction == .west
                // only a pair perpendicular to the slide axis can be brought into line
                guard slidesVertically == newPairIsHorizontal else { continue }
                for otherRoomId in layoutRooms.keys where otherRoomId != roomId {
                    guard let otherRoom = layoutRooms[otherRoomId] else { continue }
                    for partnerJoint in otherRoom.joints
                    where !consumedJoints.contains(partnerJoint.id) {
                        guard newJoint.matchesWith(other: partnerJoint) else { continue }
                        let slide = slidesVertically
                            ? Point(x: 0, y: partnerJoint.position.y - newJoint.position.y)
                            : Point(x: partnerJoint.position.x - newJoint.position.x, y: 0)
                        guard slidePreservesConnection(existingConnection, by: slide),
                              canSlideRoom(room, by: slide, abutting: otherRoomId) else {
                            continue
                        }
                        translateRoomsOnly([roomId], by: slide)
                        guard let movedRoom = layoutRooms[roomId],
                              let movedJoint = movedRoom.joints.first(where: {
                                  $0.id == newJoint.id
                              }) else {
                            translateRoomsOnly([roomId], by: Point(x: -slide.x, y: -slide.y))
                            continue
                        }
                        createNewGrouping(
                            between: movedRoom,
                            and: otherRoom,
                            connecting: movedJoint,
                            with: partnerJoint
                        )
                        return true
                    }
                }
            }
        }
        return false
    }

    /// Moves the given room together with every room connected to it, so the group keeps its
    /// internal alignment.
    public func translateGroup(connectedTo roomId: DungeonSegmentID, by delta: Point) {
        translateRoomsOnly(roomIds(connectedTo: roomId), by: delta)
    }

    /// Moves exactly the rooms given and nothing else. A connection to any room outside this
    /// set will be pulled out of alignment unless the caller has established that the move
    /// preserves it.
    public func translateRoomsOnly(
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
        for room: SegmentType,
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
    
    @discardableResult
    public func findConnection(
        for grouping: OrderedSet<DungeonSegmentID>,
        ignoringJointAlignment: Bool = false
    ) -> Bool {
        for roomId in grouping {
            guard let room = layoutRooms[roomId] else { continue }
            for otherRoomId in layoutRooms.keys {
                guard !grouping.contains(otherRoomId),
                      let currentRoom = layoutRooms[roomId],
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
        }
        return false
    }

    public func planConnection(
        between room: SegmentType,
        and otherRoom: SegmentType,
        ignoringJointAlignment: Bool = false
    ) -> DungeonConnectionPlan? {
        guard room.id != otherRoom.id else { return nil }
        guard !roomIds(connectedTo: room.id).contains(otherRoom.id) else { return nil }

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
        between room: SegmentType,
        and otherRoom: SegmentType,
        connecting fromJoint: DungeonJoint,
        with toJoint: DungeonJoint,
        applying plan: DungeonConnectionPlan? = nil
    ) -> DungeonGrouping {
        let id = String("\(randomNumberGenerator.next())-\(randomNumberGenerator.next())")

        if let plan {
            translateGroup(connectedTo: plan.movingSegmentId, by: plan.delta)
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
}
