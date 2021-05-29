import Foundation

public struct Vertex<T>: Equatable where T: Hashable {
    public var data: T
    public let index: Int
}

extension Vertex: CustomStringConvertible {
    public var description: String {
        return "\(index): \(data)"
    }
}

extension Vertex: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
        hasher.combine(index)
    }
}

public func == <T>(lhs: Vertex<T>, rhs: Vertex<T>) -> Bool {
    guard lhs.index == rhs.index else {
        return false
    }

    guard lhs.data == rhs.data else {
        return false
    }

    return true
}
