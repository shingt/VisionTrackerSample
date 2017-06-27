import UIKit
import Vision

struct ObservationArea {
    let uuid: UUID
    let bounds: CGRect
}

struct TrackedLayer {
    let layer: CAShapeLayer
    let observationArea: ObservationArea
}

final class LayersView: UIView {
    private var drawnTrackedLayers = [TrackedLayer]()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(with areas: [ObservationArea]) {
        let drawnAreas = drawnTrackedLayers.map { $0.observationArea }
        let drawnUuids: Set<UUID> = Set(drawnAreas.map { $0.uuid })
        let newUuids: Set<UUID> = Set(areas.map { $0.uuid })
        
        let uuidsToBeAdded: Set<UUID> = newUuids.subtracting(drawnUuids)
        let uuidsToBeMoved: Set<UUID> = drawnUuids.intersection(newUuids)
        
        let areasToBeAdded: [ObservationArea] = uuidsToBeAdded.flatMap { uuid in
            areas.first { $0.uuid == uuid }
        }
        let areasToBeMoved: [ObservationArea] = uuidsToBeMoved.flatMap { uuid in
            areas.first { $0.uuid == uuid }
        }
        
        drawCircles(of: areasToBeAdded)
        moveCircles(of: areasToBeMoved)
    }
    
    func reset() {
        drawnTrackedLayers.forEach { $0.layer.removeFromSuperlayer() }
    }
}

private extension LayersView {
    func moveCircles(of areas: [ObservationArea]) {
        areas.forEach { moveCircle(of: $0) }
    }
    
    func moveCircle(of area: ObservationArea) {
        guard let drawnLayerIndex = (drawnTrackedLayers.index { $0.observationArea.uuid == area.uuid }) else {
            return
        }
        let drawnLayer = drawnTrackedLayers[drawnLayerIndex]
        let fromCentroid = drawnLayer.layer.position
        let toCentroid = area.bounds.center
        let moveAnimation = CABasicAnimation(keyPath: "position")
        moveAnimation.fromValue = NSValue(cgPoint: fromCentroid)
        moveAnimation.toValue = NSValue(cgPoint: toCentroid)
        moveAnimation.duration = 0.3
        moveAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        drawnLayer.layer.position = toCentroid
        drawnLayer.layer.add(moveAnimation, forKey: "position")
    }
    
    func drawCircles(of observations: [ObservationArea]) {
        observations.forEach { drawCircle(of: $0) }
    }
    
    func drawCircle(of area: ObservationArea) {
        let bounds = area.bounds
        let radius: CGFloat = (bounds.maxX - bounds.minX) / 2.0
        let circleLayer = CAShapeLayer.circle(radius: radius)
        circleLayer.frame = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
        circleLayer.position = bounds.center
        circleLayer.fillColor = UIColor.random(alpha: 0.5).cgColor
        layer.addSublayer(circleLayer)
        drawnTrackedLayers.append(TrackedLayer(layer: circleLayer, observationArea: area))
    }
}

