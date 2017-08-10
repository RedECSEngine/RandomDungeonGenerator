import Foundation

public struct Size {

    public var width: Double
    public var height: Double
}

extension Size: CustomStringConvertible {
    
    public var description: String {
        return "W:\(width),H:\(height)"
    }
}

extension Size: Equatable {  }

public func == (_ lhs: Size, _ rhs: Size) -> Bool {
    return lhs.width == rhs.width && lhs.height == rhs.height
}

extension Size: Hashable {
    
    public var hashValue: Int {
        return description.hashValue
    }
    
}
