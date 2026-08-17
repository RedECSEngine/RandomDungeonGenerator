import OrderedCollections
import Geometry

// MARK: - Fitting
extension DungeonGenerator {
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
            
            layoutSegments.keys.forEach {
                otherRoomId in
                guard currentRoom.id != otherRoomId,
                      let otherRoom = layoutSegments[otherRoomId] else {
                    return
                }
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
            layoutSegments[newRoom.id] = newRoom
        }
    }
    
    public func applyGroupingsFitting() {
        for group in connectedGroups() where group.count > 1 {
            var velocityX: Double = 0
            var velocityY: Double = 0
            var neighborCount: Int = 0
            var diagonalLength: Double = 0
            
            for roomId in group {
                guard let room = layoutSegments[roomId] else { continue }
                let rect = room.rect
                diagonalLength += rect.diagonalLength
                let paddedRect = rect.inset(by: -minimumRoomSpacing)
                for otherRoom in layoutSegments.values where !group.contains(otherRoom.id) {
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
            layoutSegments[newRoom.id] = newRoom
        }
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
                    layoutSegments[newRoom.id] = newRoom
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
    
    public func centerAllRoomsInDungeon() {
        guard let layoutRect = containingRectForAllRooms() else {
            return
        }
        let mapCenter = Point(x: dungeonSize.width / 2, y: dungeonSize.height / 2)
        let delta = mapCenter.diffOf(layoutRect.center)
        translateRoomsOnly(
            OrderedSet(layoutSegments.keys),
            by: Point(x: delta.x.rounded(), y: delta.y.rounded())
        )
    }
    
}
