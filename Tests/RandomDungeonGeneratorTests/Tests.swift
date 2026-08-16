import XCTest
import Geometry
@testable import RandomDungeonGenerator

private struct TestRoom: DungeonRoom {
    var id: DungeonSegmentID
    var rect: Rect

    init(id: DungeonSegmentID, rect: Rect) {
        self.id = id
        self.rect = rect
    }

    var joints: [DungeonJoint] {
        [
            ("n", DungeonJointDirections.north, Point(x: rect.midX, y: rect.minY)),
            ("e", .east, Point(x: rect.maxX, y: rect.midY)),
            ("s", .south, Point(x: rect.midX, y: rect.maxY)),
            ("w", .west, Point(x: rect.minX, y: rect.midY)),
        ].map {
            DungeonJoint(
                id: DungeonJointID(stringLiteral: "\(id)-\($0.0)"),
                segmentId: id,
                position: $0.2,
                direction: $0.1
            )
        }
    }
}

private func makeGenerator(
    seed: UInt64,
    roomCount: Int = 8
) -> DungeonGenerator<TestRoom, DefaultDungeonHallway> {
    let generator = DungeonGenerator<TestRoom, DefaultDungeonHallway>(seed)
    generator.dungeonSize = .init(width: 64, height: 64)
    generator.creationBounds = .init(width: 16, height: 16)
    generator.minimumRoomSpacing = 5
    generator.initialRooms = (0..<roomCount).map { index in
        TestRoom(
            id: "room-\(index)",
            rect: Rect(
                origin: .init(x: 20, y: 20),
                size: .init(
                    width: Double(5 + index % 4),
                    height: Double(5 + (index * 3) % 4)
                )
            )
        )
    }
    return generator
}

private func runToCompletion(
    _ generator: DungeonGenerator<TestRoom, DefaultDungeonHallway>,
    stepLimit: Int = 25_000
) -> Int {
    var steps = 0
    while generator.state != .finished && steps < stepLimit {
        generator.nextGenerationStep()
        steps += 1
    }
    return steps
}

/// Two rooms placed side by side, far enough apart that a west/east joint pair
/// satisfies the ordering rule in `DungeonJoint.matchesWith`.
private func makePairGenerator() -> DungeonGenerator<TestRoom, DefaultDungeonHallway> {
    let generator = DungeonGenerator<TestRoom, DefaultDungeonHallway>(1)
    generator.dungeonSize = .init(width: 64, height: 64)
    generator.minimumRoomSpacing = 5
    generator.initialRooms = [
        TestRoom(id: "left", rect: Rect(origin: .init(x: 10, y: 10), size: .init(width: 6, height: 6))),
        TestRoom(id: "right", rect: Rect(origin: .init(x: 30, y: 10), size: .init(width: 6, height: 6))),
    ]
    generator.regenerateRooms()
    return generator
}

private let testSeeds: [UInt64] = [1, 2, 3, 4, 5, 6]

final class Tests: XCTestCase {

    func testGenerationConverges() {
        for seed in testSeeds {
            let generator = makeGenerator(seed: seed)
            let steps = runToCompletion(generator)
            XCTAssertEqual(
                generator.state, .finished,
                "seed \(seed) did not converge within \(steps) steps"
            )
        }
    }

    func testEveryRoomBelongsToExactlyOneConnectedGroup() {
        for seed in testSeeds {
            let generator = makeGenerator(seed: seed)
            _ = runToCompletion(generator)
            var membershipCount: [DungeonSegmentID: Int] = [:]
            for group in generator.connectedGroups() {
                for roomId in group {
                    membershipCount[roomId, default: 0] += 1
                }
            }
            let shared = membershipCount.filter { $0.value > 1 }
            XCTAssertTrue(
                shared.isEmpty,
                "seed \(seed): rooms in more than one movable group: \(shared.keys.sorted())"
            )
            XCTAssertEqual(
                membershipCount.count, generator.layoutRooms.count,
                "seed \(seed): every room should appear in exactly one group"
            )
        }
    }

