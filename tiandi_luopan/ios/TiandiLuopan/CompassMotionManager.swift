import Foundation
import CoreLocation
import CoreMotion
import Combine
import UIKit
import QuartzCore
#if canImport(WidgetKit)
import WidgetKit
#endif

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
    /// 即使主罗盘已锁定家宅坐向（isLocked == true），仍持续输出传感器实时方位角，供 AR 实景环视镜头使用
    @Published public private(set) var liveSensorHeading: Double = 0.0
    @Published public private(set) var hasLiveSensorHeading: Bool = false
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
    private var lastPublishedTrueHeadingTime: TimeInterval = 0
    private var lastPublishedMagneticHeadingTime: TimeInterval = 0
    private var filteredPitch: Double = 0.0
    private var filteredRoll: Double = 0.0
    private var lastMountainIndex: Int = -1
    private var wasLevel: Bool = false
    private var isRunning: Bool = false
    private var tabDeviceMotionEnabled: Bool = true
    private var tabHeadingUpdatesEnabled: Bool = true
    private var calibrationOverrideActive: Bool = false
    private var deviceMotionEnabled: Bool = true
    private var headingUpdatesEnabled: Bool = true
    private var hasCoreLocationTrueHeading: Bool = false
    private var offlineDeclination: Double?
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
        // 恢复上次锁盘状态与坐向度数（跨会话持久化 + iCloud KV 恢复，并同步给小组件）
        let kv = NSUbiquitousKeyValueStore.default
        let savedLocked: Bool = {
            if UserDefaults.standard.object(forKey: "compass_is_locked") != nil {
                return UserDefaults.standard.bool(forKey: "compass_is_locked")
            }
            return kv.bool(forKey: "compass_is_locked")
        }()
        let hasSavedAngle = UserDefaults.standard.object(forKey: "compass_locked_facing_angle") != nil
            || kv.object(forKey: "compass_locked_facing_angle") != nil
        if savedLocked, hasSavedAngle {
            let savedFacing = UserDefaults.standard.object(forKey: "compass_locked_facing_angle") != nil
                ? UserDefaults.standard.double(forKey: "compass_locked_facing_angle")
                : kv.double(forKey: "compass_locked_facing_angle")
            let normalized = (savedFacing.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
            self.isLocked = true
            self.heading = normalized
            self.continuousHeading = normalized
            self.manualOffset = 0.0
            self.headingState = Mountain24Data.shared.resolveHeadingState(heading: normalized)
            Self.syncSittingMountainToWidget(isLocked: true, sittingMountainID: self.headingState.sittingMountain.id)
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
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.hasLocationFix {
                    self.updateCoordsDesc(latitude: self.latitude, longitude: self.longitude, altitude: self.altitude)
                } else {
                    self.coordsDesc = LocalizationManager.shared.t("location_unavailable")
                    self.solarTimeDesc = LocalizationManager.shared.t("location_unavailable")
                }
                self.updateResolvedState(force: true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTimeAndSolarTerm()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTimeAndSolarTerm()
            }
            .store(in: &cancellables)

        Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshTimeAndSolarTermIfNeeded()
            }
            .store(in: &cancellables)
        hapticTick.prepare()
        hapticLevel.prepare()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        // 罗盘仅需经纬度用于磁偏角、真太阳时与粗略速度，最近十米精度已绰绰
        // 有余；相比 kCLLocationAccuracyBest 可让 GPS 射频大幅降频、显著降低耗电。
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 10.0
        // kCLHeadingFilterNone 确保硬件级所有微小方位角变化均实时上报，消除阶梯跳变与迟滞
        locationManager.headingFilter = kCLHeadingFilterNone
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
        guard headingUpdatesEnabled || deviceMotionEnabled else {
            stop()
            return
        }
        guard !isRunning else {
            updateResolvedState(force: true)
            return
        }
        isRunning = true
        updateHeadingOrientation()

        if headingUpdatesEnabled && CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
        
        let status = locationManager.authorizationStatus
        locationAuthorizationStatus = status
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if (status == .authorizedWhenInUse || status == .authorizedAlways), headingUpdatesEnabled {
            // 位置仅被实时罗盘/AR 页消费（磁偏角、真太阳时、速度）。在不需要
            // 渲染方位的页面（如设置页）保持 GPS 关闭，避免无谓耗电。
            locationManager.startUpdatingLocation()
        }
        
        if deviceMotionEnabled {
            startMotionUpdates()
        }
        updateResolvedState(force: true)
    }
    
    /// 供 SceneDelegate 前台生命周期调用：仅当当前活跃标签页或校准弹窗允许传感器工作时才恢复运行
    public func resumeIfSensorsEnabled() {
        if headingUpdatesEnabled || deviceMotionEnabled {
            start()
        } else {
            stop()
        }
        refreshTimeAndSolarTerm()
    }

    /// 强制即时重算时间与二十四节气并刷新主盘面
    public func refreshTimeAndSolarTerm() {
        if Thread.isMainThread {
            let currentTermName = SolarTimeCalculator.shared.solarTermName(for: Date())
            if self.currentSolarTermName != currentTermName {
                self.currentSolarTermName = currentTermName
            }
            self.updateResolvedState(force: true)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.refreshTimeAndSolarTerm()
            }
        }
    }

    /// 低频定时心跳检测节气与真太阳时跨界
    public func refreshTimeAndSolarTermIfNeeded() {
        if Thread.isMainThread {
            let currentTermName = SolarTimeCalculator.shared.solarTermName(for: Date())
            if self.currentSolarTermName != currentTermName {
                self.currentSolarTermName = currentTermName
                self.updateResolvedState(force: true)
            } else if self.isRunning && self.hasLocationFix {
                self.updateResolvedState(force: true)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.refreshTimeAndSolarTermIfNeeded()
            }
        }
    }
    
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
        motionManager.stopDeviceMotionUpdates()
    }
    
    /// 校准指引弹窗（如在设置页打开）临时开启传感器，关闭后自动还原当前标签页的传感器策略
    public func setCalibrationOverrideActive(_ active: Bool) {
        guard calibrationOverrideActive != active else { return }
        calibrationOverrideActive = active
        applyEffectiveSensorConfig()
        if headingUpdatesEnabled || deviceMotionEnabled {
            start()
        } else {
            stop()
        }
    }

    /// Core Location heading remains available to every analysis tab, while
    /// the higher-power attitude/magnetic stream is only needed by the live
    /// compass and calibration screens.
    public func setDeviceMotionEnabled(_ enabled: Bool) {
        tabDeviceMotionEnabled = enabled
        applyEffectiveSensorConfig()
    }

    /// Core Location heading is only needed by pages that render a live
    /// orientation. Settings can still show the last heading, magnetic field
    /// and location data without keeping the heading sensor active.
    public func setHeadingUpdatesEnabled(_ enabled: Bool) {
        tabHeadingUpdatesEnabled = enabled
        applyEffectiveSensorConfig()
    }
    
    private func applyEffectiveSensorConfig() {
        let effectiveDeviceMotion = tabDeviceMotionEnabled || calibrationOverrideActive
        let effectiveHeading = tabHeadingUpdatesEnabled || calibrationOverrideActive
        
        if deviceMotionEnabled != effectiveDeviceMotion {
            deviceMotionEnabled = effectiveDeviceMotion
            if isRunning {
                if effectiveDeviceMotion {
                    startMotionUpdates()
                } else {
                    motionManager.stopDeviceMotionUpdates()
                }
            }
        }
        
        if headingUpdatesEnabled != effectiveHeading {
            headingUpdatesEnabled = effectiveHeading
            if isRunning {
                if effectiveHeading && CLLocationManager.headingAvailable() {
                    updateHeadingOrientation()
                    locationManager.startUpdatingHeading()
                    let locStatus = locationManager.authorizationStatus
                    if locStatus == .authorizedWhenInUse || locStatus == .authorizedAlways {
                        locationManager.startUpdatingLocation()
                    }
                } else {
                    locationManager.stopUpdatingHeading()
                    // 关闭方位渲染时一并停掉 GPS，回到罗盘页时会自动重启。
                    locationManager.stopUpdatingLocation()
                }
            }
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
        // 仅请求一次高精度定位而非开启持续 GPS 流；Core Location 在交付定位
        // （或超时）后会自动停止更新，避免手动刷新后 GPS 一直空转耗电。
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestLocation()
        } else {
            locationManager.startUpdatingLocation()
        }
    }
    
    public func toggleLock() {
        DispatchQueue.main.async {
            self.isLocked.toggle()
            if !self.isLocked {
                // 解锁恢复实时陀螺仪时清除手动选山产生的偏移，立即回到传感器实时方位
                self.manualOffset = 0.0
                let liveHeading = self.northReference == .trueNorth && self.hasDeclination ? self.trueHeading : self.magneticHeading
                if liveHeading > 0 || self.hasLocationFix {
                    self.heading = liveHeading
                    self.continuousHeading = liveHeading
                }
                self.updateResolvedState(force: true)
            }
            self.persistLockState()
            if self.isLocked {
                RetentionServiceManager.shared.recordMilestone(reason: "lock_compass")
            }
            self.hapticLevel.impactOccurred()
        }
    }

    /// 直接指定某一个二十四山作为「坐山」并自动锁定盘面（供理气页/罗盘页 24 山快捷选向使用）
    public func selectSittingMountain(_ mountain: Mountain24Item) {
        let facing = (mountain.centerAngle + 180.0).truncatingRemainder(dividingBy: 360.0)
        lockAtFacingAngle(facing)
    }

    /// 直接根据向首山选定并锁定
    public func selectFacingMountain(_ mountain: Mountain24Item) {
        lockAtFacingAngle(mountain.centerAngle)
    }

    /// 微调锁定角度 (如兼向/正向下卦测试)
    public func adjustLockedAngle(delta: Double) {
        DispatchQueue.main.async {
            let current = self.headingState.facingAngle
            self.lockAtFacingAngle(current + delta)
        }
    }

    /// 锁定到指定的向首角度（0 ~ 360°）并持久化到 UserDefaults 与 App Group 小组件
    public func lockAtFacingAngle(_ facingAngle: Double) {
        DispatchQueue.main.async {
            let normalized = (facingAngle.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
            self.isLocked = true
            self.heading = normalized
            self.continuousHeading = normalized
            self.continuousMagneticHeading = normalized
            self.manualOffset = 0.0
            self.lastResolvedHeading = -999.0
            self.updateResolvedState(force: true)
            self.persistLockState()
            RetentionServiceManager.shared.recordMilestone(reason: "select_mountain")
            self.hapticLevel.impactOccurred()
        }
    }

    private func persistLockState() {
        let effective = (heading + manualOffset + 360.0).truncatingRemainder(dividingBy: 360.0)
        UserDefaults.standard.set(isLocked, forKey: "compass_is_locked")
        NSUbiquitousKeyValueStore.default.set(isLocked, forKey: "compass_is_locked")
        if isLocked {
            UserDefaults.standard.set(effective, forKey: "compass_locked_facing_angle")
            NSUbiquitousKeyValueStore.default.set(effective, forKey: "compass_locked_facing_angle")
        }
        NSUbiquitousKeyValueStore.default.synchronize()
        Self.syncSittingMountainToWidget(isLocked: isLocked, sittingMountainID: headingState.sittingMountain.id)
    }

    private static func syncSittingMountainToWidget(isLocked: Bool, sittingMountainID: Int) {
        let shared = LocalizationManager.sharedDefaults
        UserDefaults.standard.set(isLocked, forKey: "compass_is_locked")
        shared?.set(isLocked, forKey: "compass_is_locked")
        if isLocked {
            UserDefaults.standard.set(sittingMountainID, forKey: "saved_sitting_mountain_id")
            shared?.set(sittingMountainID, forKey: "saved_sitting_mountain_id")
        } else {
            UserDefaults.standard.removeObject(forKey: "saved_sitting_mountain_id")
            shared?.removeObject(forKey: "saved_sitting_mountain_id")
        }
        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: "TiandiLuopanAlmanacWidget")
        }
        #endif
    }
    
    public func resetManualOffset() {
        DispatchQueue.main.async {
            self.manualOffset = 0.0
            self.updateResolvedState(force: true)
            self.persistLockState()
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
            self.persistLockState()
        }
    }
    
    public func applyManualDragDelta(degrees: Double) {
        DispatchQueue.main.async {
            self.manualOffset = (self.manualOffset + degrees).truncatingRemainder(dividingBy: 360.0)
            self.updateResolvedState(force: true)
            if self.isLocked {
                self.persistLockState()
            }
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
            lastPublishedTrueHeadingTime = CACurrentMediaTime()
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

        // 每样本仍更新内部滤波值以保证平滑，但仅按 0.05s 门限发布到 @Published，
        // 避免 20~30Hz 下整棵罗盘视图树每样本重建导致老设备掉帧。
        // 真北针与磁北针各用独立计时器，避免互相饿死。
        filteredContinuousHeading += delta * alpha
        let now = CACurrentMediaTime()
        guard now - lastPublishedTrueHeadingTime >= 0.05 else { return }
        lastPublishedTrueHeadingTime = now
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
            lastPublishedMagneticHeadingTime = CACurrentMediaTime()
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
        // 磁北针独立 0.05s 发布门限，与真北针互不干扰。
        filteredContinuousMagneticHeading += delta * alpha
        let now = CACurrentMediaTime()
        guard now - lastPublishedMagneticHeadingTime >= 0.05 else { return }
        lastPublishedMagneticHeadingTime = now
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
                self.offlineDeclination = nil
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
                // 同样仅在需要方位渲染时开启连续定位，避免在设置页授权后 GPS 空转。
                if self.headingUpdatesEnabled {
                    manager.startUpdatingLocation()
                }
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
            } else {
                self.hasCoreLocationTrueHeading = false
                // The system heading and the offline model have independent
                // validity. A missing system true heading does not invalidate
                // a WMM correction computed from a still-valid location fix.
                let correction = self.hasLocationFix ? self.offlineDeclination : nil
                self.hasDeclination = correction != nil
                self.currentDeclination = correction ?? 0.0
                self.trueHeading = (mag + (correction ?? 0.0) + 360.0)
                    .truncatingRemainder(dividingBy: 360.0)
            }
            
            let referenceHeading = self.northReference == .trueNorth && self.hasDeclination ? self.trueHeading : mag
            let normalizedLive = (referenceHeading.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
            if !self.hasLiveSensorHeading || abs(normalizedLive - self.liveSensorHeading) >= 0.15 {
                self.liveSensorHeading = normalizedLive
                self.hasLiveSensorHeading = true
            }
            if !self.isLocked {
                self.updateContinuousMagneticHeading(newHeading: mag)
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
    
    /// Required by `requestLocation()`: Core Location raises an exception when
    /// a one-shot request fails and the delegate cannot receive the error.
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let clError = error as? CLError
        // kCLErrorLocationUnknown 是瞬态错误（Core Location 会继续尝试），
        // kCLErrorHeadingFailure 是罗盘/航向问题而非 GPS 定位失败——两者都
        // 保留当前坐标，避免把正常的定位状态误标为失效。
        if clError?.code == .locationUnknown || clError?.code == .headingFailure { return }
        DispatchQueue.main.async {
            let status = manager.authorizationStatus
            self.locationAuthorizationStatus = status
            // 拒绝/受限/定位服务不可用/网络等任何非瞬态失败都视为失去定位，
            // 避免陈旧经纬度、磁偏角与太阳时继续参与术数计算。
            self.hasLocationFix = false
            self.offlineDeclination = nil
            self.hasDeclination = false
            self.hasCoreLocationTrueHeading = false
            self.currentDeclination = 0.0
            self.latitude = 0.0
            self.longitude = 0.0
            self.altitude = 0.0
            self.speedKmH = 0.0
            self.trueHeading = self.magneticHeading
            self.coordsDesc = LocalizationManager.shared.t("location_unavailable")
            self.trueSolarTimeStr = "--:--:--"
            self.solarTimeDesc = LocalizationManager.shared.t("location_unavailable")
            self.updateResolvedState(force: true)
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
            self.offlineDeclination = wmm.declination.isFinite ? wmm.declination : nil
            // Cache the fallback even while Core Location supplies true north.
            if !self.hasCoreLocationTrueHeading {
                self.currentDeclination = self.offlineDeclination ?? 0.0
                self.hasDeclination = self.offlineDeclination != nil
                self.trueHeading = (self.magneticHeading + self.currentDeclination + 360.0)
                    .truncatingRemainder(dividingBy: 360.0)
            }
            
            self.updateCoordsDesc(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                altitude: loc.altitude
            )
            
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

    private func updateCoordsDesc(latitude: Double, longitude: Double, altitude: Double) {
        let lang = LocalizationManager.shared.effectiveLanguage
        let suffixHemisphere: Bool
        switch lang {
        case .en, .id, .vi, .th:
            suffixHemisphere = true
        case .zhHans, .zhHant, .ja, .ko, .auto:
            suffixHemisphere = false
        }
        let latLabel = (latitude >= 0 ? LocalizationManager.shared.t("lat_north") : LocalizationManager.shared.t("lat_south"))
            .trimmingCharacters(in: .whitespaces)
        let lonLabel = (longitude >= 0 ? LocalizationManager.shared.t("lon_east") : LocalizationManager.shared.t("lon_west"))
            .trimmingCharacters(in: .whitespaces)
        let altUnit = LocalizationManager.shared.t("altitude_unit")
        let latDeg = String(format: "%.5f°", abs(latitude))
        let lonDeg = String(format: "%.5f°", abs(longitude))
        let latStr = suffixHemisphere ? "\(latDeg) \(latLabel)" : "\(latLabel) \(latDeg)"
        let lonStr = suffixHemisphere ? "\(lonDeg) \(lonLabel)" : "\(lonLabel) \(lonDeg)"
        let altStr = " · " + LocalizationManager.shared.t("altitude_label") + " " + String(format: "%.0f\(altUnit)", altitude)
        self.coordsDesc = "\(latStr), \(lonStr)\(altStr)"
    }
}
