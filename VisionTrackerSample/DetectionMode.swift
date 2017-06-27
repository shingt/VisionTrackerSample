import Foundation

enum DetectionMode {
    case rectangles
    case faces
}

extension DetectionMode: CustomStringConvertible {
    var description: String {
        switch self {
        case .rectangles: return "rectangles"
        case .faces: return "faces"
        }
    }
}
