//
//  Edge.swift
//  Graph
//
//  Created by Andrew McKnight on 5/8/16.
//

import Foundation

public struct Edge<
    T: Equatable & Hashable & Codable,
    D: Equatable & Hashable & Codable
>: Equatable & Hashable & Codable {
    public let from: Vertex<T>
    public let to: Vertex<T>

    public var data: D
    public let weight: Double
}

extension Edge: CustomStringConvertible {
    public var description: String {
        return "\(from.description) -(\(weight))-> \(to.description)"
    }
}
