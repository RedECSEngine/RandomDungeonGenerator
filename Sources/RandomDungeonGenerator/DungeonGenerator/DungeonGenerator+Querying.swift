import Geometry
import OrderedCollections
import Graphs

extension DungeonGenerator {
    
    public func doesRoom(
        _ currentRoom: SegmentType,
        intersectWith otherRoom: SegmentType
    ) -> Bool {
        let rect = currentRoom.rect
        let roomRect = otherRoom.rect
        let paddedRect = rect.inset(by: -minimumRoomSpacing)
        return paddedRect.intersects(roomRect)
    }
    
    public func containsNoIntersectingRooms() -> Bool {
        var groupIndexByRoom: [DungeonSegmentID: Int] = [:]
        for (index, group) in connectedGroups().enumerated() {
            for roomId in group {
                groupIndexByRoom[roomId] = index
            }
        }
        for currentRoom in layoutSegments.values {
            for otherRoom in layoutSegments.values {
                guard currentRoom.id != otherRoom.id else { continue }
                let currentGroup = groupIndexByRoom[currentRoom.id]
                // When we are checking within a group we only check for direction intersections, minimum requirements can be ignored
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
    
    public func connectionCount(forRoomId roomId: DungeonSegmentID) -> Int {
        groupingGraph.edges.reduce(into: 0) { total, edge in
            if edge.from.data == roomId || edge.to.data == roomId {
                total += 1
            }
        }
    }

    public func connectedGroups() -> [OrderedSet<DungeonSegmentID>] {
        var unionFind = UnionFind<DungeonSegmentID>()
        for roomId in layoutSegments.keys {
            unionFind.addSetWith(roomId)
        }
        for edge in groupingGraph.edges {
            unionFind.unionSetsContaining(edge.from.data, and: edge.to.data)
        }
        var groupsBySet: OrderedDictionary<Int, OrderedSet<DungeonSegmentID>> = [:]
        for roomId in layoutSegments.keys {
            guard let setId = unionFind.setOf(roomId) else { continue }
            groupsBySet[setId, default: []].append(roomId)
        }
        return Array(groupsBySet.values)
    }

    public func roomIds(connectedToAndIncluding roomId: DungeonSegmentID) -> OrderedSet<DungeonSegmentID> {
        connectedGroups().first { $0.contains(roomId) } ?? [roomId]
    }

    public func roomCount(connectedTo roomId: DungeonSegmentID) -> Int {
        roomIds(connectedToAndIncluding: roomId).count
    }

    public func ungroupedRooms() -> [SegmentType] {
        let grouped = groupedRooms
        return layoutSegments.values.filter { !grouped.contains($0.id) }
    }
    
    /// The single connection a room holds, as the room's own joint and the joint it meets.
    /// Returns nil unless the room has exactly one connection.
    public func singularConnection(
        ofRoomId roomId: DungeonSegmentID
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
        guard let room = layoutSegments[roomId],
              let partnerRoom = layoutSegments[partnerRoomId],
              let own = room.joints.first(where: { $0.id == ownJointId }),
              let partner = partnerRoom.joints.first(where: { $0.id == partnerJointId }) else {
            return nil
        }
        return (own, partner)
    }
}
