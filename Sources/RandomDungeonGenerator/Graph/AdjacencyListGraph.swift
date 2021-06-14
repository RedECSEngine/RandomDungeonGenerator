import Foundation

public struct EdgeList<
    T: Equatable & Hashable & Codable,
    D: Equatable & Hashable & Codable
>: Equatable & Hashable & Codable {
    public var vertex: Vertex<T>
    public var edges: [Edge<T, D>]?

    public init(vertex: Vertex<T>) {
        self.vertex = vertex
    }

    public mutating func addEdge(_ edge: Edge<T, D>) {
        edges?.append(edge)
    }
}

public struct AdjacencyListGraph<
    T: Equatable & Hashable & Codable,
    D: Equatable & Hashable & Codable
>: Equatable & Hashable & Codable {
    public var adjacencyList: [EdgeList<T, D>] = []

    public init() {}

    public init(fromGraph graph: AdjacencyListGraph<T, D>) {
        for edge in graph.edges {
            let from = createVertex(edge.from.data)
            let to = createVertex(edge.to.data)

            addEdge(from, to: to, data: edge.data, withWeight: edge.weight)
        }
    }

    public var vertices: [Vertex<T>] {
        var vertices = [Vertex<T>]()
        for edgeList in adjacencyList {
            vertices.append(edgeList.vertex)
        }
        return vertices
    }

    public var edges: [Edge<T, D>] {
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

    public mutating func createVertex(_ data: T) -> Vertex<T> {
        // check if the vertex already exists
        let matchingVertices = vertices.filter { vertex in
            vertex.data == data
        }

        if matchingVertices.count > 0 {
            return matchingVertices[0]
        }

        // if the vertex doesn't exist, create a new one
        let vertex = Vertex(data: data, index: adjacencyList.count)
        adjacencyList.append(EdgeList(vertex: vertex))
        return vertex
    }

    public mutating func addEdge(_ from: Vertex<T>, to: Vertex<T>, data: D, withWeight weight: Double) {
        let edge = Edge(from: from, to: to, data: data, weight: weight)
        var edgeList = adjacencyList[from.index]
        if edgeList.edges != nil {
            edgeList.addEdge(edge)
        } else {
            edgeList.edges = [edge]
        }
        adjacencyList[from.index] = edgeList
    }

    public mutating func removeEdge(_ edge: Edge<T, D>) {
        let list = adjacencyList[edge.from.index]
        if let edges = list.edges,
           let index = edges.firstIndex(of: edge)
        {
            adjacencyList[edge.from.index].edges?.remove(at: index)
        }
    }

    public mutating func removeAllEdges() {
        for i in 0 ..< adjacencyList.count {
            adjacencyList[i].edges?.removeAll()
        }
    }

    public func weightFrom(_ sourceVertex: Vertex<T>, to destinationVertex: Vertex<T>) -> Double {
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

    public func edgesFrom(_ sourceVertex: Vertex<T>) -> [Edge<T, D>] {
        adjacencyList[sourceVertex.index].edges ?? []
    }

    public var description: String {
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
