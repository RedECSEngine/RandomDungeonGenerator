
import SpriteKit
import GameplayKit

enum GenerationPhase {
    case fittingRooms
    case roundedFittingRooms
    case initialGraph
    case minimumGraph
    case hallways
}

class GameScene: SKScene {
    
    let dungeonCamera = SKCameraNode()
    var dungeonGenerator: RandomDungeonGenerator!
    
    private var lastUpdateTimeInterval: TimeInterval = 0
    private var phase: GenerationPhase = .fittingRooms
    private var timeInPhase: TimeInterval = 0
    private var maxTimePerPhase: TimeInterval = 1
    
    override func didMove(to view: SKView) {
        
        camera = dungeonCamera
        camera?.setScale(0.25)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        dungeonGenerator = RandomDungeonGenerator()
        dungeonGenerator.generateRooms()
        phase = .fittingRooms
    }
    
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        
        let delta: TimeInterval = currentTime - lastUpdateTimeInterval
        
        timeInPhase += delta
        
        guard delta > 0.016 else {
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
        
        addRooms()
        
        switch phase {
        
        case .fittingRooms:
            dungeonGenerator.applyFittingStep()
            if dungeonGenerator.containsNoIntersectingRooms() {
                phase = .roundedFittingRooms
                timeInPhase = 0
            }
        case .roundedFittingRooms:
            dungeonGenerator.applyFittingStep(rounded: true)
            if dungeonGenerator.containsNoIntersectingRooms() {
                phase = .initialGraph
                timeInPhase = 0
            }
        case .initialGraph:
            let graph = dungeonGenerator.generateGraph()
            addGraph(graph)
            if timeInPhase > maxTimePerPhase {
                phase = .minimumGraph
                timeInPhase = 0
            }
        case .minimumGraph:
            let graph = dungeonGenerator.generateMinimumEdges()
            addGraph(graph)
            if timeInPhase > maxTimePerPhase {
                phase = .hallways
                timeInPhase = 0
            }
        case .hallways:
            addHallways()
        }
    }
    
    func addRooms() {
        dungeonGenerator.rooms
        .forEach {
            room in
            
            let visualShape = SKShapeNode(rect: room.rect.cgRect)
            visualShape.fillColor = .blue
            visualShape.strokeColor = .white
            visualShape.isAntialiased = false
            visualShape.zPosition = 1
            addChild(visualShape)
            
            var containmentCircle = Circle(fittedTo: room.rect)
            containmentCircle.radius += (dungeonGenerator.maxRoomSpacing / 2)
            
            let containmentCircleShape = SKShapeNode(circleOfRadius: CGFloat(containmentCircle.radius))
            containmentCircleShape.position = room.rect.center.cgPoint
            containmentCircleShape.fillColor = .clear
            containmentCircleShape.strokeColor = .purple
            containmentCircleShape.isAntialiased = false
            containmentCircleShape.zPosition = 0
            addChild(containmentCircleShape)
        }
    }

    func addGraph(_ graph: AdjacencyListGraph<DungeonRoom>) {
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
                    visualShape.zPosition = 2
                    addChild(visualShape)
                })
        }
    }
    
    func addHallways() {
       dungeonGenerator.generateHallways()
        .forEach {
            hallwayPoints in
            
            let path = CGMutablePath()
            path.move(to: hallwayPoints.first!.cgPoint)
            hallwayPoints.dropFirst().forEach {
                point in
                path.addLine(to: point.cgPoint)
            }
            
            let visualShape = SKShapeNode(path: path)
            visualShape.fillColor = .clear
            visualShape.strokeColor = .orange
            visualShape.alpha = 0.5
            visualShape.isAntialiased = false
            visualShape.zPosition = 2
            addChild(visualShape)
            
        }
    }
    
}
