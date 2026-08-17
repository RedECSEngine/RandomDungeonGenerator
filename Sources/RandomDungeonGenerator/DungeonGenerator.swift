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
    case addingHallways
    case finished
}

public class DungeonGenerator<SegmentType: DungeonSegment>: Equatable {
    public static func == (lhs: DungeonGenerator, rhs: DungeonGenerator) -> Bool {
        return lhs === rhs
    }
    
    internal var randomNumberGenerator: any RandomNumberGenerator = SystemRandomNumberGenerator()
    
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
    public internal(set) var lastSeed: UInt64 = 0
    
    // MARK: Intermediary State during generation
    public internal(set) var state: DungeonGeneratorState = .initialState
    public internal(set) var groupingGraph: AdjacencyListGraph<DungeonSegmentID, DungeonGrouping> = .init()
    public internal(set) var layoutSegments: OrderedDictionary<DungeonSegmentID, SegmentType> = [:]
    public internal(set) var numberOfStepsTaken = 0
    public internal(set) var totalNumberOfStepsTakenAcrossAttempts = 0

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
        layoutSegments = [:]
        groupingGraph = .init()
    }
    
    public func nextGenerationStep() throws {
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
            state = .addingHallways
        case .addingHallways:
            try fillInHallways()
            state = .finished
        case .finished:
            break
        }
    }
    
    public func runCompleteGeneration(withSegmentPool segmentPool: [SegmentType]? = nil) throws {
        if let segmentPool {
            self.segmentPool = segmentPool
        }

        reset()

        while state != .finished {
            try nextGenerationStep()
        }
    }
    
    // MARK: - Dungeon Prep
    
    public func regenerateRooms() {
        layoutSegments = [:]
        if let segmentPool {
            segmentPool
                .filter { $0.layoutCategory == .room }
                .forEach { room in
                    layoutSegments[room.id] = room
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
                layoutSegments[room.id] = room
            }
        }
    }
}
