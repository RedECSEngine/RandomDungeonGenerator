
import XCTest
import Quick
import Nimble
import BWRandomDungeonGenerator

@testable import Random_Dungeon_Generator

class Random_Dungeon_GeneratorTests: QuickSpec {
    
    override func spec() {
        
        describe("Rect & Point tests with proofs of consistency with Core Graphics") {
            
            context("containment") {
            
                it("should not contain the point") {
                
                    let rect1 = Rect(x: 0, y: 0, width: 4, height: 4)
                    let point1 = Point(x:4, y: 4)
                    let point2 = Point(x: 5, y: 5)
                    let point3 = Point(x: 4, y: 0)
                    let point4 = Point(x: 0, y: 4)
                    
                    expect(rect1.contains(point1)) == false
                    expect(rect1.contains(point2)) == false
                    expect(rect1.contains(point3)) == false
                    expect(rect1.contains(point4)) == false
                
                    expect(rect1.cgRect.contains(point1.cgPoint)) == false
                    expect(rect1.cgRect.contains(point2.cgPoint)) == false
                    expect(rect1.cgRect.contains(point3.cgPoint)) == false
                    expect(rect1.cgRect.contains(point4.cgPoint)) == false
                }
                
                it("should contain the point") {
                
                    let rect1 = Rect(x: 0, y: 0, width: 4, height: 4)
                    let point1 = Point(x: 0, y: 0)
                    let point2 = Point(x: 1, y: 0)
                    let point3 = Point(x: 0, y: 1)
                    
                    expect(rect1.contains(point1)) == true
                    expect(rect1.contains(point2)) == true
                    expect(rect1.contains(point3)) == true
                    
                    expect(rect1.cgRect.contains(point1.cgPoint)) == true
                    expect(rect1.cgRect.contains(point2.cgPoint)) == true
                    expect(rect1.cgRect.contains(point3.cgPoint)) == true
                }
            }
            
            context("intersection") {
                
                it("should not evaluate the rects as intersecting") {
                    
                    let rect1 = Rect(x: 0, y: 0, width: 4, height: 4)
                    let rect2 = Rect(x: 5, y: 5, width: 4, height: 4)
                    let rect3 = Rect(x: -2, y: -2, width: 4, height: 2)
                    let rect4 = Rect(x: -2, y: 0, width: 2, height: 2)
                    let rect5 = Rect(x: 4, y: 0, width: 4, height: 4)
                    
                    expect(rect1.intersects(rect2)) == false
                    expect(rect1.intersects(rect3)) == false
                    expect(rect1.intersects(rect4)) == false
                    expect(rect1.intersects(rect5)) == false
                    
                    expect(rect1.cgRect.intersects(rect2.cgRect)) == false
                    expect(rect1.cgRect.intersects(rect3.cgRect)) == false
                    expect(rect1.cgRect.intersects(rect5.cgRect)) == false
                }
                
                
                it("should evaluate the rects as intersecting") {
                    
                    let rect1 = Rect(x: 0, y: 0, width: 4, height: 4)
                    let rect2 = Rect(x: 1, y: 1, width: 4, height: 4)
                    let rect3 = Rect(x: 3, y: 2, width: 4, height: 2)
                    let rect4 = Rect(x: 1, y: 1, width: 1, height: 1)
                    
                    expect(rect1.intersects(rect2)) == true
                    expect(rect1.intersects(rect3)) == true
                    expect(rect1.intersects(rect4)) == true
                    
                    expect(rect1.cgRect.intersects(rect2.cgRect)) == true
                    expect(rect1.cgRect.intersects(rect3.cgRect)) == true
                    expect(rect1.cgRect.intersects(rect4.cgRect)) == true
                }
            }
            
        }
        
    }
    
    
}
