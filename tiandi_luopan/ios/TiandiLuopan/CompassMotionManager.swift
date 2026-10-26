import Foundation
import CoreLocation
import CoreMotion
import Combine

public protocol CompassMotionManagerDelegate: AnyObject {
    func didUpdateHeading(magneticHeading: Double, trueHeading: Double, accuracy: Double)
    func didUpdateTilt(pitch: Double, roll: Double)
    func didUpdateLocation(latitude: Double, longitude: Double, altitude: Double, speedKmH: Double, accuracy: Double)
    func didUpdateMagneticField(isDistorted: Bool, strengthUT: Double)
    func didChangeAccuracy(accuracy: Int)
}

public final class CompassMotionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = CompassMotionManager()
    
    public weak var delegate: CompassMotionManagerDelegate?
    
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()
    
    // MARK: - SwiftUI 响应式状态流 (@Published)
    @Published public var heading: Double = 0.0          // 当前用于盘面旋转的角度
    @Published public var magneticHeading: Double = 0.0
    @Published public var trueHeading: Double = 0.0
    @Published public var currentDeclination: Double = 0.0
    @Published public var hasDeclination: Bool = false
    
    @Published public var pitch: Double = 0.0
    @Published public var roll: Double = 0.0
    @Published public var isLevel: Bool = true
    
    @Published public var latitude: Double = 39.9042
    @Published public var longitude: Double = 116.4074
    @Published public var altitude: Double = 45.0
    @Published public var speedKmH: Double = 0.0
    @Published public var coordsDesc: String = "39.90420°N, 116.40740°E · 海拔 45m"
    @Published public var trueSolarTimeStr: String = "12:00:00"
    
    @Published public var isDistorted: Bool = false
    @Published public var magneticStrengthUT: Double = 48.0
    @Published public var accuracyLevel: Int = 3 // 0..3
    
    // 手动触控拨盘与锁盘
    @Published public var isLocked: Bool = false
    @Published public var manualOffset: Double = 0.0
    
    @Published public var headingState: CompassHeadingState = Mountain24Data.shared.resolveHeadingState(heading: 0.0)
    
    private var lastHeadingTime: TimeInterval = 0
    private var lastTiltTime: TimeInterval = 0
    
    override public init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.headingFilter = kCLHeadingFilterNone
        locationManager.headingOrientation = .portrait
    }
    
    public func start() {
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
        
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
        
        startMotionUpdates()
    }
    
    public func stop() {
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
        motionManager.stopDeviceMotionUpdates()
    }
    
    public func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    public func refreshLocation() {
        locationManager.startUpdatingLocation()
    }
    
    public func toggleLock() {
        isLocked.toggle()
    }
    
    public func resetManualOffset() {
        manualOffset = 0.0
        updateResolvedState()
    }
    
    public func applyManualDragDelta(degrees: Double) {
        manualOffset = (manualOffset + degrees).truncatingRemainder(dividingBy: 360.0)
        updateResolvedState()
    }
    
    private func updateResolvedState() {
        let effective = (heading + manualOffset + 360.0).truncatingRemainder(dividingBy: 360.0)
        self.headingState = Mountain24Data.shared.resolveHeadingState(heading: effective, pitch: pitch, roll: roll)
        
        let solarResult = SolarTimeCalculator.shared.calculate(date: Date(), longitude: self.longitude)
        self.trueSolarTimeStr = solarResult.trueSolarTimeString
    }
    
    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60 FPS
        let referenceFrame: CMAttitudeReferenceFrame = CMMotionManager.availableAttitudeReferenceFrames().contains(.xMagneticNorthZVertical) ? .xMagneticNorthZVertical : .xArbitraryZVertical
        
        motionManager.startDeviceMotionUpdates(using: referenceFrame, to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            
            let pitchDeg = motion.attitude.pitch * 180.0 / .pi
            let rollDeg = motion.attitude.roll * 180.0 / .pi
            
            self.pitch = pitchDeg
            self.roll = rollDeg
            self.isLevel = abs(pitchDeg) < 2.5 && abs(rollDeg) < 2.5
            
            let now = CACurrentMediaTime()
            if now - self.lastTiltTime >= 0.033 {
                self.lastTiltTime = now
                self.delegate?.didUpdateTilt(pitch: pitchDeg, roll: rollDeg)
                self.updateResolvedState()
            }
            
            let field = motion.magneticField.field
            let totalMag = sqrt(field.x * field.x + field.y * field.y + field.z * field.z)
            if totalMag > 0 {
                self.magneticStrengthUT = totalMag
                self.isDistorted = totalMag < 20.0 || totalMag > 75.0
                self.delegate?.didUpdateMagneticField(isDistorted: self.isDistorted, strengthUT: totalMag)
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        
        let mag = newHeading.magneticHeading
        self.magneticHeading = mag
        
        if newHeading.trueHeading >= 0 {
            self.trueHeading = newHeading.trueHeading
            self.currentDeclination = newHeading.trueHeading - newHeading.magneticHeading
            self.hasDeclination = true
        }
        
        if !isLocked {
            self.heading = mag
            updateResolvedState()
        }
        
        let now = CACurrentMediaTime()
        if now - lastHeadingTime >= 0.016 {
            lastHeadingTime = now
            delegate?.didUpdateHeading(magneticHeading: newHeading.magneticHeading, trueHeading: newHeading.trueHeading, accuracy: newHeading.headingAccuracy)
        }
        
        let accLevel: Int
        if newHeading.headingAccuracy < 0 { accLevel = 0 }
        else if newHeading.headingAccuracy > 25 { accLevel = 1 }
        else if newHeading.headingAccuracy > 10 { accLevel = 2 }
        else { accLevel = 3 }
        self.accuracyLevel = accLevel
        delegate?.didChangeAccuracy(accuracy: accLevel)
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        
        self.latitude = loc.coordinate.latitude
        self.longitude = loc.coordinate.longitude
        self.altitude = loc.altitude
        
        let latStr = String(format: "%.5f°", abs(loc.coordinate.latitude)) + (loc.coordinate.latitude >= 0 ? "N" : "S")
        let lonStr = String(format: "%.5f°", abs(loc.coordinate.longitude)) + (loc.coordinate.longitude >= 0 ? "E" : "W")
        let altStr = String(format: " · 海拔 %.0fm", loc.altitude)
        self.coordsDesc = "\(latStr), \(lonStr)\(altStr)"
        
        if loc.speed >= 0 {
            self.speedKmH = loc.speed * 3.6
        } else {
            self.speedKmH = 0.0
        }
        
        updateResolvedState()
        
        delegate?.didUpdateLocation(
            latitude: loc.coordinate.latitude,
            longitude: loc.coordinate.longitude,
            altitude: loc.altitude,
            speedKmH: self.speedKmH,
            accuracy: loc.horizontalAccuracy
        )
    }
}
