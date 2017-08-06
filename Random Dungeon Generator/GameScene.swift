
import SpriteKit
import GameplayKit

class GameScene: SKScene {
    
    let dungeonCamera = SKCameraNode()
    var dungeonGenerator: RandomDungeonGenerator!
    
    private var lastUpdateTimeInterval: TimeInterval = 0
    
    override func didMove(to view: SKView) {
        
        camera = dungeonCamera
        camera?.setScale(0.25)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        dungeonGenerator = RandomDungeonGenerator()
        dungeonGenerator.generateRooms()
    }
    
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        
        let delta: TimeInterval = currentTime - lastUpdateTimeInterval
        
        guard delta > 0.05 else {
            return
        }
        
        lastUpdateTimeInterval = currentTime
        
        removeAllChildren()
        
        guard dungeonGenerator != nil else {
            return
        }
        
        let boundaryRect = Rect(origin: Point(x:0.0, y: 0.0), size: dungeonGenerator.dungeonSize)
        camera?.position = boundaryRect.center.cgPoint
        
        let boundaryShape = SKShapeNode(rect: boundaryRect.cgRect)
        boundaryShape.fillColor = .clear
        boundaryShape.strokeColor = .green
        boundaryShape.isAntialiased = false
        addChild(boundaryShape)
        
        dungeonGenerator.rooms
        .forEach {
            room in
            
            let visualShape = SKShapeNode(rect: room.rect.cgRect)
            visualShape.fillColor = .blue
            visualShape.strokeColor = .white
            visualShape.isAntialiased = false
            addChild(visualShape)
            
            var containmentCircle = Circle(fittedTo: room.rect)
            containmentCircle.radius += dungeonGenerator.minimumRoomSpacing
            
            let containmentCircleShape = SKShapeNode(circleOfRadius: CGFloat(containmentCircle.radius))
            containmentCircleShape.position = room.rect.center.cgPoint
            containmentCircleShape.fillColor = .purple
            containmentCircleShape.strokeColor = .clear
            containmentCircleShape.isAntialiased = false
            containmentCircleShape.alpha = 0.3
            addChild(containmentCircleShape)
        }
        
        if false == dungeonGenerator.containsNoIntersectingRooms() {
            dungeonGenerator.applyFittingStep()
        } else {
            let graph = dungeonGenerator.generateGraph()
            graph.vertices
            .forEach {
                vertex in
                
                let edges = graph.edgesFrom(vertex)
                edges.forEach({
                    (edge) in
                    
                    let path = CGMutablePath()
                    path.move(to: edge.from.data.rect.center.cgPoint)
                    path.addLine(to: edge.to.data.rect.center.cgPoint)
                    
                    let visualShape = SKShapeNode(path: path)
                    visualShape.fillColor = .clear
                    visualShape.strokeColor = .green
                    visualShape.alpha = 0.5
                    visualShape.isAntialiased = false
                    addChild(visualShape)
                })
            }
        }
    }
    
}
