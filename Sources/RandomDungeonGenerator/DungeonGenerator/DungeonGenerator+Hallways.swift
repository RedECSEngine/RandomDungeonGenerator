import Geometry
import OrderedCollections

extension DungeonGenerator {
    static var jointAlignmentTolerance: Double { 0.001 }

    func fillInHallways() throws {
        guard let hallwayPool, !hallwayPool.isEmpty else { return }

        var fillCount = 0
        for edge in groupingGraph.edges {
            let grouping = edge.grouping
            guard let fromSegment = layoutRooms[grouping.from] else {
                throw DungeonGeneratorError.missingSegment(grouping.from)
            }
            guard let toSegment = layoutRooms[grouping.to] else {
                throw DungeonGeneratorError.missingSegment(grouping.to)
            }
            guard let fromJoint = fromSegment.joints.first(where: { $0.id == grouping.fromJoint }) else {
                throw DungeonGeneratorError.missingJoint(grouping.fromJoint)
            }
            guard let toJoint = toSegment.joints.first(where: { $0.id == grouping.toJoint }) else {
                throw DungeonGeneratorError.missingJoint(grouping.toJoint)
            }
            guard let axis = straightGapAxis(from: fromJoint, to: toJoint) else { continue }

            let gap = distance(from: fromJoint, to: toJoint, along: axis)
            guard let candidate = fillerSegment(
                in: hallwayPool,
                spanning: gap,
                along: axis,
                bridging: fromJoint,
                and: toJoint
            ) else {
                continue
            }

            var hallway = try candidate.makeCopy(withId: "\(candidate.id)-fill-\(fillCount)")
            guard let localNearJoint = hallway.joints.first(where: {
                $0.direction == fromJoint.direction.opposite
            }), let span = jointSpan(
                of: hallway,
                along: axis,
                from: fromJoint,
                to: toJoint
            ) else {
                throw DungeonGeneratorError.fillerJointsMisaligned(hallway.id)
            }

            if gap - span > Self.jointAlignmentTolerance {
                hallway = try hallway.stretched(
                    by: gap - span,
                    along: axis,
                    anchoredAt: localNearJoint.position
                )
            }

            guard let nearJoint = hallway.joints.first(where: {
                $0.direction == fromJoint.direction.opposite
            }), let farJoint = hallway.joints.first(where: {
                $0.direction == toJoint.direction.opposite
            }) else {
                throw DungeonGeneratorError.fillerJointsMisaligned(hallway.id)
            }

            hallway.rect = hallway.rect.offsetBy(
                alignmentDelta(moving: nearJoint, onto: fromJoint, gap: 0)
            )

            guard let placedNearJoint = hallway.joints.first(where: { $0.id == nearJoint.id }),
                  let placedFarJoint = hallway.joints.first(where: { $0.id == farJoint.id }),
                  isAligned(placedNearJoint.position, with: fromJoint.position),
                  isAligned(placedFarJoint.position, with: toJoint.position) else {
                throw DungeonGeneratorError.fillerJointsMisaligned(hallway.id)
            }

            guard isPlacementSafe(
                rect: hallway.rect,
                ignoring: [fromSegment.id, toSegment.id],
                padded: false
            ) else {
                continue
            }

            layoutRooms[hallway.id] = hallway
            groupingGraph.removeEdge(edge)
            createNewGrouping(
                between: fromSegment,
                and: hallway,
                connecting: fromJoint,
                with: placedNearJoint
            )
            createNewGrouping(
                between: hallway,
                and: toSegment,
                connecting: placedFarJoint,
                with: toJoint
            )
            fillCount += 1
        }
    }

    var hallwayPool: [SegmentType]? {
        guard let segmentPool else { return nil }
        let hallways = segmentPool.filter { $0.layoutCategory == .hallway }
        return hallways.isEmpty ? nil : hallways
    }

    func straightGapAxis(
        from fromJoint: DungeonJoint,
        to toJoint: DungeonJoint
    ) -> DungeonJointDirections? {
        let tolerance = Self.jointAlignmentTolerance
        let horizontalGap = abs(toJoint.position.x - fromJoint.position.x)
        let verticalGap = abs(toJoint.position.y - fromJoint.position.y)
        let isHorizontal = horizontalGap > tolerance && verticalGap <= tolerance
        let isVertical = verticalGap > tolerance && horizontalGap <= tolerance
        guard isHorizontal != isVertical else { return nil }
        return isHorizontal ? .eastWest : .northSouth
    }

    func distance(
        from fromJoint: DungeonJoint,
        to toJoint: DungeonJoint,
        along axis: DungeonJointDirections
    ) -> Double {
        axis == .eastWest
            ? abs(toJoint.position.x - fromJoint.position.x)
            : abs(toJoint.position.y - fromJoint.position.y)
    }

    func jointSpan(
        of segment: SegmentType,
        along axis: DungeonJointDirections,
        from fromJoint: DungeonJoint,
        to toJoint: DungeonJoint
    ) -> Double? {
        guard let nearJoint = segment.joints.first(where: {
            $0.direction == fromJoint.direction.opposite
        }), let farJoint = segment.joints.first(where: {
            $0.direction == toJoint.direction.opposite
        }) else {
            return nil
        }
        return distance(from: nearJoint, to: farJoint, along: axis)
    }

    func fillerSegment(
        in pool: [SegmentType],
        spanning gap: Double,
        along axis: DungeonJointDirections,
        bridging fromJoint: DungeonJoint,
        and toJoint: DungeonJoint
    ) -> SegmentType? {
        pool.first { candidate in
            guard let maximum = candidate.maximumStretchedLength(along: axis),
                  let span = jointSpan(
                      of: candidate,
                      along: axis,
                      from: fromJoint,
                      to: toJoint
                  ),
                  span <= gap + Self.jointAlignmentTolerance else {
                return false
            }
            return candidate.length(along: axis) + (gap - span) <= maximum
        }
    }

    func maximumFillableGap(
        along axis: DungeonJointDirections,
        bridging fromJoint: DungeonJoint,
        and toJoint: DungeonJoint
    ) -> Double? {
        guard let hallwayPool else { return nil }
        return hallwayPool.reduce(into: 0) { longest, candidate in
            guard let maximum = candidate.maximumStretchedLength(along: axis),
                  let span = jointSpan(
                      of: candidate,
                      along: axis,
                      from: fromJoint,
                      to: toJoint
                  ) else {
                return
            }
            longest = max(longest, span + (maximum - candidate.length(along: axis)))
        }
    }

    func isAligned(_ point: Point, with otherPoint: Point) -> Bool {
        abs(point.x - otherPoint.x) <= Self.jointAlignmentTolerance
            && abs(point.y - otherPoint.y) <= Self.jointAlignmentTolerance
    }
}
