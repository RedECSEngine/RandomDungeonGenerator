import Geometry
import OrderedCollections

extension DungeonGenerator {
      public func resolvedRects(forSegmentId segmentId: DungeonSegmentID) -> [Rect] {
          roomIds(connectedToAndIncluding: segmentId).compactMap { layoutSegments[$0]?.rect }
      }

      public func containingRectForAllRooms() -> Rect? {
          let rects = layoutSegments.values.map { $0.rect }
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
}
