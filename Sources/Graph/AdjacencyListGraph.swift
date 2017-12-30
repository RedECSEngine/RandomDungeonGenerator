import Foundation

public class EdgeList<T, D>: Codable where T: Hashable & Codable, D: Codable {
    
    enum CodingKeys: String, CodingKey {
        case vertex
        case edges
    }
    
    var vertex: Vertex<T>
    var edges: [Edge<T, D>]?
    
    init(vertex: Vertex<T>) {
        self.vertex = vertex
    }
    
    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        vertex = try values.decode(Vertex<T>.self, forKey: .vertex)
        let edges = try values.decode([Edge<T, D>].self, forKey: .edges)
        if edges.isEmpty == false {
            self.edges = edges
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(vertex, forKey: .vertex)
        let edgesArray = edges ?? []
        try container.encode(edgesArray, forKey: .edges)
    }
    
    func addEdge(_ edge: Edge<T, D>) {
        edges?.append(edge)
    }
}

open class AdjacencyListGraph<T, D>: CustomStringConvertible, Codable where T: Hashable & Codable, D: Codable {
    
    enum CodingKeys: String, CodingKey {
        case adjacencyList
    }
    
    internal var adjacencyList: [EdgeList<T, D>] = []
    
    open var vertices: [Vertex<T>] {
        var vertices = [Vertex<T>]()
        for edgeList in adjacencyList {
            vertices.append(edgeList.vertex)
        }
        return vertices
    }
    
    open var edges: [Edge<T, D>] {
        var allEdges = Set<Edge<T, D>>()
        for edgeList in adjacencyList {
            guard let edges = edgeList.edges else {
                continue
            }
            
            for edge in edges {
                allEdges.insert(edge)
            }
        }
        return Array(allEdges)
    }
    
    public required init() {}
    
    public required init(fromGraph graph: AdjacencyListGraph<T, D>) {
        for edge in graph.edges {
            let from = createVertex(edge.from.data)
            let to = createVertex(edge.to.data)
            
            addEdge(from, to: to, data: edge.data, withWeight: edge.weight)
        }
    }
    
    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        adjacencyList = try values.decode([EdgeList<T, D>].self, forKey: .adjacencyList)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(adjacencyList, forKey: .adjacencyList)
    }

    open func createVertex(_ data: T) -> Vertex<T> {
        // check if the vertex already exists
        let matchingVertices = vertices.filter { vertex in
            return vertex.data == data
        }
        
        if matchingVertices.count > 0 {
            return matchingVertices[0]
        }
        
        // if the vertex doesn't exist, create a new one
        let vertex = Vertex(data: data, index: adjacencyList.count)
        adjacencyList.append(EdgeList(vertex: vertex))
        return vertex
    }
    
    open func addEdge(_ from: Vertex<T>, to: Vertex<T>, data: D, withWeight weight: Double) {
        
        let edge = Edge(from: from, to: to, data: data, weight: weight)
        let edgeList = adjacencyList[from.index]
        if edgeList.edges != nil {
            edgeList.addEdge(edge)
        } else {
            edgeList.edges = [edge]
        }
    }
    
    open func removeEdge(_ edge: Edge<T, D>) {
        let list = adjacencyList[edge.from.index]
        if let edges = list.edges
            , let index = edges.index(of: edge) {
            adjacencyList[edge.from.index].edges?.remove(at: index)
        }
    }
    
    open func removeAllEdges() {
        for i in 0..<adjacencyList.count {
            adjacencyList[i].edges?.removeAll()
        }
    }
    
    open func weightFrom(_ sourceVertex: Vertex<T>, to destinationVertex: Vertex<T>) -> Double {
        guard let edges = adjacencyList[sourceVertex.index].edges else {
            return -1
        }
        
        for edge: Edge<T, D> in edges {
            if edge.to == destinationVertex {
                return edge.weight
            }
        }
        
        return -1
    }
    
    open func edgesFrom(_ sourceVertex: Vertex<T>) -> [Edge<T, D>] {
        return adjacencyList[sourceVertex.index].edges ?? []
    }
    
    open var description: String {
        var rows = [String]()
        for edgeList in adjacencyList {
            
            guard let edges = edgeList.edges else {
                continue
            }
            
            var row = [String]()
            for edge in edges {
                let value = "\(edge.to.data): \(edge.weight))"
                row.append(value)
            }
            
            rows.append("\(edgeList.vertex.data) -> [\(row.joined(separator: ", "))]")
        }
        
        return rows.joined(separator: "\n")
    }
}
