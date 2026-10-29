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

public enum CompassNorthReference: String, CaseIterable, Identifiable {
    case trueNorth = "true_north"
    case magneticNorth = "magnetic_north"

    public var id: String { rawValue }
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
    @Published public var continuousHeading: Double = 0.0// 连续真北角度 (系统真北可用时与 iOS 指南针一致)
    @Published public var continuousMagneticHeading: Double = 0.0 // 连续地磁北角度
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
    @Published public private(set) var currentSolarTermName: String = ""
    
    @Published public var isDistorted: Bool = false
    @Published public var magneticStrengthUT: Double = 48.0
    @Published public var accuracyLevel: Int = 3
    
    // 手动触控拨盘与锁盘
    @Published public var isLocked: Bool = false
    @Published public var manualOffset: Double = 0.0
    @Published public var isHapticEnabled: Bool = true
    
    @Published public var headingState: CompassHeadingState = Mountain24Data.shared.resolveHeadingState(heading: 0.0)
    @Published public var northReference: CompassNorthReference = .trueNorth {
        didSet {
            UserDefaults.standard.set(northReference.rawValue, forKey: "compass_north_reference")
            hasInitializedFilter = false
            recentHeadingSamples.removeAll(keepingCapacity: true)
            updateResolvedState(force: true)
        }
    }
    
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
    private var hasCoreLocationTrueHeading: Bool = false
    private var lastSolarCalcTime: TimeInterval = 0
    private var solarCalculationInFlight: Bool = false
    private var solarCalculationGeneration: Int = 0
    private var lastResolvedHeading: Double = -999.0
    // Heading and attitude are sampled independently. Keep the last attitude
    // used to build `headingState` so a user can tilt the phone while keeping
    // it pointed in the same direction and still get an up-to-date level
    // state without rebuilding the state for every 30 Hz motion sample.
    private var lastResolvedPitch: Double = .nan
    private var lastResolvedRoll: Double = .nan
    private var cancellables = Set<AnyCancellable>()
    
    override public init() {
        super.init()
        if let saved = UserDefaults.standard.string(forKey: "compass_north_reference"),
           let reference = CompassNorthReference(rawValue: saved) {
            northReference = reference
        }
        setupLocationManager()
        locationAuthorizationStatus = locationManager.authorizationStatus
        coordsDesc = LocalizationManager.shared.t("location_unavailable")
        solarTimeDesc = LocalizationManager.shared.t("location_unavailable")
        // Keep the placeholder location out of user-visible reports until an
        // actual Core Location fix has arrived.
        latitude = 0.0
        longitude = 0.0
        currentSolarTermName = SolarTimeCalculator.shared.solarTermName(for: Date())
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
        // 采用最高精度位置与高灵敏传感器融合，确保罗盘与地理真北完全精准
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0
        // kCLHeadingFilterNone 确保硬件级所有微小方位角变化均实时上报，消除阶梯跳变与迟滞
        locationManager.headingFilter = kCLHeadingFilterNone
        locationManager.showsDeviceMovementDisplay = true
        updateHeadingOrientation()
    }

    /// Core Location reports a bearing relative to the orientation supplied
    /// here. The iPhone UI is portrait-only, but iPad also permits upside-down
    /// portrait; using a hard-coded portrait orientation there creates a full
    /// 180° error after the interface rotates.
    private func updateHeadingOrientation() {
        let targetOrientation: CLDeviceOrientation
        guard let interfaceOrientation = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .filter({ $0.activationState == .foregroundActive })
            .map({ $0.interfaceOrientation })
            .first,
              interfaceOrientation != .unknown else {
            targetOrientation = .portrait
            if locationManager.headingOrientation != targetOrientation {
                locationManager.headingOrientation = targetOrientation
            }
            return
        }

        switch interfaceOrientation {
        case .portrait:
            targetOrientation = .portrait
        case .portraitUpsideDown:
            targetOrientation = .portraitUpsideDown
        case .landscapeLeft:
            targetOrientation = .landscapeLeft
        case .landscapeRight:
            targetOrientation = .landscapeRight
        default:
            targetOrientation = .portrait
        }
        if locationManager.headingOrientation != targetOrientation {
            locationManager.headingOrientation = targetOrientation
        }
    }
    
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        updateHeadingOrientation()

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
            // The interface may have rotated while heading updates were
            // paused (for example after leaving Settings). Apply the current
            // scene orientation before the first resumed sample so the first
            // displayed bearing cannot be off by 90° or 180°.
            updateHeadingOrientation()
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

