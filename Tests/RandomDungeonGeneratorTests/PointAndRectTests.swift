@testable import RandomDungeonGenerator
import XCTest
import UIKit

extension Point {
    var cgPoint: CGPoint {
        return CGPoint(x: x, y: y)
    }
}

extension Rect {
    var cgRect: CGRect {
        return CGRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
    }
}

final class PointAndRectTests: XCTestCase {
    func testShouldNotContainThePoint() {
        let rect1 = Rect(x: 0, y: 0, width: 4, height: 4)
        let point1 = Point(x:4, y: 4)
        let point2 = Point(x: 5, y: 5)
        let point3 = Point(x: 4, y: 0)
        let point4 = Point(x: 0, y: 4)
        
        XCTAssertEqual(rect1.contains(point1), false)
        XCTAssertEqual(rect1.contains(point2), false)
        XCTAssertEqual(rect1.contains(point3), false)
        XCTAssertEqual(rect1.contains(point4), false)
    
        XCTAssertEqual(rect1.cgRect.contains(point1.cgPoint), false)
        XCTAssertEqual(rect1.cgRect.contains(point2.cgPoint), false)
        XCTAssertEqual(rect1.cgRect.contains(point3.cgPoint), false)
        XCTAssertEqual(rect1.cgRect.contains(point4.cgPoint), false)
    }
    
    func testShouldContainThePoint() {
        let rect1 = Rect(x: 0, y: 0, width: 4, height: 4)
        let point1 = Point(x: 0, y: 0)
        let point2 = Point(x: 1, y: 0)
        let point3 = Point(x: 0, y: 1)
        
        XCTAssertEqual(rect1.contains(point1), true)
        XCTAssertEqual(rect1.contains(point2), true)
        XCTAssertEqual(rect1.contains(point3), true)
        
        XCTAssertEqual(rect1.cgRect.contains(point1.cgPoint), true)
        XCTAssertEqual(rect1.cgRect.contains(point2.cgPoint), true)
        XCTAssertEqual(rect1.cgRect.contains(point3.cgPoint), true)
    }
    
    func testShouldNotEvaluateRectsAsIntersecting() {
        let rect1 = Rect(x: 0, y: 0, width: 4, height: 4)
        let rect2 = Rect(x: 5, y: 5, width: 4, height: 4)
        let rect3 = Rect(x: -2, y: -2, width: 4, height: 2)
        let rect4 = Rect(x: -2, y: 0, width: 2, height: 2)
        let rect5 = Rect(x: 4, y: 0, width: 4, height: 4)
        
        XCTAssertEqual(rect1.intersects(rect2), false)
        XCTAssertEqual(rect1.intersects(rect3), false)
        XCTAssertEqual(rect1.intersects(rect4), false)
        XCTAssertEqual(rect1.intersects(rect5), false)
        
        XCTAssertEqual(rect1.cgRect.intersects(rect2.cgRect), false)
        XCTAssertEqual(rect1.cgRect.intersects(rect3.cgRect), false)
        XCTAssertEqual(rect1.cgRect.intersects(rect5.cgRect), false)
    }
    
    func testShouldEvaluateRectsAsIntersecting() {
        let rect1 = Rect(x: 0, y: 0, width: 4, height: 4)
        let rect2 = Rect(x: 1, y: 1, width: 4, height: 4)
        let rect3 = Rect(x: 3, y: 2, width: 4, height: 2)
        let rect4 = Rect(x: 1, y: 1, width: 1, height: 1)
        
        XCTAssertEqual(rect1.intersects(rect2), true)
        XCTAssertEqual(rect1.intersects(rect3), true)
        XCTAssertEqual(rect1.intersects(rect4), true)
        
        XCTAssertEqual(rect1.cgRect.intersects(rect2.cgRect), true)
        XCTAssertEqual(rect1.cgRect.intersects(rect3.cgRect), true)
        XCTAssertEqual(rect1.cgRect.intersects(rect4.cgRect), true)
    }
}


