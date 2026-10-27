import Foundation
import CoreLocation
import CoreMotion
import Combine
import UIKit
import QuartzCore

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
    @Published public var coordsDesc: String = "39.90420°N, 116.40740°E · 45m"
    @Published public var trueSolarTimeStr: String = "12:00:00"
    @Published public var solarTimeDesc: String = "12:00:00"
    
    @Published public var isDistorted: Bool = false
    @Published public var magneticStrengthUT: Double = 48.0
    @Published public var accuracyLevel: Int = 3
    
    // 手动触控拨盘与锁盘
    @Published public var isLocked: Bool = false
    @Published public var manualOffset: Double = 0.0
    @Published public var isHapticEnabled: Bool = true
    
    @Published public var headingState: CompassHeadingState = Mountain24Data.shared.resolveHeadingState(heading: 0.0)
    
    private var lastRawHeading: Double = 0.0
    private var lastHeadingTime: TimeInterval = 0
    private var lastTiltTime: TimeInterval = 0
    private var lastMountainIndex: Int = -1
    private var wasLevel: Bool = false
    private var isRunning: Bool = false
    private var lastSolarCalcTime: TimeInterval = 0
    private var lastResolvedHeading: Double = -999.0
    private var lastResolvedTime: TimeInterval = 0
    
    override public init() {
        super.init()
        setupLocationManager()
        hapticTick.prepare()
        hapticLevel.prepare()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        // 降低 GPS 天线高发热射频功耗：罗盘仅需十米/百米级经度计算太阳时，无需高耗能Best硬件
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 20.0
        locationManager.headingFilter = 0.3
        locationManager.headingOrientation = .portrait
    }
    
    public func start() {
        guard !isRunning else { return }
        isRunning = true

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
        guard isRunning else { return }
        isRunning = false
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
    
    // MARK: - 连续无跳跃角度平滑算法与自适应滤波 (彻底消除高频微抖与360°突变)
    private var smoothedHeading: Double = 0.0
    private var hasInitializedFilter: Bool = false
    
    private func updateContinuousHeading(newHeading: Double) {
        if !hasInitializedFilter {
            hasInitializedFilter = true
            lastRawHeading = newHeading
            smoothedHeading = newHeading
            continuousHeading = newHeading
            heading = newHeading
            return
        }
        
        var diff = newHeading - lastRawHeading
        // 处理环形 360 度回绕
        if diff > 180.0 {
            diff -= 360.0
        } else if diff < -180.0 {
            diff += 360.0
        }
        
        lastRawHeading = newHeading
        
        // 自适应非线性阻尼滤波 (Adaptive Deadband & EMA Filter):
        // 1. 微小手颤 ( < 0.2°): 极强阻尼抑制抖动，稳定视盘
        // 2. 中速转动 ( 0.2° ~ 2.0°): 适度平滑跟手
        // 3. 快速转动 ( > 2.0°): 快速响应无延迟
        let absDiff = abs(diff)
        let alpha: Double
        if absDiff < 0.12 {
            // 手部生理微颤死区直接滤除
            alpha = 0.04
        } else if absDiff < 0.5 {
            alpha = 0.15
        } else if absDiff < 2.0 {
            alpha = 0.35
        } else {
            alpha = 0.75
        }
        
        continuousHeading += diff * alpha
        let normalized = (continuousHeading.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        heading = normalized
    }
    
    private func updateResolvedState(force: Bool = false) {
        let now = CACurrentMediaTime()
        let effective = (heading + manualOffset + 360.0).truncatingRemainder(dividingBy: 360.0)
        
        // 节流 headingState 广播：防止一秒数十次全量 TabView 深度重绘风暴引发手机发烫
        let angleDelta = abs(effective - lastResolvedHeading)
        if force || angleDelta >= 0.25 || (now - lastResolvedTime >= 0.1) {
            lastResolvedHeading = effective
            lastResolvedTime = now
            let resolved = Mountain24Data.shared.resolveHeadingState(heading: effective, pitch: pitch, roll: roll)
            self.headingState = resolved
            
            // 跨越二十四山边界时触发微触觉反馈
            if resolved.facingMountain.id != lastMountainIndex {
                if lastMountainIndex != -1 && isHapticEnabled {
                    hapticTick.impactOccurred()
                }
                lastMountainIndex = resolved.facingMountain.id
            }
            
            // 当达到完全水平状态 (<1.5°) 时触发一次沉浸式对准震感
            if resolved.isLevel && !wasLevel && isHapticEnabled {
                hapticLevel.impactOccurred()
            }
            wasLevel = resolved.isLevel
        }
        
        // 节流真太阳时历法计算：真太阳时以秒为单位，每 1.0 秒最多计算一次球面三角，大幅减低 CPU 负荷
        if force || (now - lastSolarCalcTime >= 1.0) {
            lastSolarCalcTime = now
            let solarResult = SolarTimeCalculator.shared.calculate(date: Date(), longitude: self.longitude)
            self.trueSolarTimeStr = solarResult.trueSolarTimeString
            let offsetSign = solarResult.timeOffsetMinutes >= 0 ? "+" : ""
            let eqLabel = LocalizationManager.shared.t("solar_eq_time")
            let minUnit = LocalizationManager.shared.t("minute_unit")
            self.solarTimeDesc = "\(solarResult.baziGanzhi) (\(eqLabel) \(offsetSign)\(String(format: "%.1f", solarResult.timeOffsetMinutes))\(minUnit))"
        }
    }
    
    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        // 调整采样频率为 30Hz (平滑且大幅降低主线程压力与设备功耗)
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        let referenceFrame: CMAttitudeReferenceFrame = CMMotionManager.availableAttitudeReferenceFrames().contains(.xMagneticNorthZVertical) ? .xMagneticNorthZVertical : .xArbitraryZVertical
        
        motionManager.startDeviceMotionUpdates(using: referenceFrame, to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            
            let pitchDeg = motion.attitude.pitch * 180.0 / .pi
            let rollDeg = motion.attitude.roll * 180.0 / .pi
            
            DispatchQueue.main.async {
                // 水准仪倾角应用低通平滑，消除水平气泡剧烈颤动
                self.pitch = self.pitch * 0.82 + pitchDeg * 0.18
                self.roll = self.roll * 0.82 + rollDeg * 0.18
                self.isLevel = abs(self.pitch) < 2.0 && abs(self.roll) < 2.0
                
                let now = CACurrentMediaTime()
                if now - self.lastTiltTime >= 0.08 {
                    self.lastTiltTime = now
                    self.delegate?.didUpdateTilt(pitch: self.pitch, roll: self.roll)
                    if self.isLocked {
                        self.updateResolvedState()
                    }
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
            guard self.isRunning else { return }
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
                self.updateContinuousHeading(newHeading: mag)
                self.updateResolvedState()
            }
            
            if now - self.lastHeadingTime >= 0.033 {
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
            
            let isEn = LocalizationManager.shared.effectiveLanguage == .en
            let latLabel = loc.coordinate.latitude >= 0 ? LocalizationManager.shared.t("lat_north") : LocalizationManager.shared.t("lat_south")
            let lonLabel = loc.coordinate.longitude >= 0 ? LocalizationManager.shared.t("lon_east") : LocalizationManager.shared.t("lon_west")
            let altUnit = LocalizationManager.shared.t("altitude_unit")
            
            let latStr = isEn ? "\(String(format: "%.5f°", abs(loc.coordinate.latitude)))\(latLabel)" : "\(latLabel) \(String(format: "%.5f°", abs(loc.coordinate.latitude)))"
            let lonStr = isEn ? "\(String(format: "%.5f°", abs(loc.coordinate.longitude)))\(lonLabel)" : "\(lonLabel) \(String(format: "%.5f°", abs(loc.coordinate.longitude)))"
            let altStr = " · " + LocalizationManager.shared.t("altitude_label") + " " + String(format: "%.0f\(altUnit)", loc.altitude)
            self.coordsDesc = "\(latStr), \(lonStr)\(altStr)"
            
            if loc.speed >= 0 {
                self.speedKmH = loc.speed * 3.6
            } else {
                self.speedKmH = 0.0
            }
            
            self.updateResolvedState(force: true)
            
            self.delegate?.didUpdateLocation(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                altitude: loc.altitude,
                speedKmH: self.speedKmH,
                accuracy: loc.horizontalAccuracy
            )
            
            // 获得有效定位后及时挂起 GPS，切断手机真机高功耗持续发热源
            if loc.horizontalAccuracy > 0 && loc.horizontalAccuracy < 100 {
                self.locationManager.stopUpdatingLocation()
            }
        }
    }
}
