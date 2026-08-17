import Geometry
import OrderedCollections

extension DungeonGenerator {
    public func freeSlideAxisForRoom(_ roomId: DungeonSegmentID) -> DungeonJointDirections? {
        guard let connection = singularConnection(ofRoomId: roomId) else {
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
        guard gap >= minimumRoomSpacing else {
            return false
        }
        return isGapFillable(between: movedOwnJoint, and: connection.partner)
    }

    public func isGapFillable(
        between fromJoint: DungeonJoint,
        and toJoint: DungeonJoint
    ) -> Bool {
        guard let axis = straightGapAxis(from: fromJoint, to: toJoint),
              let maximumGap = maximumFillableGap(
                  along: axis,
                  bridging: fromJoint,
                  and: toJoint
              ) else {
            return true
        }
        let gap = distance(from: fromJoint, to: toJoint, along: axis)
        return gap <= maximumGap + Self.jointAlignmentTolerance
    }

    public func canSlideRoom(
        _ room: SegmentType,
        by delta: Point,
        abutting abuttingRoomId: DungeonSegmentID
    ) -> Bool {
        let movedRect = room.rect.offsetBy(delta)
        let paddedRect = movedRect.inset(by: -minimumRoomSpacing)
        for otherRoom in layoutSegments.values where otherRoom.id != room.id {
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
        for roomId in layoutSegments.keys {
            guard let slideAxis = freeSlideAxisForRoom(roomId),
                  let existingConnection = singularConnection(ofRoomId: roomId),
                  let room = layoutSegments[roomId] else {
                continue
            }
            let slidesVertically = slideAxis == .northSouth
            for newJoint in room.joints where !consumedJoints.contains(newJoint.id) {
                let newPairIsHorizontal = newJoint.direction == .east
                    || newJoint.direction == .west
                // only a pair perpendicular to the slide axis can be brought into line
                guard slidesVertically == newPairIsHorizontal else { continue }
                for otherRoomId in layoutSegments.keys where otherRoomId != roomId {
                    guard let otherRoom = layoutSegments[otherRoomId] else { continue }
                    for partnerJoint in otherRoom.joints
                    where !consumedJoints.contains(partnerJoint.id) {
                        guard newJoint.matchesWith(other: partnerJoint),
                              isGapFillable(between: newJoint, and: partnerJoint) else {
                            continue
                        }
                        let slide = slidesVertically
                            ? Point(x: 0, y: partnerJoint.position.y - newJoint.position.y)
                            : Point(x: partnerJoint.position.x - newJoint.position.x, y: 0)
                        guard slidePreservesConnection(existingConnection, by: slide),
                              canSlideRoom(room, by: slide, abutting: otherRoomId) else {
                            continue
                        }
                        translateRoomsOnly([roomId], by: slide)
                        guard let movedRoom = layoutSegments[roomId],
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
}
