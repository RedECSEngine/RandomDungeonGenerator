
import SpriteKit
import GameplayKit
import BWRandomDungeonGenerator

enum GenerationPhase {
    case fittingRooms
    case roundedFittingRooms
    case initialGraph
    case minimumGraph
    case hallways
    case grid
}

class GameScene: SKScene {
    
    let dungeonCamera = SKCameraNode()
    var dungeonGenerator: DungeonGenerator<DefaultDungeonRoom, DefaultDungeonHallway>!
    
    private var lastUpdateTimeInterval: TimeInterval = 0
    private var phase: GenerationPhase = .fittingRooms
    private var timeInPhase: TimeInterval = 0
    private var maxTimePerPhase: TimeInterval = 1
    
    private var isGenerating = false
    
    override func didMove(to view: SKView) {
        
        camera = dungeonCamera
        camera?.setScale(0.25)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        isGenerating = true
        dungeonGenerator = DungeonGenerator()
        dungeonGenerator.generateRooms()
        phase = .fittingRooms
    }
    
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        
        guard isGenerating else {
            lastUpdateTimeInterval = currentTime
            return
        }
        
        let delta: TimeInterval = currentTime - lastUpdateTimeInterval
        
        timeInPhase += delta
        
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
        
        
        switch phase {
        
        case .fittingRooms:
            addRooms()
            dungeonGenerator.applyFittingStep()
            if dungeonGenerator.containsNoIntersectingRooms() {
                phase = .roundedFittingRooms
                timeInPhase = 0
            }
        case .roundedFittingRooms:
            addRooms()
            dungeonGenerator.roundRoomPositions()
            if dungeonGenerator.containsNoIntersectingRooms() {
                phase = .initialGraph
                timeInPhase = 0
            }
        case .initialGraph:
            addRooms()
            let graph = dungeonGenerator.generateGraph()
            addCircles()
            addGraph(graph)
            if timeInPhase > maxTimePerPhase {
                phase = .minimumGraph
                timeInPhase = 0
            }
        case .minimumGraph:
            addRooms()
            dungeonGenerator.generateDungeonGraph()
            addGraph(dungeonGenerator.dungeon)
            if timeInPhase > maxTimePerPhase {
                phase = .hallways
                timeInPhase = 0
            }
        case .hallways:
            addRooms()
            addHallways()
            if timeInPhase > 3 {
                phase = .grid
                timeInPhase = 0
            }
        case .grid:
           add2DGrid()
            isGenerating = false
        }
    }
    
    func addRooms() {
        dungeonGenerator.layoutRooms
        .forEach {
            room in
            
            let visualShape = SKShapeNode(rect: room.rect.cgRect)
            visualShape.fillColor = .blue
            visualShape.strokeColor = .white
            visualShape.isAntialiased = false
            visualShape.zPosition = 1
            addChild(visualShape)
        }
    }
    
    func addCircles() {
        dungeonGenerator.layoutRooms
        .forEach {
            room in
            
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

    func addGraph(_ graph: Dungeon<DefaultDungeonRoom, DefaultDungeonHallway>) {
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
        dungeonGenerator.dungeon.hallways.forEach {
            hallway in
            
            hallway.rects.forEach {
                (rect) in
                let visualShape = SKShapeNode(rect: rect.cgRect)
                visualShape.fillColor = .blue
                visualShape.strokeColor = .clear
                visualShape.lineWidth = 3
                visualShape.isAntialiased = false
                visualShape.zPosition = 2
                addChild(visualShape)
            }
            
        }
    }
    
    func add2DGrid() {
        let grid = dungeonGenerator.to2DGrid()
        grid.enumerated()
            .forEach {
                y, row in
                
                row.enumerated().forEach {
                    x, value in
                    
                    guard value == 1 else { return }
                    
                    let rect = CGRect(x: x, y: y, width: 1, height: 1)
                    let visualShape = SKShapeNode(rect: rect)
                    visualShape.fillColor = .blue
                    visualShape.strokeColor = .clear
                    visualShape.lineWidth = 3
                    visualShape.isAntialiased = false
                    visualShape.zPosition = 2
                    addChild(visualShape)
                }
        }
        
        //print(JSONSerialization.data(withJSONObject: grid, options: .prettyPrinted))
        print(grid)
    }
    
}
