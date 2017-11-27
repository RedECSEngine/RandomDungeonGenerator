//
//  Edge.swift
//  Graph
//
//  Created by Andrew McKnight on 5/8/16.
//

import Foundation

public struct Edge<T, D>: Equatable where T: Hashable {

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

extension Edge: Hashable {

  public var hashValue: Int {
    let string = "\(from.description)\(to.description)\(weight)"
    return string.hashValue
  }
}

public func == <T, D>(lhs: Edge<T, D>, rhs: Edge<T, D>) -> Bool {
  guard lhs.from == rhs.from else {
    return false
  }

  guard lhs.to == rhs.to else {
    return false
  }

  guard lhs.weight == rhs.weight else {
    return false
  }

  return true
}
