import Foundation

public struct Vertex<
    T: Equatable & Hashable & Codable
>: Equatable, Hashable, Codable {
    public var data: T
    public let index: Int
}

extension Vertex: CustomStringConvertible {
    public var description: String {
        return "\(index): \(data)"
    }
}
