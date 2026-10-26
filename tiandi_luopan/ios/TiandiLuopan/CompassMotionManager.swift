import Foundation
import CoreLocation
import CoreMotion
import Combine
import UIKit

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
    private let hapticTick = UIImpactFeedbackGenerator(style: .light)
    private let hapticLevel = UIImpactFeedbackGenerator(style: .medium)
    
    // MARK: - SwiftUI 响应式主线程状态流 (@Published)
    @Published public var heading: Double = 0.0          // 当前模 360 度数 (0 ~ 359.9°)
    @Published public var continuousHeading: Double = 0.0// 连续不跳变角度 (彻底解决 359°->0° 旋转倒转飞盘 Bug)
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
    @Published public var accuracyLevel: Int = 3
    
    // 手动触控拨盘与锁盘
    @Published public var isLocked: Bool = false
    @Published public var manualOffset: Double = 0.0
    
    @Published public var headingState: CompassHeadingState = Mountain24Data.shared.resolveHeadingState(heading: 0.0)
    
    private var lastRawHeading: Double = 0.0
    private var lastHeadingTime: TimeInterval = 0
    private var lastTiltTime: TimeInterval = 0
    private var lastMountainIndex: Int = -1
    private var wasLevel: Bool = false
    
    override public init() {
        super.init()
        setupLocationManager()
        hapticTick.prepare()
        hapticLevel.prepare()
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
        DispatchQueue.main.async {
            self.isLocked.toggle()
            self.hapticLevel.impactOccurred()
        }
    }
    
    public func resetManualOffset() {
        DispatchQueue.main.async {
            self.manualOffset = 0.0
            self.updateResolvedState()
            self.hapticLevel.impactOccurred()
        }
    }
    
    public func applyManualDragDelta(degrees: Double) {
        DispatchQueue.main.async {
            self.manualOffset = (self.manualOffset + degrees).truncatingRemainder(dividingBy: 360.0)
            self.updateResolvedState()
        }
    }
    
    // MARK: - 连续无跳跃角度平滑算法 (解决 359° 与 0° 之间的跳跃突变)
    private func updateContinuousHeading(newHeading: Double) {
        if lastRawHeading == 0.0 {
            lastRawHeading = newHeading
            continuousHeading = newHeading
            return
        }
        
        var diff = newHeading - lastRawHeading
        // 处理环形回绕
        if diff > 180.0 {
            diff -= 360.0
        } else if diff < -180.0 {
            diff += 360.0
        }
        
        lastRawHeading = newHeading
        continuousHeading += diff
    }
    
    private func updateResolvedState() {
        let effective = (heading + manualOffset + 360.0).truncatingRemainder(dividingBy: 360.0)
        let resolved = Mountain24Data.shared.resolveHeadingState(heading: effective, pitch: pitch, roll: roll)
        self.headingState = resolved
        
        // 跨越二十四山边界时触发微触觉反馈
        if resolved.facingMountain.id != lastMountainIndex {
            if lastMountainIndex != -1 {
                hapticTick.impactOccurred()
            }
            lastMountainIndex = resolved.facingMountain.id
        }
        
        // 当达到完全水平状态 (<1.5°) 时触发一次沉浸式对准震感
        if resolved.isLevel && !wasLevel {
            hapticLevel.impactOccurred()
        }
        wasLevel = resolved.isLevel
        
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
            
            DispatchQueue.main.async {
                self.pitch = pitchDeg
                self.roll = rollDeg
                self.isLevel = abs(pitchDeg) < 2.0 && abs(rollDeg) < 2.0
                
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
    }
    
    // MARK: - CLLocationManagerDelegate (确保主线程赋值)
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            let status = manager.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
                if CLLocationManager.headingAvailable() {
                    manager.startUpdatingHeading()
                }
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        
        let mag = newHeading.magneticHeading
        let now = CACurrentMediaTime()
        
        DispatchQueue.main.async {
            self.magneticHeading = mag
            
            if newHeading.trueHeading >= 0 {
                self.trueHeading = newHeading.trueHeading
                self.currentDeclination = newHeading.trueHeading - newHeading.magneticHeading
                self.hasDeclination = true
            }
            
            if !self.isLocked {
                self.heading = mag
                self.updateContinuousHeading(newHeading: mag)
                self.updateResolvedState()
            }
            
            if now - self.lastHeadingTime >= 0.016 {
                self.lastHeadingTime = now
                self.delegate?.didUpdateHeading(magneticHeading: newHeading.magneticHeading, trueHeading: newHeading.trueHeading, accuracy: newHeading.headingAccuracy)
            }
            
            let accLevel: Int
            if newHeading.headingAccuracy < 0 { accLevel = 0 }
            else if newHeading.headingAccuracy > 25 { accLevel = 1 }
            else if newHeading.headingAccuracy > 10 { accLevel = 2 }
            else { accLevel = 3 }
            self.accuracyLevel = accLevel
            self.delegate?.didChangeAccuracy(accuracy: accLevel)
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        
        DispatchQueue.main.async {
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
            
            self.updateResolvedState()
            
            self.delegate?.didUpdateLocation(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                altitude: loc.altitude,
                speedKmH: self.speedKmH,
                accuracy: loc.horizontalAccuracy
            )
        }
    }
}