    /// Reset software heading filters before the user performs the iOS
    /// figure-eight calibration movement. Core Location owns the hardware
    /// calibration prompt; clearing the local history prevents pre-calibration
    /// samples from being blended into the first corrected readings.
    public func requestSensorCalibration() {
        DispatchQueue.main.async {
            self.manualOffset = 0.0
            self.hasInitializedFilter = false
            self.hasInitializedMagneticFilter = false
            self.recentHeadingSamples.removeAll(keepingCapacity: true)
            self.recentMagneticSamples.removeAll(keepingCapacity: true)
            self.lastResolvedHeading = -999.0
            self.lastResolvedPitch = .nan
            self.lastResolvedRoll = .nan
            self.updateHeadingOrientation()
            if self.isRunning && self.headingUpdatesEnabled && CLLocationManager.headingAvailable() {
                self.locationManager.startUpdatingHeading()
            }
            self.updateResolvedState(force: true)
        }
    }
    
    public func applyManualDragDelta(degrees: Double) {
        DispatchQueue.main.async {
            self.manualOffset = (self.manualOffset + degrees).truncatingRemainder(dividingBy: 360.0)
            self.updateResolvedState(force: true)
        }
    }
    
    // MARK: - 连续无跳跃角度平滑算法与自适应滤波 (彻底消除高频微抖与360°突变)
    private var filteredContinuousHeading: Double = 0.0
    private var hasInitializedFilter: Bool = false
    private var recentHeadingSamples: [Double] = []
    private var filteredContinuousMagneticHeading: Double = 0.0
    private var hasInitializedMagneticFilter: Bool = false
    private var recentMagneticSamples: [Double] = []

    private static func shortestAngleDelta(from: Double, to: Double) -> Double {
        var delta = to - from
        while delta > 180.0 { delta -= 360.0 }
        while delta < -180.0 { delta += 360.0 }
        return delta
    }
    
