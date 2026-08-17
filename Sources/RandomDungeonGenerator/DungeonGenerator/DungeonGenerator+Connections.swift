import OrderedCollections
import Geometry

extension DungeonGenerator {
    public func identifyConnections() {
        identifyFreelanceRoomConnections()
        identifyRoomToGroupingConnections()
        identifyGroupingToGroupingConnections()
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
    

    @discardableResult
    public func findConnection(
        for room: SegmentType,
        ignoringJointAlignment: Bool = false
    ) -> Bool {
        for otherRoomId in layoutSegments.keys {
            guard let currentRoom = layoutSegments[room.id],
                  let otherRoom = layoutSegments[otherRoomId] else {
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
            for otherRoomId in layoutSegments.keys {
                guard !grouping.contains(otherRoomId),
                      let currentRoom = layoutSegments[roomId],
                      let otherRoom = layoutSegments[otherRoomId] else {
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
        guard !roomIds(connectedToAndIncluding: room.id).contains(otherRoom.id) else { return nil }
        
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
                        nextTo: stationaryJoint.segmentId
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
    
    public func isPlacementSafe(
        rect: Rect,
        ignoring ignoredIds: Set<DungeonSegmentID>,
        padded: Bool
    ) -> Bool {
        let checkedRect = padded ? rect.inset(by: -minimumRoomSpacing) : rect
        for otherRoom in layoutSegments.values where !ignoredIds.contains(otherRoom.id) {
            if checkedRect.intersects(otherRoom.rect) { return false }
        }
        return true
    }

    public func isMoveSafe(
        movingSegmentId: DungeonSegmentID,
        by delta: Point,
        nextTo adjacentRoomId: DungeonSegmentID
    ) -> Bool {
        let movingRoomIds = roomIds(connectedToAndIncluding: movingSegmentId)
        guard !movingRoomIds.isEmpty else { return false }
        let movingIds = Set(movingRoomIds)
        for movingRoomId in movingRoomIds {
            guard let movingRoom = layoutSegments[movingRoomId] else { continue }
            let movedRect = movingRoom.rect.offsetBy(delta)
            guard isPlacementSafe(
                rect: movedRect,
                ignoring: movingIds.union([adjacentRoomId]),
                padded: true
            ), isPlacementSafe(
                rect: movedRect,
                ignoring: movingIds,
                padded: false
            ) else {
                return false
            }
        }
        return true
    }
    
    /// Pairs two solo vertices, building the smallest groups first.
    @discardableResult
    public func identifyFreelanceRoomConnections() -> Bool {
        var madeConnection = false
        for currentRoomId in layoutSegments.keys {
            guard connectionCount(forRoomId: currentRoomId) == 0 else {
                continue
            }
            for otherRoomId in layoutSegments.keys {
                guard connectionCount(forRoomId: otherRoomId) == 0,
                      let currentRoom = layoutSegments[currentRoomId],
                      let otherRoom = layoutSegments[otherRoomId] else {
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
        for currentRoomId in layoutSegments.keys {
            guard connectionCount(forRoomId: currentRoomId) == 0 else {
                continue
            }
            for otherRoomId in layoutSegments.keys {
                guard connectionCount(forRoomId: otherRoomId) > 0,
                      let currentRoom = layoutSegments[currentRoomId],
                      let otherRoom = layoutSegments[otherRoomId] else {
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
        for currentRoomId in layoutSegments.keys {
            guard connectionCount(forRoomId: currentRoomId) > 0 else {
                continue
            }
            let currentGroup = roomIds(connectedToAndIncluding: currentRoomId)
            for otherRoomId in layoutSegments.keys {
                guard connectionCount(forRoomId: otherRoomId) > 0,
                      !currentGroup.contains(otherRoomId),
                      let currentRoom = layoutSegments[currentRoomId],
                      let otherRoom = layoutSegments[otherRoomId] else {
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