    func testConnectedJointsLandOnTheirRooms() {
        for seed in testSeeds {
            let generator = makeGenerator(seed: seed)
            _ = runToCompletion(generator)
            for edge in generator.groupingGraph.edges {
                let grouping = edge.grouping
                let ends = [
                    (grouping.from, grouping.fromJoint),
                    (grouping.to, grouping.toJoint),
                ]
                for (roomId, jointId) in ends {
                    guard let room = generator.layoutRooms[roomId],
                          let joint = room.joints.first(where: { $0.id == jointId }) else {
                        XCTFail("seed \(seed): grouping references a missing room or joint")
                        continue
                    }
                    let rect = room.rect
                    XCTAssertTrue(
                        joint.position.x >= rect.minX - 0.001
                            && joint.position.x <= rect.maxX + 0.001
                            && joint.position.y >= rect.minY - 0.001
                            && joint.position.y <= rect.maxY + 0.001,
                        "seed \(seed): joint \(jointId) is not on room \(roomId)"
                    )
                }
            }
        }
    }

    func testFinalLayoutHasNoOverlappingRooms() {
        for seed in testSeeds {
            let generator = makeGenerator(seed: seed)
            _ = runToCompletion(generator)
            let rooms = Array(generator.layoutRooms.values)
            for i in 0..<rooms.count {
                for j in (i + 1)..<rooms.count {
                    XCTAssertFalse(
                        rooms[i].rect.intersects(rooms[j].rect),
                        "seed \(seed): \(rooms[i].id) overlaps \(rooms[j].id)"
                    )
                }
            }
        }
    }

    func testSameSeedProducesSameLayout() {
        func layoutFingerprint(seed: UInt64) -> String {
            let generator = makeGenerator(seed: seed)
            _ = runToCompletion(generator)
            return generator.layoutRooms.values
                .map { "\($0.id):\($0.rect.origin)" }
                .joined(separator: "|")
        }
        for seed in testSeeds {
            XCTAssertEqual(
                layoutFingerprint(seed: seed),
                layoutFingerprint(seed: seed),
                "seed \(seed) is not reproducible"
            )
        }
    }

    func testConnectingTwoRoomsAddsOneEdgeAndConsumesBothJoints() {
        let generator = makePairGenerator()
        XCTAssertEqual(generator.groupingGraph.edges.count, 0)
        XCTAssertTrue(generator.connectedJoints.isEmpty)

        let rooms = Array(generator.layoutRooms.values)
        guard let plan = generator.planConnection(between: rooms[0], and: rooms[1]) else {
            return XCTFail("expected a connection between two freshly placed rooms")
        }
        generator.createNewGrouping(
            between: rooms[0],
            and: rooms[1],
            connecting: plan.fromJoint,
            with: plan.toJoint,
            applying: plan
        )

        XCTAssertEqual(generator.groupingGraph.edges.count, 1)
        XCTAssertEqual(generator.groupedRooms.count, 2)
        XCTAssertEqual(generator.connectedJoints.count, 2)
        XCTAssertEqual(generator.roomCount(connectedTo: rooms[0].id), 2)
        XCTAssertEqual(generator.connectionCount(forRoomId: rooms[0].id), 1)
    }

    func testTranslateMovesEveryRoomInTheConnectedGroup() {
        let generator = makePairGenerator()
        let rooms = Array(generator.layoutRooms.values)
        guard let plan = generator.planConnection(between: rooms[0], and: rooms[1]) else {
            return XCTFail("expected a connection between two freshly placed rooms")
        }
        generator.createNewGrouping(
            between: rooms[0],
            and: rooms[1],
            connecting: plan.fromJoint,
            with: plan.toJoint,
            applying: plan
        )

        let before = generator.layoutRooms.mapValues { $0.rect.origin }
        let delta = Point(x: 3, y: -2)
        generator.translateGroup(connectedTo: rooms[0].id, by: delta)

        for (roomId, origin) in before {
            guard let moved = generator.layoutRooms[roomId] else {
                return XCTFail("room \(roomId) disappeared")
            }
            XCTAssertEqual(moved.rect.origin.x, origin.x + delta.x, accuracy: 0.0001)
            XCTAssertEqual(moved.rect.origin.y, origin.y + delta.y, accuracy: 0.0001)
        }
    }
}