    private func updateContinuousHeading(newHeading: Double) {
        if !hasInitializedFilter {
            hasInitializedFilter = true
            filteredContinuousHeading = newHeading
            continuousHeading = newHeading
            heading = (newHeading.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
            return
        }
        
        let delta = Self.shortestAngleDelta(from: filteredContinuousHeading, to: newHeading)
        let absDelta = abs(delta)
        
        // 高性能自适应响应滤波：大动作零延迟即时跟从，微动精密平滑抗抖动，且无死区截断
        let alpha: Double
        if absDelta > 3.0 {
            alpha = 0.95
        } else if absDelta > 1.0 {
            alpha = 0.75
        } else if absDelta > 0.3 {
            alpha = 0.50
        } else {
            alpha = 0.35
        }
        
        filteredContinuousHeading += delta * alpha
        continuousHeading = filteredContinuousHeading
        let normalized = (filteredContinuousHeading.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        heading = normalized
    }

    /// Keep an independent smooth magnetic bearing for the red/blue magnetic needle.
    private func updateContinuousMagneticHeading(newHeading: Double) {
        if !hasInitializedMagneticFilter {
            hasInitializedMagneticFilter = true
            filteredContinuousMagneticHeading = newHeading
            continuousMagneticHeading = newHeading
            magneticHeading = (newHeading.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
            return
        }

        let delta = Self.shortestAngleDelta(from: filteredContinuousMagneticHeading, to: newHeading)
        let absDelta = abs(delta)
        let alpha: Double
        if absDelta > 3.0 {
            alpha = 0.95
        } else if absDelta > 1.0 {
            alpha = 0.75
        } else if absDelta > 0.3 {
            alpha = 0.50
        } else {
            alpha = 0.35
        }
        filteredContinuousMagneticHeading += delta * alpha
        continuousMagneticHeading = filteredContinuousMagneticHeading
        magneticHeading = (filteredContinuousMagneticHeading.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
    }
    
    private func updateResolvedState(force: Bool = false) {
        let now = CACurrentMediaTime()
        let currentTermName = SolarTimeCalculator.shared.solarTermName(for: Date())
        if currentSolarTermName != currentTermName {
            currentSolarTermName = currentTermName
        }
        let effective = (heading + manualOffset + 360.0).truncatingRemainder(dividingBy: 360.0)
        
        // 采用 0.01° 高灵敏度更新门限，确保微动时度数绝不卡死
        let angleDelta: Double
        if lastResolvedHeading < 0 {
            angleDelta = .infinity
        } else {
            let rawAngleDelta = abs(effective - lastResolvedHeading)
            angleDelta = min(rawAngleDelta, 360.0 - rawAngleDelta)
        }
        let pitchDelta = lastResolvedPitch.isFinite ? abs(pitch - lastResolvedPitch) : .infinity
        let rollDelta = lastResolvedRoll.isFinite ? abs(roll - lastResolvedRoll) : .infinity
        if force || angleDelta >= 0.01 || pitchDelta >= 0.05 || rollDelta >= 0.05 {
            lastResolvedHeading = effective
            lastResolvedPitch = pitch
            lastResolvedRoll = roll
            let resolved = Mountain24Data.shared.resolveHeadingState(
                heading: effective,
                pitch: pitch,
                roll: roll,
                trueHeading: northReference == .trueNorth && hasDeclination ? heading : nil
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
            solarCalculationGeneration += 1
            solarCalculationInFlight = false
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
        if (force || (now - lastSolarCalcTime >= 1.0)) && !solarCalculationInFlight {
            lastSolarCalcTime = now
            solarCalculationInFlight = true
            solarCalculationGeneration += 1
            let generation = solarCalculationGeneration
            let calculationDate = Date()
            let calculationLongitude = longitude
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let solarResult = SolarTimeCalculator.shared.calculate(
                    date: calculationDate,
                    longitude: calculationLongitude
                )
                DispatchQueue.main.async {
                    guard let self = self,
                          self.solarCalculationGeneration == generation else { return }
                    self.solarCalculationInFlight = false
                    guard self.hasLocationFix,
                          abs(self.longitude - calculationLongitude) < 0.0001 else { return }
                    self.trueSolarTimeStr = solarResult.trueSolarTimeString
                    let offsetSign = solarResult.timeOffsetMinutes >= 0 ? "+" : ""
                    let eqLabel = LocalizationManager.shared.t("solar_eq_time")
                    let minUnit = LocalizationManager.shared.t("minute_unit")
                    self.solarTimeDesc = "\(solarResult.baziGanzhi) (\(eqLabel) \(offsetSign)\(String(format: "%.1f", solarResult.timeOffsetMinutes))\(minUnit))"
                }
            }
        }
    }
    
    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        // A 30 Hz sample stream keeps the level bubble responsive while the
        // publication gate below still bounds SwiftUI redraws to 20 Hz.
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.showsDeviceMovementDisplay = true
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
            self.filteredPitch = self.filteredPitch * 0.68 + pitchDeg * 0.32
            self.filteredRoll = self.filteredRoll * 0.68 + rollDeg * 0.32

            let shouldPublishTilt = now - self.lastPublishedMotionTime >= 0.05
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
                self.hasCoreLocationTrueHeading = false
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
                    self.updateHeadingOrientation()
                    manager.startUpdatingHeading()
                }
            }
        }
    }

    public func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        // Let iOS present its native figure-eight calibration prompt when the
        // magnetometer reports that calibration is needed.
        return true
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        
        let mag = newHeading.magneticHeading
        let now = CACurrentMediaTime()
        
        DispatchQueue.main.async {
            self.updateHeadingOrientation()
            self.magneticHeading = mag
            
            // Core Location's trueHeading 是系统最高精度传感器融合计算的地理真北。
            // 当其有效时直接作为真北基准并校准磁偏角；当尚未获得时使用离线 WMM 模型补偿。
            if newHeading.trueHeading >= 0 {
                self.trueHeading = newHeading.trueHeading
                var declination = newHeading.trueHeading - newHeading.magneticHeading
                while declination > 180.0 { declination -= 360.0 }
                while declination < -180.0 { declination += 360.0 }
                self.currentDeclination = declination
                self.hasDeclination = true
                self.hasCoreLocationTrueHeading = true
            } else if self.hasDeclination {
                self.trueHeading = (mag + self.currentDeclination + 360.0)
                    .truncatingRemainder(dividingBy: 360.0)
            } else {
                self.trueHeading = mag
            }
            
            if !self.isLocked {
                self.updateContinuousMagneticHeading(newHeading: mag)
                let referenceHeading = self.northReference == .trueNorth && self.hasDeclination ? self.trueHeading : mag
                self.updateContinuousHeading(newHeading: referenceHeading)
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

            // Do not overwrite Core Location's calibrated declination with an
            // offline model when trueHeading is already available. WMM remains
            // the fallback for devices/locations where Core Location has not
            // produced a true heading yet.
            if !self.hasCoreLocationTrueHeading {
                let wmm = WorldMagneticModel.shared.field(
                    latitude: loc.coordinate.latitude,
                    longitude: loc.coordinate.longitude,
                    altitudeMeters: loc.altitude,
                    date: Date()
                )
                self.currentDeclination = wmm.declination
                self.hasDeclination = true
                self.trueHeading = (self.magneticHeading + self.currentDeclination + 360.0)
                    .truncatingRemainder(dividingBy: 360.0)
            }
            
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
