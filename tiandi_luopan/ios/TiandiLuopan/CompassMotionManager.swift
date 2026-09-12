import Foundation
import CoreLocation
import CoreMotion

protocol CompassMotionManagerDelegate: AnyObject {
    func didUpdateHeading(magneticHeading: Double, trueHeading: Double, accuracy: Double)
    func didUpdateTilt(pitch: Double, roll: Double)
    func didUpdateLocation(latitude: Double, longitude: Double, altitude: Double, speedKmH: Double, accuracy: Double)
    func didUpdateMagneticField(isDistorted: Bool, strengthUT: Double)
    func didChangeAccuracy(accuracy: Int)
}

final class CompassMotionManager: NSObject, CLLocationManagerDelegate {
    static let shared = CompassMotionManager()
    
    weak var delegate: CompassMotionManagerDelegate?
    
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()
    
    private(set) var currentHeading: Double = 0.0
    private(set) var currentTrueHeading: Double = 0.0
    private(set) var currentDeclination: Double = 0.0
    private(set) var hasDeclination: Bool = false
    
    private(set) var currentPitch: Double = 0.0
    private(set) var currentRoll: Double = 0.0
    
    private(set) var currentLatitude: Double = 0.0
    private(set) var currentLongitude: Double = 0.0
    private(set) var currentAltitude: Double = 0.0
    private(set) var currentSpeedKmH: Double = 0.0
    private(set) var hasAltitude: Bool = false
    
    private var lastHeadingTime: TimeInterval = 0
    private var lastTiltTime: TimeInterval = 0
    
    override private init() {
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
    
    func start() {
        // 请求权限并启动定位与方向
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
    
    func stop() {
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
        motionManager.stopDeviceMotionUpdates()
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func refreshLocation() {
        locationManager.startUpdatingLocation()
    }
    
    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60 FPS 刷新
        
        let referenceFrame: CMAttitudeReferenceFrame
        if CMMotionManager.availableAttitudeReferenceFrames().contains(.xMagneticNorthZVertical) {
            referenceFrame = .xMagneticNorthZVertical
        } else {
            referenceFrame = .xArbitraryZVertical
        }
        
        motionManager.startDeviceMotionUpdates(using: referenceFrame, to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            
            // 俯仰角 (Pitch) 与横滚角 (Roll) 转换至度数
            let pitchDeg = motion.attitude.pitch * 180.0 / .pi
            let rollDeg = motion.attitude.roll * 180.0 / .pi
            
            self.currentPitch = pitchDeg
            self.currentRoll = rollDeg
            
            // 60FPS 频率限制保护
            let now = CACurrentMediaTime()
            if now - self.lastTiltTime >= 0.033 { // ~30-60FPS
                self.lastTiltTime = now
                self.delegate?.didUpdateTilt(pitch: pitchDeg, roll: rollDeg)
            }
            
            // 磁场畸变监测 (微特斯拉 μT)
            let field = motion.magneticField.field
            let totalMag = sqrt(field.x * field.x + field.y * field.y + field.z * field.z)
            if totalMag > 0 {
                // 地球正常磁场强度约为 30~65 μT
                let isDistorted = totalMag < 20.0 || totalMag > 75.0
                self.delegate?.didUpdateMagneticField(isDistorted: isDistorted, strengthUT: totalMag)
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        
        currentHeading = newHeading.magneticHeading
        if newHeading.trueHeading >= 0 {
            currentTrueHeading = newHeading.trueHeading
            currentDeclination = newHeading.trueHeading - newHeading.magneticHeading
            hasDeclination = true
        }
        
        let now = CACurrentMediaTime()
        if now - lastHeadingTime >= 0.016 { // 60 FPS
            lastHeadingTime = now
            delegate?.didUpdateHeading(
                magneticHeading: newHeading.magneticHeading,
                trueHeading: newHeading.trueHeading,
                accuracy: newHeading.headingAccuracy
            )
        }
        
        // 精度等级映射 (0: 不可靠, 1: 低, 2: 中, 3: 高)
        let accLevel: Int
        if newHeading.headingAccuracy < 0 {
            accLevel = 0
        } else if newHeading.headingAccuracy > 25 {
            accLevel = 1
        } else if newHeading.headingAccuracy > 10 {
            accLevel = 2
        } else {
            accLevel = 3
        }
        delegate?.didChangeAccuracy(accuracy: accLevel)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        
        currentLatitude = loc.coordinate.latitude
        currentLongitude = loc.coordinate.longitude
        currentAltitude = loc.altitude
        hasAltitude = loc.verticalAccuracy >= 0
        
        // iOS 硬件多普勒直出航速 (m/s) -> 转换为 km/h
        if loc.speed >= 0 {
            currentSpeedKmH = loc.speed * 3.6
        } else {
            currentSpeedKmH = 0.0
        }
        
        delegate?.didUpdateLocation(
            latitude: loc.coordinate.latitude,
            longitude: loc.coordinate.longitude,
            altitude: loc.altitude,
            speedKmH: currentSpeedKmH,
            accuracy: loc.horizontalAccuracy
        )
    }
}
