import Foundation

func minimumSpanningTreeKruskal<T>(graph: AdjacencyListGraph<T>) -> (cost: Double, tree: AdjacencyListGraph<T>) {
    
    var cost: Double = 0
    let tree = AdjacencyListGraph<T>(fromGraph: graph)
    tree.removeAllEdges()
    let sortedEdgeListByWeight = graph.edges.sorted(by: { $0.weight < $1.weight })
    
    var unionFind = UnionFind<Vertex<T>>()
    for vertex in graph.vertices {
        unionFind.addSetWith(vertex)
    }
    
    for edge in sortedEdgeListByWeight {
        let v1 = edge.from
        let v2 = edge.to
        if false == unionFind.inSameSet(v1, and: v2) {
            cost += edge.weight
            tree.addEdge(v1, to: v2, withWeight: edge.weight)
            unionFind.unionSetsContaining(v1, and: v2)
        }
    }
    
    return (cost: cost, tree: tree)
}
