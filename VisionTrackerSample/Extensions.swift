import UIKit

extension CAShapeLayer {
    static func circle(radius: CGFloat) -> CAShapeLayer {
        let layer = CAShapeLayer()
        let rect = CGRect(x: 0, y: 0, width: 2.0 * radius, height: 2.0 * radius)
        layer.path = UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath
        return layer
    }
}

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: (minX + maxX) / 2.0, y: (minY + maxY) / 2.0)
    }
}

extension UIColor {
    static func random(alpha: CGFloat) -> UIColor {
        let hue = CGFloat(arc4random() % 256) / 256
        let saturation = CGFloat(arc4random() % 128) / 256 + 0.5
        let brightness = CGFloat(arc4random() % 128) / 256 + 0.5
        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    }
}

