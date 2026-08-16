import Geometry
import OrderedCollections

extension DungeonGenerator {
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
 
    /// Moves the given room together with every room connected to it, so the group keeps its
    /// internal alignment.
    public func translateGroup(connectedTo roomId: DungeonSegmentID, by delta: Point) {
        translateRoomsOnly(roomIds(connectedToAndIncluding: roomId), by: delta)
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

    /// determine what offset we need in order to line up the joints
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

}
