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
    
    @Published public var latitude: Double = 0.0
    @Published public var longitude: Double = 0.0
    @Published public var altitude: Double = 0.0
    @Published public var speedKmH: Double = 0.0
    @Published public var coordsDesc: String = ""
    @Published public private(set) var hasLocationFix: Bool = false
    @Published public private(set) var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var trueSolarTimeStr: String = "--:--:--"
    @Published public var solarTimeDesc: String = ""
    
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
    private var lastPublishedMotionTime: TimeInterval = 0
    private var lastPublishedMagneticTime: TimeInterval = 0
    private var filteredPitch: Double = 0.0
    private var filteredRoll: Double = 0.0
    private var lastMountainIndex: Int = -1
    private var wasLevel: Bool = false
    private var isRunning: Bool = false
    private var deviceMotionEnabled: Bool = true
    private var headingUpdatesEnabled: Bool = true
    private var lastSolarCalcTime: TimeInterval = 0
    private var lastResolvedHeading: Double = -999.0
    private var cancellables = Set<AnyCancellable>()
    
    override public init() {
        super.init()
        setupLocationManager()
        locationAuthorizationStatus = locationManager.authorizationStatus
        coordsDesc = LocalizationManager.shared.t("location_unavailable")
        solarTimeDesc = LocalizationManager.shared.t("location_unavailable")
        // Keep the placeholder location out of user-visible reports until an
        // actual Core Location fix has arrived.
        latitude = 0.0
        longitude = 0.0
        LocalizationManager.shared.$effectiveLanguage
            .sink { [weak self] _ in
                guard let self = self, !self.hasLocationFix else { return }
                self.coordsDesc = LocalizationManager.shared.t("location_unavailable")
                self.solarTimeDesc = LocalizationManager.shared.t("location_unavailable")
            }
            .store(in: &cancellables)
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

        if headingUpdatesEnabled && CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
        
        let status = locationManager.authorizationStatus
        locationAuthorizationStatus = status
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
        
        if deviceMotionEnabled {
            startMotionUpdates()
        }
    }
    
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
        motionManager.stopDeviceMotionUpdates()
    }

    /// Core Location heading remains available to every analysis tab, while
    /// the higher-power attitude/magnetic stream is only needed by the live
    /// compass and calibration screens.
    public func setDeviceMotionEnabled(_ enabled: Bool) {
        guard deviceMotionEnabled != enabled else { return }
        deviceMotionEnabled = enabled
        guard isRunning else { return }
        if enabled {
            startMotionUpdates()
        } else {
            motionManager.stopDeviceMotionUpdates()
        }
    }

    /// Core Location heading is only needed by pages that render a live
    /// orientation. Settings can still show the last heading, magnetic field
    /// and location data without keeping the heading sensor active.
    public func setHeadingUpdatesEnabled(_ enabled: Bool) {
        guard headingUpdatesEnabled != enabled else { return }
        headingUpdatesEnabled = enabled
        guard isRunning else { return }
        if enabled && CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        } else {
            locationManager.stopUpdatingHeading()
        }
    }
    
    public func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Once the user has denied location access, iOS will not show the
    /// permission prompt again. Expose a direct settings action so the GPS
    /// dependent true-north and solar-time features can be recovered.
    public func openLocationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
    public func refreshLocation() {
        let status = locationManager.authorizationStatus
        locationAuthorizationStatus = status
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            locationManager.requestWhenInUseAuthorization()
            return
        }
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
            self.updateResolvedState(force: true)
            self.hapticLevel.impactOccurred()
        }
    }
    
    public func applyManualDragDelta(degrees: Double) {
        DispatchQueue.main.async {
            self.manualOffset = (self.manualOffset + degrees).truncatingRemainder(dividingBy: 360.0)
            self.updateResolvedState(force: true)
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
        // Headings are circular.  A transition such as 359.9° -> 0.1° is a
        // 0.2° movement and must not be treated as a 359.8° jump; otherwise
        // the throttled state update fires on every north crossing.
        let angleDelta: Double
        if lastResolvedHeading < 0 {
            angleDelta = .infinity
        } else {
            let rawAngleDelta = abs(effective - lastResolvedHeading)
            angleDelta = min(rawAngleDelta, 360.0 - rawAngleDelta)
        }
        if force || angleDelta >= 0.25 {
            lastResolvedHeading = effective
            let resolved = Mountain24Data.shared.resolveHeadingState(
                heading: effective,
                pitch: pitch,
                roll: roll,
                trueHeading: trueHeading
            )
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
        
        // 没有真实经度时不展示基于占位经度计算出的太阳时。
        guard hasLocationFix else {
            if trueSolarTimeStr != "--:--:--" {
                trueSolarTimeStr = "--:--:--"
            }
            let unavailable = LocalizationManager.shared.t("location_unavailable")
            if solarTimeDesc != unavailable {
                solarTimeDesc = unavailable
            }
            // Mark this refresh even without a GPS fix. Otherwise the motion
            // callback would call updateResolvedState on every sample because
            // the solar-time timestamp remained at zero.
            lastSolarCalcTime = now
            return
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
        
        // 20 Hz is sufficient for a handheld level bubble.  The filter below
        // still smooths every sample, while published SwiftUI state is limited
        // to 10 Hz so all tabs do not redraw on every sensor callback.
        motionManager.deviceMotionUpdateInterval = 1.0 / 20.0
        let referenceFrame: CMAttitudeReferenceFrame = CMMotionManager.availableAttitudeReferenceFrames().contains(.xMagneticNorthZVertical) ? .xMagneticNorthZVertical : .xArbitraryZVertical
        
        motionManager.startDeviceMotionUpdates(using: referenceFrame, to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            
            let pitchDeg = motion.attitude.pitch * 180.0 / .pi
            let rollDeg = motion.attitude.roll * 180.0 / .pi
            
            // The callback is already delivered on `.main`; processing it
            // inline avoids an extra async hop for every 20 Hz sample, which
            // otherwise adds latency and can queue stale samples while the UI
            // is busy.
            let now = CACurrentMediaTime()
            // Apply the low-pass filter to every sensor sample without
            // publishing each intermediate value to SwiftUI.
            self.filteredPitch = self.filteredPitch * 0.82 + pitchDeg * 0.18
            self.filteredRoll = self.filteredRoll * 0.82 + rollDeg * 0.18

            let shouldPublishTilt = now - self.lastPublishedMotionTime >= 0.1
            if shouldPublishTilt {
                self.lastPublishedMotionTime = now
                let nextPitch = self.filteredPitch
                let nextRoll = self.filteredRoll
                let nextIsLevel = abs(nextPitch) < 2.0 && abs(nextRoll) < 2.0
                let tiltChanged = abs(nextPitch - self.pitch) >= 0.05 ||
                    abs(nextRoll - self.roll) >= 0.05 ||
                    nextIsLevel != self.isLevel
                if tiltChanged {
                    self.pitch = nextPitch
                    self.roll = nextRoll
                    self.isLevel = nextIsLevel
                    self.delegate?.didUpdateTilt(pitch: self.pitch, roll: self.roll)
                    if self.isLocked {
                        self.updateResolvedState(force: true)
                    }
                }
            }

            let field = motion.magneticField.field
            let totalMag = sqrt(field.x * field.x + field.y * field.y + field.z * field.z)
            if totalMag > 0 {
                let distorted = totalMag < 20.0 || totalMag > 75.0
                let shouldPublishMagnetic = now - self.lastPublishedMagneticTime >= 0.2 || distorted != self.isDistorted
                if shouldPublishMagnetic {
                    self.lastPublishedMagneticTime = now
                    self.magneticStrengthUT = totalMag
                    self.isDistorted = distorted
                    self.delegate?.didUpdateMagneticField(isDistorted: distorted, strengthUT: totalMag)
                }
            }

            // Keep the clock/solar-term readout fresh without forcing a
            // new headingState publication when the device is stationary.
            if now - self.lastSolarCalcTime >= 1.0 {
                self.updateResolvedState()
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate (确保主线程赋值)
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            let status = manager.authorizationStatus
            self.locationAuthorizationStatus = status
            if status == .denied || status == .restricted {
                self.hasLocationFix = false
                self.hasDeclination = false
                self.currentDeclination = 0.0
                self.latitude = 0.0
                self.longitude = 0.0
                self.altitude = 0.0
                self.speedKmH = 0.0
                // Do not leave a previously calculated WMM correction on the
                // compass after access is revoked. Magnetic north remains a
                // valid local fallback until permission is granted again.
                self.trueHeading = self.magneticHeading
                self.coordsDesc = LocalizationManager.shared.t("location_unavailable")
                self.trueSolarTimeStr = "--:--:--"
                self.solarTimeDesc = LocalizationManager.shared.t("location_unavailable")
                self.updateResolvedState(force: true)
            }
            guard self.isRunning else { return }
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
                if self.headingUpdatesEnabled && CLLocationManager.headingAvailable() {
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
            if abs(mag - self.magneticHeading) >= 0.1 {
                self.magneticHeading = mag
            }
            
            // Core Location's trueHeading is useful as a first estimate, but its
            // value depends on the OS location cache. Once a WMM result exists,
            // keep the two needles driven by the same offline model everywhere.
            if newHeading.trueHeading >= 0 && !self.hasDeclination &&
                (self.locationAuthorizationStatus == .authorizedWhenInUse || self.locationAuthorizationStatus == .authorizedAlways) {
                self.trueHeading = newHeading.trueHeading
                var declination = newHeading.trueHeading - newHeading.magneticHeading
                if declination > 180.0 { declination -= 360.0 }
                if declination < -180.0 { declination += 360.0 }
                self.currentDeclination = declination
                self.hasDeclination = true
            }
            if self.hasDeclination {
                let resolvedTrueHeading = (mag + self.currentDeclination + 360.0)
                    .truncatingRemainder(dividingBy: 360.0)
                if abs(resolvedTrueHeading - self.trueHeading) >= 0.1 {
                    self.trueHeading = resolvedTrueHeading
                }
            }
            
            if !self.isLocked {
                self.updateContinuousHeading(newHeading: mag)
                self.updateResolvedState()
            }
            
            if now - self.lastHeadingTime >= 0.1 {
                self.lastHeadingTime = now
                self.delegate?.didUpdateHeading(magneticHeading: mag, trueHeading: self.trueHeading, accuracy: newHeading.headingAccuracy)
            }
            
            let accLevel: Int
            if newHeading.headingAccuracy < 0 { accLevel = 0 }
            else if newHeading.headingAccuracy > 25 { accLevel = 1 }
            else if newHeading.headingAccuracy > 10 { accLevel = 2 }
            else { accLevel = 3 }
            if self.accuracyLevel != accLevel {
                self.accuracyLevel = accLevel
                self.delegate?.didChangeAccuracy(accuracy: accLevel)
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        
        DispatchQueue.main.async {
            guard loc.coordinate.latitude.isFinite,
                  loc.coordinate.longitude.isFinite,
                  loc.horizontalAccuracy >= 0 else { return }
            self.locationAuthorizationStatus = manager.authorizationStatus
            self.hasLocationFix = true
            self.latitude = loc.coordinate.latitude
            self.longitude = loc.coordinate.longitude
            self.altitude = loc.altitude

            let wmm = WorldMagneticModel.shared.field(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                altitudeMeters: loc.altitude,
                date: Date()
            )
            self.currentDeclination = wmm.declination
            self.hasDeclination = true
            // East declination rotates a magnetic bearing clockwise toward true
            // north. Normalize to [0, 360) for consumers and the dial renderer.
            self.trueHeading = (self.magneticHeading + wmm.declination + 360.0)
                .truncatingRemainder(dividingBy: 360.0)
            
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
            
            // Keep location updates alive: speed and the live coordinate shown
            // by the compass must continue to refresh after the first fix.
        }
    }
}
