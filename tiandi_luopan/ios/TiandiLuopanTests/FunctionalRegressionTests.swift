import XCTest
import UIKit
import Combine
import simd
import CryptoKit
import Security
@testable import TiandiLuopan

final class FunctionalRegressionTests: XCTestCase {
    private func instant(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    private func liChunBoundary() -> Date {
        var low = instant("2026-02-03T00:00:00Z")
        var high = instant("2026-02-05T00:00:00Z")
        while high.timeIntervalSince(low) > 0.001 {
            let middle = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
            if SolarTimeCalculator.shared.solarTermIndex(for: middle) < 2 { low = middle }
            else { high = middle }
        }
        return high
    }

    func testRectangularPlanBearingsAndDrawingUseTheSameScale() {
        let center = CGPoint(x: 0.5, y: 0.5)
        let point = CGPoint(x: 0.7, y: 0.3)
        let bounds = CGRect(x: 40, y: 20, width: 1000, height: 740)
        let ratios: [CGFloat] = [1.0 / 3.0, 1, 3]
        for ratio in ratios {
            let rect = GeometryUtils.aspectFitRect(aspectRatio: ratio, in: bounds)
            XCTAssertEqual(rect.width / rect.height, ratio, accuracy: 0.000001)
            let origin = CGPoint(x: rect.minX + center.x * rect.width, y: rect.minY + center.y * rect.height)
            let target = CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
            XCTAssertEqual(GeometryUtils.bearing(from: center, to: point, aspectRatio: ratio),
                           GeometryUtils.bearing(from: origin, to: target), accuracy: 0.000001)
        }
        XCTAssertEqual(GeometryUtils.bearing(from: center, to: point, aspectRatio: 3), 71.565051177, accuracy: 0.000001)
    }

    @MainActor
    func testRectangularPlanAssignsRoomToEastInsteadOfNortheast() {
        let language = LocalizationManager.shared.effectiveLanguage
        defer { LocalizationManager.shared.effectiveLanguage = language }
        LocalizationManager.shared.effectiveLanguage = .zhHans
        let room = FloorplanRoom(name: "书房", type: .study, rect: CGRect(x: 0.65, y: 0.25, width: 0.1, height: 0.1))
        let result = FloorplanEngine.shared.auditFloorplan(rooms: [room], centroid: CGPoint(x: 0.5, y: 0.5), heading: 0, aspectRatio: 3)
        XCTAssertTrue(result.auditedRooms[0].palaceName.contains("正东"))
    }

    func testSolarClockDoesNotIncludeNewYorkSummerTime() {
        let date = instant("2026-07-01T16:00:00Z") // 12:00 EDT
        let ny = SolarTimeCalculator.shared.calculate(date: date, longitude: -74.006,
                                                      timeZone: TimeZone(identifier: "America/New_York")!)
        let utc = SolarTimeCalculator.shared.calculate(date: date, longitude: -74.006,
                                                       timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertTrue(ny.trueSolarTimeString.hasPrefix("11:00:"))
        XCTAssertEqual(ny.trueSolarTimeString, utc.trueSolarTimeString)
        XCTAssertEqual(ny.dayPillar, utc.dayPillar)
        XCTAssertEqual(ny.timeOffsetMinutes - utc.timeOffsetMinutes, 240, accuracy: 0.000001)
    }

    func testSolarClockIsContinuousAcrossDaylightSavingTransition() {
        let zone = TimeZone(identifier: "America/New_York")!
        let before = SolarTimeCalculator.shared.calculate(date: instant("2026-03-08T06:59:59Z"), longitude: -74.006, timeZone: zone)
        let after = SolarTimeCalculator.shared.calculate(date: instant("2026-03-08T07:00:00Z"), longitude: -74.006, timeZone: zone)
        func seconds(_ value: String) -> Int {
            let fields = value.split(separator: ":").map { Int($0)! }
            return fields[0] * 3600 + fields[1] * 60 + fields[2]
        }
        XCTAssertEqual(seconds(after.trueSolarTimeString) - seconds(before.trueSolarTimeString), 1)
    }

    @MainActor
    func testYearAndMonthChangeAtTheSameInstantForDifferentLongitudes() {
        let language = LocalizationManager.shared.effectiveLanguage
        defer { LocalizationManager.shared.effectiveLanguage = language }
        LocalizationManager.shared.effectiveLanguage = .zhHans
        let boundary = liChunBoundary()
        let zone = TimeZone(secondsFromGMT: 8 * 3600)!
        func pillars(_ date: Date, _ longitude: Double) -> [Substring] {
            Array(SolarTimeCalculator.shared.calculate(date: date, longitude: longitude, timeZone: zone).baziGanzhi.split(separator: " ").prefix(2))
        }
        let before = boundary.addingTimeInterval(-60)
        let after = boundary.addingTimeInterval(60)
        XCTAssertEqual(pillars(before, 80), pillars(before, 120))
        XCTAssertEqual(pillars(after, 80), pillars(after, 120))
        XCTAssertNotEqual(pillars(before, 120), pillars(after, 120))
    }

    @MainActor
    func testSolarClockCrossingNewYearDoesNotChangeGanzhiYear() {
        let language = LocalizationManager.shared.effectiveLanguage
        defer { LocalizationManager.shared.effectiveLanguage = language }
        LocalizationManager.shared.effectiveLanguage = .zhHans
        let date = instant("2025-12-31T16:30:00Z")
        let zone = TimeZone(secondsFromGMT: 8 * 3600)!
        let west = SolarTimeCalculator.shared.calculate(date: date, longitude: 80, timeZone: zone)
        let east = SolarTimeCalculator.shared.calculate(date: date, longitude: 120, timeZone: zone)
        XCTAssertEqual(west.baziGanzhi.split(separator: " ").first, east.baziGanzhi.split(separator: " ").first)
    }

    private func survey(_ method: String) -> HouseSpatialSurvey {
        HouseSpatialSurvey(scanMethod: method,
                           dimensions: HouseDimensions(totalWidth: 12, totalDepth: 4, ceilingHeight: 2.8, grossFloorArea: 48, usableFloorArea: 48),
                           walls: [], openings: [], beams: [], rooms: [], objects: [], centroid: .zero,
                           compassHeading: 90, shaItems: [], fengshuiScore: 80)
    }

    @MainActor
    func testPropertySwitchClearsModelsExteriorAndPersistedReport() throws {
        let suite = "ios-regression-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShaSurveyStore(defaults: defaults)
        store.replaceProperty(measured: survey("LiDAR"), virtual: survey("VR"),
                              exterior: [ExteriorShaRecord(shaID: "luchong", bearingDegrees: 90)])
        store.replaceProperty(measured: nil, virtual: nil, exterior: [])
        XCTAssertNil(defaults.data(forKey: SpatialSurveyArchiveKeys.measured))
        XCTAssertNil(defaults.data(forKey: SpatialSurveyArchiveKeys.virtual))
        XCTAssertNil(store.archive)
        XCTAssertNil(ShaSurveyStore(defaults: defaults).archive)
    }

    @MainActor
    func testReplacingMeasuredPropertyDoesNotKeepOldVirtualModel() throws {
        let suite = "ios-regression-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShaSurveyStore(defaults: defaults)
        store.replaceProperty(measured: nil, virtual: survey("VR"), exterior: [])
        let measured = survey("LiDAR B")
        store.replaceProperty(measured: measured, virtual: nil, exterior: [])
        XCTAssertEqual(store.latestInterior?.id, measured.id)
        XCTAssertNil(defaults.data(forKey: SpatialSurveyArchiveKeys.virtual))
    }

    private func record(image: String?) -> FloorplanCaseRecord {
        FloorplanCaseRecord(id: "original", title: "A", createdAt: Date(), sittingSummary: "90°",
                            layout: SavedFloorplanLayout(rooms: [], centroidX: 0.5, centroidY: 0.5,
                                                         compassRotation: 90, isSyncWithCompass: false, hasFloorplanAccess: false,
                                                         floorplanAccessGrantID: nil, floorplanAccessGrantSignature: nil), imageFileName: image)
    }

    func testPortableCaseBackupRestoresImageOnAnotherDevice() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = root.appendingPathComponent("source")
        let destination = root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let pixels = UIGraphicsImageRenderer(size: CGSize(width: 3, height: 1)).image { _ in
            UIColor.red.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 3, height: 1))
        }.pngData()!
        try pixels.write(to: source.appendingPathComponent("original.jpg"))
        let data = try FloorplanCaseAssets.backup(record(image: "original.jpg"), directory: source)
        let imported = try FloorplanCaseAssets.importBackup(data, existingIDs: [], directory: destination)
        let name = try XCTUnwrap(imported.imageFileName)
        XCTAssertNotEqual(name, "original.jpg")
        XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent(name)), pixels)
        XCTAssertNil(imported.backupImageData)
    }

    func testLegacyDuplicateImportAndDeletionPreserveOriginalImage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = record(image: "original.jpg")
        let bytes = Data([1, 2, 3])
        try bytes.write(to: directory.appendingPathComponent("original.jpg"))
        let imported = try FloorplanCaseAssets.importBackup(JSONEncoder().encode(original), existingIDs: [original.id], directory: directory)
        XCTAssertNotEqual(imported.id, original.id)
        XCTAssertNotEqual(imported.imageFileName, original.imageFileName)
        try FloorplanCaseAssets.deleteImage(imported, remainingCases: [original], directory: directory)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("original.jpg")), bytes)
        // Older app versions may already have two records sharing one file.
        var legacyCopy = original
        legacyCopy.id = "legacy-copy"
        try FloorplanCaseAssets.deleteImage(legacyCopy, remainingCases: [original], directory: directory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("original.jpg").path))
    }

    func testLegacyLayoutsDecodeWithoutNewOptionalFields() throws {
        let original = record(image: nil)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original.layout)) as? [String: Any])
        for key in ["aspectRatio", "widthMeters", "depthMeters"] { object.removeValue(forKey: key) }
        let restored = try JSONDecoder().decode(SavedFloorplanLayout.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(restored.aspectRatio)
        XCTAssertEqual(restored.compassRotation, 90)
    }

    func testLifetimeRevocationPreservesSubscriptionAndCredits() {
        var mirror = StoreKitIAPManager.EntitlementMirror(verifiedAt: Date(), isAuthoritative: true,
                                                         isLifetime: true, vipActive: true, vipExpireDate: 12345,
                                                         floorplanCredits: 2, tianjiCredits: 3,
                                                         purchasedProductIDs: [IAPProductID.proLifetime.rawValue, IAPProductID.vipYearly.rawValue])
        mirror.revokePaidProduct(IAPProductID.proLifetime.rawValue)
        XCTAssertFalse(mirror.isLifetime)
        XCTAssertTrue(mirror.vipActive)
        XCTAssertEqual(mirror.floorplanCredits, 2)
        XCTAssertEqual(mirror.tianjiCredits, 3)
        XCTAssertEqual(mirror.purchasedProductIDs, [IAPProductID.vipYearly.rawValue])
        mirror.revokePaidProduct(IAPProductID.vipYearly.rawValue)
        XCTAssertFalse(mirror.vipActive)
        XCTAssertEqual(mirror.vipExpireDate, 0)
        XCTAssertTrue(mirror.purchasedProductIDs.isEmpty)
    }

    func testManualRestoreInvalidatesPreSyncScansAndBlocksBackgroundRefreshes() throws {
        var coordinator = EntitlementScanCoordinator()
        let beforeSync = try XCTUnwrap(coordinator.beginScan(restoring: false))
        coordinator.beginRestore()
        XCTAssertFalse(coordinator.canCommit(beforeSync))
        XCTAssertNil(coordinator.beginScan(restoring: false))
        let restore = try XCTUnwrap(coordinator.beginScan(restoring: true))
        XCTAssertNil(coordinator.beginScan(restoring: false))
        XCTAssertTrue(coordinator.canCommit(restore))
        coordinator.endRestore()
        XCTAssertNotNil(coordinator.beginScan(restoring: false))
    }

    func testLaterEntitlementScanCannotBeOverwrittenByAnOlderScan() throws {
        var coordinator = EntitlementScanCoordinator()
        let old = try XCTUnwrap(coordinator.beginScan(restoring: false))
        let latest = try XCTUnwrap(coordinator.beginScan(restoring: false))
        XCTAssertFalse(coordinator.canCommit(old))
        XCTAssertTrue(coordinator.canCommit(latest))
    }

    func testRefundDuringRestoreRejectsTheScanAndPermitsReconciliation() throws {
        var coordinator = EntitlementScanCoordinator()
        coordinator.beginRestore()
        let scan = try XCTUnwrap(coordinator.beginScan(restoring: true))
        coordinator.revoke()
        XCTAssertFalse(coordinator.canCommit(scan))
        let retry = try XCTUnwrap(coordinator.beginScan(restoring: true))
        XCTAssertTrue(coordinator.canCommit(retry))
        XCTAssertNil(coordinator.beginScan(restoring: false))
    }

    func testFailedRestoreReleasesTheBackgroundReconciliationGate() throws {
        var coordinator = EntitlementScanCoordinator()
        coordinator.beginRestore()
        coordinator.endRestore()
        XCTAssertFalse(coordinator.isRestoring)
        XCTAssertNotNil(coordinator.beginScan(restoring: false))
    }

    func testRestoreReportsOnlyFreshlyVerifiedCurrentPaidProducts() {
        let now = instant("2026-11-09T00:00:00Z")
        var mirror = StoreKitIAPManager.EntitlementMirror(verifiedAt: now, isAuthoritative: true,
            isLifetime: true, vipActive: false, vipExpireDate: 0, floorplanCredits: 3, tianjiCredits: 4,
            purchasedProductIDs: [IAPProductID.proLifetime.rawValue])
        let all = IAPProductID.allCases.map(\.rawValue)
        XCTAssertEqual(mirror.restoredProductIDs(confirmed: all, at: now), [IAPProductID.proLifetime.rawValue])
        XCTAssertEqual(mirror.restoredProductIDs(confirmed: [], at: now), [])
        mirror.vipActive = true
        XCTAssertEqual(Set(mirror.restoredProductIDs(confirmed: all, at: now)),
                       Set([IAPProductID.vipYearly.rawValue, IAPProductID.proLifetime.rawValue]))
        mirror.revokePaidProduct(IAPProductID.vipYearly.rawValue)
        XCTAssertEqual(mirror.restoredProductIDs(confirmed: [IAPProductID.vipYearly.rawValue], at: now), [])
        mirror.isAuthoritative = false
        XCTAssertEqual(mirror.restoredProductIDs(confirmed: all, at: now), [])
    }

    @MainActor
    func testRestoreFailureMessagesIdentifySandboxAndXcodeInAllLanguages() {
        XCTAssertEqual(PurchaseRestoreEnvironment.sandbox.noPurchasesMessageKey, "iap_restore_none_sandbox")
        XCTAssertEqual(PurchaseRestoreEnvironment.xcode.noPurchasesMessageKey, "iap_restore_none_xcode")
        XCTAssertEqual(PurchaseRestoreEnvironment.production.noPurchasesMessageKey, "iap_restore_none")
        XCTAssertEqual(PurchaseRestoreEnvironment.unknown.noPurchasesMessageKey, "iap_restore_none")
        let lang = LocalizationManager.shared
        let oldLanguage = lang.effectiveLanguage
        defer { lang.effectiveLanguage = oldLanguage }
        for language in AppLanguage.allCases where language != .auto {
            lang.effectiveLanguage = language
            for environment in [PurchaseRestoreEnvironment.production, .sandbox, .xcode, .unknown] {
                let key = environment.noPurchasesMessageKey
                XCTAssertNotEqual(lang.t(key), key)
                XCTAssertFalse(lang.t(key).isEmpty)
            }
            XCTAssertNotEqual(lang.t("iap_restore_unavailable"), lang.t("iap_restore_none"))
            XCTAssertNotEqual(lang.t("iap_restore_success"), "iap_restore_success")
        }
    }

    func testIncompleteSubscriptionDisclosuresCannotBeUsedForPurchasing() {
        XCTAssertNil(SubscriptionPurchaseTerms(title: " ", displayPrice: "$19.99", periodValue: 1, periodUnit: .year))
        XCTAssertNil(SubscriptionPurchaseTerms(title: "Annual VIP", displayPrice: "\n", periodValue: 1, periodUnit: .year))
        XCTAssertNil(SubscriptionPurchaseTerms(title: "Annual VIP", displayPrice: "$19.99", periodValue: 0, periodUnit: .year))
        XCTAssertNil(SubscriptionPurchaseTerms(title: "Annual VIP", displayPrice: "$19.99", periodValue: -1, periodUnit: .month))
    }

    @MainActor
    func testSubscriptionDisclosureUsesTheActualStorefrontPriceAndBillingPeriod() throws {
        let lang = LocalizationManager.shared
        let oldLanguage = lang.effectiveLanguage
        defer { lang.effectiveLanguage = oldLanguage }
        lang.effectiveLanguage = .en
        let annual = try XCTUnwrap(SubscriptionPurchaseTerms(title: "StoreKit Subscription Name", displayPrice: "€29,99",
                                                           periodValue: 1, periodUnit: .year))
        XCTAssertEqual(annual.title, "StoreKit Subscription Name")
        XCTAssertEqual(annual.localizedPeriod, "1 year")
        XCTAssertEqual(annual.localizedPricePerPeriod, "€29,99 / 1 year")
        let quarterly = try XCTUnwrap(SubscriptionPurchaseTerms(title: "VIP", displayPrice: "฿399.00",
                                                              periodValue: 3, periodUnit: .month))
        XCTAssertEqual(quarterly.localizedPeriod, "3 months")
        XCTAssertEqual(quarterly.localizedPricePerPeriod, "฿399.00 / 3 months")
    }

    @MainActor
    func testSubscriptionDisclosurePeriodsAreLocalizedWithoutLosingValuesOrCurrency() throws {
        let lang = LocalizationManager.shared
        let oldLanguage = lang.effectiveLanguage
        defer { lang.effectiveLanguage = oldLanguage }
        for language in AppLanguage.allCases where language != .auto {
            lang.effectiveLanguage = language
            for unit in SubscriptionPurchaseTerms.Unit.allCases {
                for value in [1, 3] {
                    let terms = try XCTUnwrap(SubscriptionPurchaseTerms(title: "VIP", displayPrice: "NT$990",
                                                                      periodValue: value, periodUnit: unit))
                    XCTAssertTrue(terms.localizedPeriod.contains(String(value)), "\(language) \(unit)")
                    XCTAssertFalse(terms.localizedPeriod.contains("subscription_period_"))
                    XCTAssertTrue(terms.localizedPricePerPeriod.contains("NT$990"))
                    XCTAssertTrue(terms.localizedPricePerPeriod.contains(terms.localizedPeriod))
                    XCTAssertFalse(terms.localizedPricePerPeriod.contains("%@"))
                }
            }
        }
    }

    @MainActor
    func testSubscriptionDisclosureUsesSingularAndPluralPeriods() throws {
        let lang = LocalizationManager.shared
        let oldLanguage = lang.effectiveLanguage
        defer { lang.effectiveLanguage = oldLanguage }
        lang.effectiveLanguage = .en
        let expected: [(SubscriptionPurchaseTerms.Unit, String)] = [(.day, "day"), (.week, "week"), (.month, "month"), (.year, "year")]
        for (unit, name) in expected {
            let one = try XCTUnwrap(SubscriptionPurchaseTerms(title: "VIP", displayPrice: "$9.99", periodValue: 1, periodUnit: unit))
            let many = try XCTUnwrap(SubscriptionPurchaseTerms(title: "VIP", displayPrice: "$9.99", periodValue: 2, periodUnit: unit))
            XCTAssertEqual(one.localizedPeriod, "1 " + name)
            XCTAssertEqual(many.localizedPeriod, "2 " + name + "s")
        }
    }

    func testPurchaseEulaLinkTargetsTheLicenseDocumentInsteadOfTheSupportPage() {
        XCTAssertEqual(LegalLinks.termsOfUse.scheme, "https")
        XCTAssertEqual(LegalLinks.termsOfUse.host, "yulintao.github.io")
        XCTAssertEqual(LegalLinks.termsOfUse.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")), "tiandiluopan-subscription")
        XCTAssertEqual(LegalLinks.privacyPolicy.scheme, "https")
        XCTAssertEqual(LegalLinks.privacyPolicy.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")), "tiandiluopan-privacy")
    }

    func testReopeningJanuaryBirthdayNeverSubtractsAnotherYear() {
        let original = instant("1990-01-10T04:00:00Z")
        var savedDate = original
        let calendar = UserKuaProfileManager.gregorianCalendar(timeZone: TimeZone(secondsFromGMT: 8 * 3600)!)
        for _ in 0..<5 {
            let editor = BirthDateEditorState(date: savedDate, calendar: calendar)
            XCTAssertEqual(editor.year, 1990)
            XCTAssertEqual(UserKuaProfileManager.fengShuiYear(for: editor.date, calendar: calendar), 1989)
            savedDate = editor.date
        }
        XCTAssertEqual(savedDate, original)
    }

    func testBirthYearUsesGregorianYearUnderBuddhistAndIslamicCalendars() {
        let date = instant("1990-06-15T04:00:00Z")
        let identifiers: [Calendar.Identifier] = [.gregorian, .buddhist, .islamicCivil]
        for identifier in identifiers {
            var calendar = Calendar(identifier: identifier)
            calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
            XCTAssertEqual(BirthDateEditorState(date: date, calendar: calendar).year, 1990)
            XCTAssertEqual(UserKuaProfileManager.fengShuiYear(for: date, calendar: calendar), 1990)
        }
    }

    func testOwnerAndFamilyUseTheAstronomicalLiChunBoundary() {
        let boundary = liChunBoundary()
        let calendar = UserKuaProfileManager.gregorianCalendar(timeZone: TimeZone(secondsFromGMT: 8 * 3600)!)
        XCTAssertEqual(UserKuaProfileManager.fengShuiYear(for: boundary.addingTimeInterval(-1), calendar: calendar), 2025)
        XCTAssertEqual(UserKuaProfileManager.fengShuiYear(for: boundary.addingTimeInterval(1), calendar: calendar), 2026)
        let member = FamilyMemberProfile(role: .spouse, birthDate: instant("1990-01-10T04:00:00Z"),
                                         birthYear: 2035, isMale: false)
        XCTAssertEqual(member.birthYear, 1989)
        XCTAssertEqual(member.effectiveFengShuiYear, 1989)
    }

    @MainActor
    func testOneZiHourHasOneBureauAndOneHourPillarAcrossMidnight() {
        let zone = TimeZone(secondsFromGMT: 8 * 3600)!
        let early = QimenEngine.shared.calculateChart(date: instant("2026-11-10T15:30:00Z"), timeZone: zone)
        let late = QimenEngine.shared.calculateChart(date: instant("2026-11-10T16:30:00Z"), timeZone: zone)
        XCTAssertEqual(early.juNumber, 8)
        XCTAssertEqual(early.juNumber, late.juNumber)
        XCTAssertEqual(early.title, late.title)
        XCTAssertEqual(early.cells.map(\.doorName), late.cells.map(\.doorName))
        XCTAssertEqual(early.cells.map(\.tianStem), late.cells.map(\.tianStem))
        XCTAssertEqual(early.cells.map(\.diStem), late.cells.map(\.diStem))
        XCTAssertEqual(early.cells.map(\.starName), late.cells.map(\.starName))
        XCTAssertEqual(early.cells.map(\.godName), late.cells.map(\.godName))
    }

    func testQimenCacheInvalidatesForSolarTermCrossingWithinOneHour() {
        let boundary = liChunBoundary()
        let zone = TimeZone(secondsFromGMT: 8 * 3600)!
        let before = QimenEngine.shared.chartTimeKey(for: boundary.addingTimeInterval(-1), timeZone: zone)
        let after = QimenEngine.shared.chartTimeKey(for: boundary.addingTimeInterval(1), timeZone: zone)
        XCTAssertEqual(before.hour, after.hour)
        XCTAssertEqual(before.day, after.day)
        XCTAssertNotEqual(before.solarTerm, after.solarTerm)
        XCTAssertNotEqual(before, after)
    }

    func testQimenCacheDistinguishesRepeatedHourAtDaylightSavingEnd() {
        let zone = TimeZone(identifier: "America/New_York")!
        let first = QimenEngine.shared.chartTimeKey(for: instant("2026-11-01T05:30:00Z"), timeZone: zone)
        let second = QimenEngine.shared.chartTimeKey(for: instant("2026-11-01T06:30:00Z"), timeZone: zone)
        XCTAssertEqual(first.hour, second.hour)
        XCTAssertNotEqual(first, second)
    }

    func testChangingMountainRestoresAutomaticModeEvenWhenAutomaticFlagIsUnchanged() {
        var selection = FlyingStarModeSelection()
        selection.toggle(automatic: false)
        XCTAssertTrue(selection.usesTiGua(automatic: false))
        selection.restoreAutomatic()
        XCTAssertFalse(selection.usesTiGua(automatic: false))
        selection.toggle(automatic: true)
        XCTAssertFalse(selection.usesTiGua(automatic: true))
        selection.restoreAutomatic()
        XCTAssertTrue(selection.usesTiGua(automatic: true))
    }

    @MainActor
    func testReportKeepsSelectedPeriodAndManualTiGuaInsteadOfDefaults() {
        let date = instant("2026-11-08T04:00:00Z")
        let snapshot = TianJiAnalysisSnapshot(heading: 90, period: 8, useTiGua: true, reportDate: date)
        let exported = snapshot.flyingStarsChart()
        let displayed = FlyingStarsEngine.shared.calculateChart(
            period: 8, sitting: Mountain24Data.shared.mountain(for: 270),
            facing: Mountain24Data.shared.mountain(for: 90), useTiGua: true, date: date)
        XCTAssertEqual(exported.period, 8)
        XCTAssertTrue(exported.isTiGua)
        XCTAssertFalse(TianJiAnalysisSnapshot(heading: 90, reportDate: date).useTiGua)
        XCTAssertEqual(exported.palaces.map(\.mountainStar), displayed.palaces.map(\.mountainStar))
        XCTAssertEqual(exported.palaces.map(\.facingStar), displayed.palaces.map(\.facingStar))
        XCTAssertEqual(snapshot.reportDate, date)
    }

    @MainActor
    func testManualLowerChartIsPreservedForAnOffCenterHeadingInReport() {
        let snapshot = TianJiAnalysisSnapshot(heading: 94, period: 8, useTiGua: false)
        XCTAssertTrue(TianJiAnalysisSnapshot(heading: 94).useTiGua)
        XCTAssertFalse(snapshot.flyingStarsChart().isTiGua)
    }

    func testExportReservationStaysActiveUntilExplicitCompletionAndCommitsOnce() throws {
        var reservations = ConsumableCreditReservations()
        let token = try XCTUnwrap(reservations.reserve(availableCredits: 1))
        // Repeated availability checks must not evict a still-presented share.
        for _ in 0..<100 { XCTAssertNil(reservations.reserve(availableCredits: 1)) }
        XCTAssertEqual(reservations.count, 1)
        XCTAssertTrue(reservations.finish(token))
        XCTAssertFalse(reservations.finish(token))
        XCTAssertEqual(reservations.count, 0)
    }

    func testCancellingOneExportDoesNotReleaseAnotherExportsCredit() throws {
        var reservations = ConsumableCreditReservations()
        let first = try XCTUnwrap(reservations.reserve(availableCredits: 2))
        let second = try XCTUnwrap(reservations.reserve(availableCredits: 2))
        XCTAssertTrue(reservations.finish(first))
        XCTAssertFalse(reservations.finish(first))
        XCTAssertEqual(reservations.count, 1)
        XCTAssertNil(reservations.reserve(availableCredits: 1))
        XCTAssertTrue(reservations.finish(second))
    }

    func testSealKeyMigrationPreservesTheKeyAndCanBeReadFromABackup() throws {
        let original = Data(repeating: 41, count: 32)
        var keychain = [IAPSealKeyStore.legacyAccount: original]
        var migratedAccounts: [String] = []
        let store = IAPSealKeyStore(read: { keychain[$0] }, write: { account, bytes in
            keychain[account] = bytes
            return bytes
        }, makeMigratable: { migratedAccounts.append($0) }, generate: {
            XCTFail("An upgrade must not replace the existing seal key")
            return Data(repeating: 0, count: 32)
        })
        XCTAssertEqual(try store.key().withUnsafeBytes { Data($0) }, original)
        XCTAssertEqual(keychain[IAPSealKeyStore.account], original)
        XCTAssertEqual(migratedAccounts, [IAPSealKeyStore.account])
        let backup = keychain
        let restored = IAPSealKeyStore(read: { backup[$0] }, write: { _, bytes in
            XCTFail("A restored key must not be replaced")
            return bytes
        }, makeMigratable: { _ in })
        XCTAssertEqual(try restored.key(createIfMissing: false).withUnsafeBytes { Data($0) }, original)
    }

    func testTemporarilyLockedKeychainDoesNotGenerateOrOverwriteAPaidLedgersKey() {
        let store = IAPSealKeyStore(read: { _ in
            throw IAPLedgerStorageError.keychain(errSecInteractionNotAllowed)
        }, write: { _, bytes in
            XCTFail("Read failures must never be treated as an absent key")
            return bytes
        }, makeMigratable: { _ in XCTFail("The key was not read") }, generate: {
            XCTFail("A temporary Keychain error must not rotate the key")
            return Data()
        })
        XCTAssertThrowsError(try store.key())
    }

    func testFailedKeyWriteIsNotCachedAndTheNextAttemptCanRecover() throws {
        var persistedKey: Data?
        var attempts = 0
        let bytes = Data(repeating: 17, count: 32)
        let store = IAPSealKeyStore(read: { _ in persistedKey }, write: { _, data in
            attempts += 1
            if attempts == 1 { throw IAPLedgerStorageError.keychain(errSecNotAvailable) }
            persistedKey = data
            return data
        }, makeMigratable: { _ in }, generate: { bytes })
        XCTAssertThrowsError(try store.key())
        XCTAssertNil(persistedKey)
        XCTAssertEqual(try store.key().withUnsafeBytes { Data($0) }, bytes)
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(try store.key().withUnsafeBytes { Data($0) }, bytes)
        XCTAssertEqual(attempts, 2)
    }

    func testMissingBackupKeyIsReportedWithoutGeneratingAReplacement() {
        let store = IAPSealKeyStore(read: { _ in nil }, write: { _, bytes in
            XCTFail("An existing ledger cannot be resealed with a new key")
            return bytes
        }, makeMigratable: { _ in }, generate: {
            XCTFail("An existing ledger requires its original key")
            return Data()
        })
        XCTAssertThrowsError(try store.key(createIfMissing: false))
    }

    func testRecoveredLedgerKeepsItsBalanceWhenVerifiedMembershipIsMerged() {
        let now = Date()
        var recovered = StoreKitIAPManager.EntitlementMirror(verifiedAt: .distantPast, isAuthoritative: false,
            isLifetime: false, vipActive: false, vipExpireDate: 0, floorplanCredits: 3,
            tianjiCredits: 2, purchasedProductIDs: [], processedTransactionIDs: ["paid-transaction"],
            redeemedFloorplanGrantIDs: ["floorplan-v2-already-paid"])
        let verified = StoreKitIAPManager.EntitlementMirror(verifiedAt: now, isAuthoritative: true,
            isLifetime: true, vipActive: false, vipExpireDate: 0, floorplanCredits: 0,
            tianjiCredits: 0, purchasedProductIDs: [IAPProductID.proLifetime.rawValue])
        recovered.applyMembershipSnapshot(from: verified)
        XCTAssertTrue(recovered.isLifetime)
        XCTAssertTrue(recovered.isAuthoritative)
        XCTAssertEqual(recovered.verifiedAt, now)
        XCTAssertEqual(recovered.floorplanCredits, 3)
        XCTAssertEqual(recovered.tianjiCredits, 2)
        XCTAssertEqual(recovered.processedTransactionIDs, ["paid-transaction"])
        XCTAssertEqual(recovered.redeemedFloorplanGrantIDs, ["floorplan-v2-already-paid"])
    }

    func testFailedAccessibilityMigrationRetainsTheOriginalKeyForRetry() throws {
        let original = Data(repeating: 29, count: 32)
        var canMigrate = false
        let store = IAPSealKeyStore(read: { account in
            account == IAPSealKeyStore.account ? original : nil
        }, write: { _, bytes in
            XCTFail("Accessibility changes must not delete or replace a key")
            return bytes
        }, makeMigratable: { _ in
            if !canMigrate { throw IAPLedgerStorageError.keychain(errSecNotAvailable) }
        })
        XCTAssertThrowsError(try store.key())
        canMigrate = true
        XCTAssertEqual(try store.key().withUnsafeBytes { Data($0) }, original)
    }

    @MainActor
    func testFailedFloorplanImageSaveReleasesItsReservationWithoutSpending() throws {
        let suite = "failed-case-save-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data([1]).write(to: blocker) // A file cannot be the image directory.
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: blocker)
        }
        let workspace = FloorplanWorkspaceStore(defaults: defaults, directory: blocker)
        var reservations = ConsumableCreditReservations()
        let grant = FloorplanAccessGrant(id: "floorplan-v2-save-failure", signature: "test")
        var didCommit = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }
        let layout = SavedFloorplanLayout(rooms: [], centroidX: 0.5, centroidY: 0.5,
                                         compassRotation: 0, isSyncWithCompass: false,
                                         hasFloorplanAccess: true, floorplanAccessGrantID: grant.id,
                                         floorplanAccessGrantSignature: grant.signature)
        let outcome = FloorplanCreditPurchase.acquire(reserve: {
            reservations.reserve(availableCredits: 1, token: grant.id).map { _ in grant }
        }, persist: { _ in
            do { return try workspace.save(layout: layout, image: image, writerID: UUID()) }
            catch { return false }
        }, commit: { _ in didCommit = true; return true }, cancel: {
            reservations.finish($0.id)
        })
        guard case .saveFailed = outcome else { return XCTFail("Saving must fail before any debit") }
        XCTAssertFalse(didCommit)
        XCTAssertEqual(reservations.count, 0)
        XCTAssertNil(defaults.data(forKey: FloorplanWorkspaceStore.layoutKey))
        XCTAssertEqual(workspace.snapshot.revision, 0)
    }

    func testFloorplanCommitFailureReleasesItsSlotAndDoesNotActivateTheGrant() throws {
        var reservations = ConsumableCreditReservations()
        let grant = FloorplanAccessGrant(id: "floorplan-v2-write-failure", signature: "test")
        var saveSucceeded = false
        let outcome = FloorplanCreditPurchase.acquire(reserve: {
            reservations.reserve(availableCredits: 1, token: grant.id).map { _ in grant }
        }, persist: { _ in saveSucceeded = true; return true }, commit: { _ in false }, cancel: {
            reservations.finish($0.id)
        })
        guard case .commitFailed = outcome else { return XCTFail("A failed ledger write must not activate the case") }
        XCTAssertTrue(saveSucceeded)
        XCTAssertEqual(reservations.count, 0)
        XCTAssertNotNil(reservations.reserve(availableCredits: 1))
        XCTAssertTrue(grant.requiresCommittedDebit)
    }

    func testFloorplanGrantDebitsOnceOnlyAfterItsSaveSucceeds() throws {
        var mirror = StoreKitIAPManager.EntitlementMirror(verifiedAt: Date(), isAuthoritative: true,
            isLifetime: false, vipActive: false, vipExpireDate: 0, floorplanCredits: 1,
            tianjiCredits: 0, purchasedProductIDs: [])
        let grant = FloorplanAccessGrant(id: "floorplan-v2-success", signature: "test")
        var saved = false
        let outcome = FloorplanCreditPurchase.acquire(reserve: { grant }, persist: { _ in
            XCTAssertEqual(mirror.floorplanCredits, 1)
            XCTAssertTrue(mirror.redeemedFloorplanGrantIDs.isEmpty)
            saved = true
            return true
        }, commit: {
            XCTAssertTrue(saved)
            return mirror.redeemFloorplanGrant($0.id)
        }, cancel: { _ in })
        guard case .completed(let redeemed) = outcome else { return XCTFail("Expected a saved and paid case") }
        XCTAssertEqual(redeemed, grant)
        XCTAssertEqual(mirror.floorplanCredits, 0)
        XCTAssertEqual(mirror.redeemedFloorplanGrantIDs, [grant.id])
        XCTAssertFalse(mirror.redeemFloorplanGrant(grant.id))
        XCTAssertEqual(mirror.floorplanCredits, 0)
        let restored = try JSONDecoder().decode(StoreKitIAPManager.EntitlementMirror.self,
                                               from: JSONEncoder().encode(mirror))
        XCTAssertEqual(restored.redeemedFloorplanGrantIDs, [grant.id])
    }

    private func entrance(position: SIMD3<Float>, normal: SIMD3<Float>) -> SpatialOpening3D {
        SpatialOpening3D(type: .entranceDoor, position: position, normal: normal, width: 1, height: 2.1)
    }

    func testHouseFacingIsInvariantWhenScanCoordinateAxesRotate() throws {
        let eastDoor = entrance(position: SIMD3<Float>(5, 1, 0), normal: SIMD3<Float>(1, 0, 0))
        let northDoor = entrance(position: SIMD3<Float>(0, 1, -5), normal: SIMD3<Float>(0, 0, -1))
        let first = try XCTUnwrap(HouseSpatialSurveyEngine.resolveHouseFacing(openings: [eastDoor], centroid: .zero, coordinateHeading: 0))
        let rotated = try XCTUnwrap(HouseSpatialSurveyEngine.resolveHouseFacing(openings: [northDoor], centroid: .zero, coordinateHeading: 90))
        XCTAssertEqual(first, 90, accuracy: 0.00001)
        XCTAssertEqual(rotated, first, accuracy: 0.00001)
    }

    func testHouseFacingCorrectsAnInwardDoorNormalAndHonorsExplicitFacing() throws {
        let door = entrance(position: SIMD3<Float>(5, 1, 0), normal: SIMD3<Float>(-1, 0, 0))
        XCTAssertEqual(try XCTUnwrap(HouseSpatialSurveyEngine.resolveHouseFacing(openings: [door], centroid: .zero, coordinateHeading: 0)), 90, accuracy: 0.00001)
        XCTAssertEqual(HouseSpatialSurveyEngine.resolveHouseFacing(openings: [door], centroid: .zero, coordinateHeading: 0, explicitFacing: 180), 180)
        XCTAssertNil(HouseSpatialSurveyEngine.resolveHouseFacing(openings: [], centroid: .zero, coordinateHeading: 90))
    }

    @MainActor
    func testRotatedScansGiveTheSameHouseAnalysis() throws {
        let language = LocalizationManager.shared.effectiveLanguage
        defer { LocalizationManager.shared.effectiveLanguage = language }
        LocalizationManager.shared.effectiveLanguage = .zhHans
        let date = instant("2026-11-08T04:00:00Z")
        let corners: [SIMD3<Float>] = [SIMD3(-5, 0, -3), SIMD3(5, 0, -3), SIMD3(5, 0, 3), SIMD3(-5, 0, 3)]
        func rotate(_ p: SIMD3<Float>) -> SIMD3<Float> { SIMD3(p.z, p.y, -p.x) }
        func analyze(rotated: Bool) -> HouseSpatialSurvey {
            let points = rotated ? corners.map(rotate) : corners
            let walls = (0..<4).map { SpatialWall3D(start: points[$0], end: points[($0 + 1) % 4]) }
            let doorPosition = SIMD3<Float>(5, 1, 0)
            let doorNormal = SIMD3<Float>(1, 0, 0)
            let rooms = [
                SpatialRoom3D(name: "主卧", type: .masterBedroom, center: rotated ? rotate(SIMD3(2, 1.4, -1)) : SIMD3(2, 1.4, -1), size: SIMD3(3, 2.8, 2), rotationY: rotated ? -Float.pi / 2 : 0),
                SpatialRoom3D(name: "卫浴", type: .bathroom, center: rotated ? rotate(SIMD3(-2, 1.4, 1)) : SIMD3(-2, 1.4, 1), size: SIMD3(2, 2.8, 2), rotationY: rotated ? -Float.pi / 2 : 0)
            ]
            return HouseSpatialSurveyEngine.analyzeSpatialHouse(
                scanMethod: "test", walls: walls,
                openings: [entrance(position: rotated ? rotate(doorPosition) : doorPosition,
                                    normal: rotated ? rotate(doorNormal) : doorNormal)],
                beams: [], rooms: rooms, objects: [], compassHeading: rotated ? 90 : 0,
                centroidOverride: .zero, analysisDate: date)
        }
        let first = analyze(rotated: false)
        let second = analyze(rotated: true)
        XCTAssertEqual(try XCTUnwrap(first.houseFacingDegrees), 90, accuracy: 0.00001)
        XCTAssertEqual(first.houseFacingDegrees, second.houseFacingDegrees)
        let findings: (HouseSpatialSurvey) -> [String] = { survey in
            survey.shaItems.filter { $0.detail.contains("八宅") || $0.detail.contains("玄空") || $0.title.contains("玄空") }
                .map { $0.title + "|" + $0.locationName + "|" + $0.detail }.sorted()
        }
        XCTAssertFalse(findings(first).isEmpty)
        XCTAssertEqual(findings(first), findings(second))
    }

    @MainActor
    func testManualVrHeadingAndCentroidSurviveGenerationAndArchiveRoundTrip() throws {
        let reference = VRSurveyReference(coordinateHeading: 90, houseFacingDegrees: 180,
                                          normalizedCentroid: CGPoint(x: 0.3, y: 0.7), yaw: 0)
        let center = try XCTUnwrap(reference.centroid(width: 12, depth: 10))
        XCTAssertEqual(center.x, 3.6, accuracy: 0.00001)
        XCTAssertEqual(center.z, 7, accuracy: 0.00001)
        let room = SpatialRoom3D(name: "客厅", type: .livingRoom, center: SIMD3(6, 1.4, 5), size: SIMD3(12, 2.8, 10))
        let result = HouseSpatialSurveyEngine.analyzeSpatialHouse(scanMethod: "VR", walls: [], openings: [], beams: [], rooms: [room], objects: [],
                                                                  compassHeading: reference.coordinateHeading, centroidOverride: center,
                                                                  houseFacingDegrees: reference.houseFacingDegrees)
        let restored = try JSONDecoder().decode(HouseSpatialSurvey.self, from: JSONEncoder().encode(result))
        XCTAssertEqual(restored.compassHeading, 90)
        XCTAssertEqual(restored.houseFacingDegrees, 180)
        XCTAssertEqual(restored.centroidX, 3.6, accuracy: 0.00001)
        XCTAssertEqual(restored.centroidZ, 7, accuracy: 0.00001)
        XCTAssertEqual(restored.centroidWasExplicit, true)
    }

    func testVrCentroidUsesTheSameRotationAndScaleAsRooms() throws {
        let reference = VRSurveyReference(coordinateHeading: 25, houseFacingDegrees: 130,
                                          normalizedCentroid: CGPoint(x: 0.25, y: 0.75), yaw: .pi / 2)
        let center = try XCTUnwrap(reference.centroid(width: 12, depth: 8))
        XCTAssertEqual(center.x, 4, accuracy: 0.00001)
        XCTAssertEqual(center.z, 1, accuracy: 0.00001)
    }

    func testLegacySurveyDecodesWithoutConfusingBaselineWithHouseFacing() throws {
        let original = survey("legacy")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json.removeValue(forKey: "houseFacingDegrees")
        json.removeValue(forKey: "centroidWasExplicit")
        let restored = try JSONDecoder().decode(HouseSpatialSurvey.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.compassHeading, 90)
        XCTAssertNil(restored.resolvedHouseFacing)
        XCTAssertNil(restored.centroidWasExplicit)
    }

    func testSolarReminderNamesFollowActualTransitionsAcrossYearBoundary() throws {
        let solar = SolarTimeCalculator.shared
        let start = instant("2026-12-23T00:00:00Z")
        let transitions = solar.upcomingSolarTerms(after: start, count: 24)
        XCTAssertEqual(transitions.count, 24)
        XCTAssertEqual(Array(transitions.prefix(3)).map(\.name), ["小寒", "大寒", "立春"])
        var previous = start
        for transition in transitions {
            XCTAssertGreaterThan(transition.date, previous)
            XCTAssertEqual(solar.solarTermName(for: transition.date.addingTimeInterval(1)), transition.name)
            XCTAssertNotEqual(solar.solarTermName(for: transition.date.addingTimeInterval(-1)), transition.name)
            XCTAssertNotNil(SolarTermsData.shared.terms.first(where: { $0.name == transition.name }))
            previous = transition.date
        }
        XCTAssertGreaterThan(try XCTUnwrap(transitions.last).date.timeIntervalSince(start), 330 * 86400)
    }

    func testSolarReminderRefillAfterDeliveryStartsWithTheFollowingTerm() throws {
        let solar = SolarTimeCalculator.shared
        let firstBatch = solar.upcomingSolarTerms(after: instant("2026-02-05T00:00:00Z"))
        let delivered = try XCTUnwrap(firstBatch.first)
        XCTAssertEqual(delivered.name, "雨水")
        let refill = solar.upcomingSolarTerms(after: delivered.date.addingTimeInterval(1))
        XCTAssertEqual(refill.count, 24)
        XCTAssertEqual(refill.first?.name, "惊蛰")
        XCTAssertGreaterThan(try XCTUnwrap(refill.last).date, try XCTUnwrap(firstBatch.last).date)
    }

    func testWorldMapArchiveKeepsItsOriginalNorthReference() throws {
        let payload = Data([1, 2, 3, 4])
        let saved = try SpatialWorldMapArchive(mapData: payload, coordinateHeading: 450)
        let restored = try SpatialWorldMapArchive.decode(JSONEncoder().encode(saved))
        XCTAssertEqual(restored.mapData, payload)
        XCTAssertEqual(restored.coordinateHeading, 90)
    }

    func testLegacyWorldMapWithoutNorthReferenceRequiresRescan() {
        XCTAssertThrowsError(try SpatialWorldMapArchive.decode(Data("bplist00-legacy-map".utf8))) {
            XCTAssertEqual($0 as? ARSpatialSurveyError, .mapOrientationUnavailable)
        }
        XCTAssertThrowsError(try SpatialWorldMapArchive(mapData: Data([1]), coordinateHeading: .nan))
    }


    func testShareCompletionCanSettleAfterPresentationOwnerReleasesLease() throws {
        var outcomes: [Bool] = []
        var lease: TianjiExportCreditLease? = TianjiExportCreditLease { outcomes.append($0) }
        var controllerCompletion: ((Bool) -> Void)? = { [heldLease = lease!] success in heldLease.complete(success: success) }
        lease = nil
        XCTAssertTrue(outcomes.isEmpty)
        controllerCompletion?(true)
        controllerCompletion?(true)
        controllerCompletion = nil
        XCTAssertEqual(outcomes, [true])
    }

    func testControllerTeardownWithoutCompletionReleasesExportSlot() {
        var outcomes: [Bool] = []
        var lease: TianjiExportCreditLease? = TianjiExportCreditLease { outcomes.append($0) }
        XCTAssertNotNil(lease)
        lease = nil
        XCTAssertEqual(outcomes, [false])
    }


    private func caseRecord(_ id: String) -> FloorplanCaseRecord {
        var value = record(image: nil)
        value.id = id
        value.title = id
        return value
    }

    @MainActor
    func testTwoWindowsInsertCasesWithoutOverwritingEachOthersArchives() throws {
        let suite = "case-store-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let shared = FloorplanCaseStore(defaults: defaults)
        let windowA = shared, windowB = shared
        try shared.insert(caseRecord("A"))
        try windowA.insert(caseRecord("B"))
        try windowB.insert(caseRecord("C"))
        XCTAssertEqual(windowA.records.map(\.id), ["C", "B", "A"])
        XCTAssertEqual(FloorplanCaseStore(defaults: defaults).records.map(\.id), ["C", "B", "A"])
    }

    @MainActor
    func testStaleWindowDeletionCannotResurrectADeletedCase() throws {
        let suite = "case-delete-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { defaults.removePersistentDomain(forName: suite) }
        let shared = FloorplanCaseStore(defaults: defaults)
        try shared.insert(caseRecord("A"))
        try shared.insert(caseRecord("B"))
        try shared.remove(id: "A", imageDirectory: directory)
        try shared.insert(caseRecord("C"))
        try shared.remove(id: "A", imageDirectory: directory)
        XCTAssertEqual(shared.records.map(\.id), ["C", "B"])
    }

    @MainActor
    func testOldWorkspaceRevisionCannotOverwriteTheNewPlanOrItsImage() throws {
        let suite = "workspace-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let store = FloorplanWorkspaceStore(defaults: defaults, directory: directory)
        let first = record(image: nil).layout
        var second = first
        second.houseFacingDegrees = 180
        func image(_ color: UIColor) -> UIImage {
            UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in
                color.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 8, height: 8))
            }
        }
        let red = image(.red), blue = image(.blue)
        XCTAssertTrue(try store.save(layout: first, image: red, writerID: UUID(), expectedRevision: 0))
        let oldRevision = store.snapshot.revision
        XCTAssertTrue(try store.save(layout: second, image: blue, writerID: UUID(), expectedRevision: oldRevision))
        let imageURL = try XCTUnwrap(store.imageURL)
        let bytes = try Data(contentsOf: imageURL)
        XCTAssertFalse(try store.save(layout: first, image: red, writerID: UUID(), expectedRevision: oldRevision))
        XCTAssertEqual(try Data(contentsOf: imageURL), bytes)
        XCTAssertEqual(store.snapshot.layout?.houseFacingDegrees, 180)
        XCTAssertTrue(store.snapshot.image === blue)
        let restored = FloorplanWorkspaceStore(defaults: defaults, directory: directory)
        XCTAssertEqual(restored.snapshot.layout?.houseFacingDegrees, 180)
    }

    @MainActor
    func testApplyingASharedWorkspaceSnapshotDoesNotStartAWriteFeedbackLoop() throws {
        let suite = "workspace-echo-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let store = FloorplanWorkspaceStore(defaults: defaults, directory: directory)
        let layout = record(image: nil).layout
        try store.save(layout: layout, image: nil, writerID: UUID())
        let revision = store.snapshot.revision
        try store.save(layout: layout, image: nil, writerID: UUID(), expectedRevision: revision)
        XCTAssertEqual(store.snapshot.revision, revision)
    }

    func testScanReferenceUsesPhysicalCameraAndArPoseIndependentlyOfLockedChart() throws {
        let baseline = try XCTUnwrap(SurveyCoordinateReference.heading(cameraHeading: 180, cameraForward: SIMD3(0, 0, -1)))
        XCTAssertEqual(baseline, 180, accuracy: 0.00001)
        let turned = try XCTUnwrap(SurveyCoordinateReference.heading(cameraHeading: 270, cameraForward: SIMD3(1, 0, 0)))
        XCTAssertEqual(turned, baseline, accuracy: 0.00001)
    }

    func testScanReferenceCannotUseAnUnavailableHeadingOrAVerticalCameraRay() {
        XCTAssertNil(SurveyCoordinateReference.heading(cameraHeading: nil, cameraForward: SIMD3(0, 0, -1)))
        XCTAssertNil(SurveyCoordinateReference.heading(cameraHeading: .nan, cameraForward: SIMD3(0, 0, -1)))
        XCTAssertNil(SurveyCoordinateReference.heading(cameraHeading: 90, cameraForward: SIMD3(0, 1, 0)))
    }

    @MainActor
    func testRoomPlanFacingSurvivesBlueprintPersistenceAndVrReconstruction() throws {
        var layout = record(image: nil).layout
        layout = SavedFloorplanLayout(rooms: [], centroidX: 0.5, centroidY: 0.5, compassRotation: 0,
                                      isSyncWithCompass: false, hasFloorplanAccess: false,
                                      floorplanAccessGrantID: nil, floorplanAccessGrantSignature: nil,
                                      houseFacingDegrees: 90)
        let restored = try JSONDecoder().decode(SavedFloorplanLayout.self, from: JSONEncoder().encode(layout))
        let orientation = FloorplanOrientation(coordinateHeading: restored.compassRotation, houseFacingDegrees: restored.houseFacingDegrees)
        let reference = VRSurveyReference(coordinateHeading: restored.compassRotation,
                                          houseFacingDegrees: orientation.facing(afterCalibratingTo: restored.compassRotation),
                                          normalizedCentroid: CGPoint(x: 0.5, y: 0.5), yaw: 0)
        let room = SpatialRoom3D(name: "客厅", type: .livingRoom, center: SIMD3(6, 1.4, 5), size: SIMD3(12, 2.8, 10))
        let result = HouseSpatialSurveyEngine.analyzeSpatialHouse(scanMethod: "VR", walls: [], openings: [], beams: [], rooms: [room], objects: [],
                                                                  compassHeading: reference.coordinateHeading,
                                                                  centroidOverride: reference.centroid(width: 12, depth: 10),
                                                                  houseFacingDegrees: reference.houseFacingDegrees)
        XCTAssertEqual(result.compassHeading, 0)
        XCTAssertEqual(result.houseFacingDegrees, 90)
        XCTAssertEqual(orientation.facing(afterCalibratingTo: 30), 120)
    }

    func testUnspecifiedHouseFacingDoesNotDefaultToBlueprintNorth() {
        let orientation = FloorplanOrientation(coordinateHeading: 80, houseFacingDegrees: nil)
        XCTAssertNil(orientation.relativeFacing)
        XCTAssertNil(orientation.facing(afterCalibratingTo: 110))
    }

    func testEntranceSelectionIsInvariantUnderArbitraryScanRotations() {
        let main = UUID(), interior = UUID()
        let corners: [SIMD2<Float>] = [SIMD2(-5, -3), SIMD2(5, -3), SIMD2(5, 3), SIMD2(-5, 3)]
        for degrees in [0.0, 15, 45, 89, 123, 270] {
            let angle = Float(degrees * .pi / 180)
            func rotate(_ p: SIMD2<Float>) -> SIMD2<Float> {
                SIMD2(p.x * cos(angle) - p.y * sin(angle), p.x * sin(angle) + p.y * cos(angle))
            }
            let doors = [SpatialEntranceCandidate(id: main, position: rotate(SIMD2(5, 0)), width: 1),
                         SpatialEntranceCandidate(id: interior, position: rotate(SIMD2(4.5, 2)), width: 1.2)]
            XCTAssertEqual(GeometryUtils.entranceDoorID(wallEndpoints: corners.map(rotate), doors: doors), main, "rotation: \(degrees)")
            XCTAssertEqual(GeometryUtils.entranceDoorID(wallEndpoints: Array(corners.map(rotate).reversed()), doors: Array(doors.reversed())), main)
        }
    }

    func testEntranceSelectionUsesDoorWidthForBoundaryTies() {
        let first = UUID(), second = UUID()
        let points: [SIMD2<Float>] = [SIMD2(-5, -3), SIMD2(5, -3), SIMD2(5, 3), SIMD2(-5, 3)]
        let doors = [SpatialEntranceCandidate(id: first, position: SIMD2(5, 0), width: 0.8),
                     SpatialEntranceCandidate(id: second, position: SIMD2(0, -3), width: 1.2)]
        XCTAssertEqual(GeometryUtils.entranceDoorID(wallEndpoints: points, doors: doors), second)
    }

    func testVerticalTargetDragUsesTheSamePointForDisplayDistanceAndRecord() throws {
        let point = ARTargetProjection.targetPoint(detected: CGPoint(x: 0.5, y: 0.5), normalizedDrag: CGSize(width: 0, height: 0.25),
                                                   viewport: CGSize(width: 400, height: 800), marker: CGSize(width: 200, height: 150))
        XCTAssertEqual(point.y, 0.75)
        let values: [Float] = (0..<64).map { $0 / 8 < 4 ? 1 : 8 }
        let depth = ARCapturedDepth(width: 8, height: 8, values: values, confidence: nil, viewToImage: .identity)
        let pose = ARCapturePose(heading: 90, elevation: 0, projection: ARTargetProjection(horizontalFOVDegrees: 50, aspectRatio: 0.5))
        let frame = ARCapturedFrame(image: UIImage(), pose: pose, depth: depth)
        let saved = try XCTUnwrap(frame.exteriorRecord(shaID: "luchong", point: point, confidence: nil, source: .manual, note: nil))
        XCTAssertEqual(depth.sample(at: CGPoint(x: 0.5, y: 0.5 - 0.25)), 1)
        XCTAssertEqual(saved.distanceMeters, depth.sample(at: point))
        XCTAssertEqual(saved.distanceMeters, 8)
        XCTAssertLessThan(saved.elevationDegrees, 0)
    }

    func testTargetCoordinatesStayConsistentAtViewportEdgesAndAfterRotation() {
        for viewport in [CGSize(width: 400, height: 800), CGSize(width: 800, height: 400)] {
            let marker = CGSize(width: 200, height: 150)
            let point = ARTargetProjection.targetPoint(detected: CGPoint(x: 0.9, y: 0.1), normalizedDrag: CGSize(width: 0.5, height: -0.5),
                                                       viewport: viewport, marker: marker)
            XCTAssertEqual(point.x * viewport.width, viewport.width - marker.width / 2, accuracy: 0.00001)
            XCTAssertEqual(point.y * viewport.height, marker.height / 2, accuracy: 0.00001)
        }
    }

    func testTopOfImageIsPositiveElevationForPortraitAndLandscape() {
        for aspect in [0.5, 1.0, 2.0] {
            let projection = ARTargetProjection(horizontalFOVDegrees: 50, aspectRatio: aspect)
            let above = projection.elevation(point: CGPoint(x: 0.5, y: 0.25), cameraElevation: 0)
            let below = projection.elevation(point: CGPoint(x: 0.5, y: 0.75), cameraElevation: 0)
            XCTAssertGreaterThan(above, 0)
            XCTAssertLessThan(below, 0)
            XCTAssertEqual(above, -below, accuracy: 0.000001)
        }
    }

    func testCapturedRecordUsesExposurePoseAndDepthAfterPhoneTurns() throws {
        let date = instant("2026-11-08T04:00:00Z")
        let projection = ARTargetProjection(horizontalFOVDegrees: 50, aspectRatio: 0.5)
        let captured = ARCapturePose(heading: 90, elevation: 5, projection: projection)
        let current = ARCapturePose(heading: 180, elevation: -10, projection: projection)
        XCTAssertFalse(captured.isCompatible(with: current))
        let depth = ARCapturedDepth(width: 3, height: 3, values: Array(repeating: 6, count: 9), confidence: nil, viewToImage: .identity)
        let frame = ARCapturedFrame(image: UIImage(), pose: captured, depth: depth, capturedAt: date)
        let record = try XCTUnwrap(frame.exteriorRecord(shaID: "tianzhan", point: CGPoint(x: 0.5, y: 0.5), confidence: 0.8, source: .ai, note: nil))
        XCTAssertEqual(record.bearingDegrees, 90)
        XCTAssertEqual(record.elevationDegrees, 5, accuracy: 0.000001)
        XCTAssertEqual(record.distanceMeters, 6)
        XCTAssertEqual(record.capturedHeadingDegrees, 90)
        XCTAssertEqual(record.capturedAt, date)
    }

    func testAiPoseConsensusHandlesNorthSeamAndRejectsChangedViewport() {
        let projection = ARTargetProjection(horizontalFOVDegrees: 50, aspectRatio: 0.5)
        let first = ARCapturePose(heading: 359, elevation: 0, projection: projection)
        XCTAssertTrue(first.isCompatible(with: ARCapturePose(heading: 1, elevation: 1, projection: projection)))
        XCTAssertFalse(first.isCompatible(with: ARCapturePose(heading: 359, elevation: 0,
                                                              projection: ARTargetProjection(horizontalFOVDegrees: 50, aspectRatio: 2))))
    }

    func testCapturedDepthUsesNormalizedDisplayTransformAndRejectsLowConfidence() {
        let depth = ARCapturedDepth(width: 3, height: 3, values: Array(repeating: 4, count: 9),
                                    confidence: Array(repeating: 2, count: 9), viewToImage: CGAffineTransform(translationX: 0.1, y: 0.1))
        XCTAssertEqual(depth.sample(at: CGPoint(x: 0.5, y: 0.5)), 4)
        XCTAssertNil(depth.sample(at: CGPoint(x: 1, y: 1)))
        let invalid = ARCapturedDepth(width: 3, height: 3, values: Array(repeating: 4, count: 9),
                                      confidence: Array(repeating: 0, count: 9), viewToImage: .identity)
        XCTAssertNil(invalid.sample(at: CGPoint(x: 0.5, y: 0.5)))
    }

    @MainActor
    func testFloorplanExportKeepsOneCentroidAndItsMatchingAudit() {
        let language = LocalizationManager.shared.effectiveLanguage
        defer { LocalizationManager.shared.effectiveLanguage = language }
        LocalizationManager.shared.effectiveLanguage = .zhHans
        let room = FloorplanRoom(name: "书房", type: .study, rect: CGRect(x: 0.65, y: 0.45, width: 0.1, height: 0.1))
        var center = CGPoint(x: 0.5, y: 0.5)
        let report = FloorplanReportSnapshot(rooms: [room], centroid: center, heading: 0, aspectRatio: 1)
        center = CGPoint(x: 0.8, y: 0.5)
        let edited = FloorplanEngine.shared.auditFloorplan(rooms: [room], centroid: center, heading: 0)
        XCTAssertTrue(report.rooms[0].palaceName.contains("正东"))
        XCTAssertTrue(edited.auditedRooms[0].palaceName.contains("正西"))
        XCTAssertEqual(report.centroid, CGPoint(x: 0.5, y: 0.5))
    }

    @MainActor
    func testFloorplanAuditInvalidatesAtLiChunWithUnchangedGeometry() {
        let language = LocalizationManager.shared.effectiveLanguage
        defer { LocalizationManager.shared.effectiveLanguage = language }
        LocalizationManager.shared.effectiveLanguage = .zhHans
        let boundary = liChunBoundary()
        let before = boundary.addingTimeInterval(-1), after = boundary.addingTimeInterval(1)
        XCTAssertNotEqual(FloorplanAuditTimeKey(date: before), FloorplanAuditTimeKey(date: after))
        let room = FloorplanRoom(name: "书房", type: .study, rect: CGRect(x: 0.7, y: 0.4, width: 0.1, height: 0.1))
        let old = FloorplanReportSnapshot(rooms: [room], centroid: CGPoint(x: 0.5, y: 0.5), heading: 0, aspectRatio: 1, date: before)
        let new = FloorplanReportSnapshot(rooms: [room], centroid: CGPoint(x: 0.5, y: 0.5), heading: 0, aspectRatio: 1, date: after)
        XCTAssertNotEqual(old.report.map(\.lore), new.report.map(\.lore))
        XCTAssertEqual(old.date, before)
        XCTAssertEqual(new.date, after)
    }

    @MainActor
    func testOldCaptureCannotReplaceEitherArchiveAfterPropertySwitch() throws {
        let suite = "property-capture-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShaSurveyStore(defaults: defaults)
        let oldID = store.propertyID
        let measuredB = survey("RoomPlan B"), virtualB = survey("VR B")
        store.replaceProperty(measured: measuredB, virtual: virtualB, exterior: [])
        let measuredBytes = defaults.data(forKey: SpatialSurveyArchiveKeys.measured)
        let virtualBytes = defaults.data(forKey: SpatialSurveyArchiveKeys.virtual)
        XCTAssertFalse(store.saveSurvey(survey("RoomPlan A"), key: SpatialSurveyArchiveKeys.measured, propertyID: oldID))
        XCTAssertFalse(store.saveSurvey(survey("VR A"), key: SpatialSurveyArchiveKeys.virtual, propertyID: oldID))
        XCTAssertFalse(store.updateInterior(survey("projection A"), propertyID: oldID))
        XCTAssertEqual(defaults.data(forKey: SpatialSurveyArchiveKeys.measured), measuredBytes)
        XCTAssertEqual(defaults.data(forKey: SpatialSurveyArchiveKeys.virtual), virtualBytes)
        XCTAssertEqual(ShaSurveyStore(defaults: defaults).latestInterior?.id, measuredB.id)
    }

    @MainActor
    func testRepeatedCapturesAndImportsForOnePropertyKeepTheirAuthority() throws {
        let suite = "property-edit-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShaSurveyStore(defaults: defaults)
        let id = store.propertyID
        XCTAssertTrue(store.saveSurvey(survey("RoomPlan 1"), key: SpatialSurveyArchiveKeys.measured, propertyID: id))
        XCTAssertTrue(store.replaceProperty(measured: survey("RoomPlan 2"), virtual: nil, exterior: [], expectedPropertyID: id))
        XCTAssertEqual(store.propertyID, id)
        XCTAssertTrue(store.saveSurvey(survey("VR 3"), key: SpatialSurveyArchiveKeys.virtual, propertyID: id))
        store.replaceProperty(measured: nil, virtual: nil, exterior: [])
        XCTAssertNotEqual(store.propertyID, id)
        XCTAssertFalse(store.replaceProperty(measured: survey("late import"), virtual: nil, exterior: [], expectedPropertyID: id))
        XCTAssertNil(store.archive)
    }

    @MainActor
    func testOldExteriorCaptureCannotAppendToTheNewProperty() throws {
        let suite = "property-exterior-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShaSurveyStore(defaults: defaults)
        let oldID = store.propertyID
        let recordB = ExteriorShaRecord(shaID: "B", bearingDegrees: 180)
        store.replaceProperty(measured: nil, virtual: nil, exterior: [recordB])
        XCTAssertFalse(store.addRecord(ExteriorShaRecord(shaID: "A", bearingDegrees: 90), propertyID: oldID))
        XCTAssertEqual(store.records.map(\.id), [recordB.id])
    }

    @MainActor
    func testStaleRoomPlanImportDoesNotChangeTheWorkspaceOrItsGrant() {
        let store = FloorplanWorkspaceStore.shared
        let revision = store.snapshot.revision
        let id = ShaSurveyStore.shared.propertyID
        let data = UserDefaults.standard.data(forKey: FloorplanWorkspaceStore.layoutKey)
        XCTAssertFalse(FloorplanView.persistRoomPlanImport(rooms: [], centroid: .zero, blueprintImage: nil,
                                                         propertyID: UUID(), spatialSurvey: survey("old scan")))
        XCTAssertEqual(store.snapshot.revision, revision)
        XCTAssertEqual(ShaSurveyStore.shared.propertyID, id)
        XCTAssertEqual(UserDefaults.standard.data(forKey: FloorplanWorkspaceStore.layoutKey), data)
    }

    @MainActor
    func testWorkspaceRejectsAStalePropertyEvenWhenItsEditRevisionMatches() throws {
        let suite = "property-workspace-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let store = FloorplanWorkspaceStore(defaults: defaults, directory: directory)
        XCTAssertFalse(try store.save(layout: record(image: nil).layout, image: nil, writerID: UUID(),
                                      expectedRevision: store.snapshot.revision, expectedPropertyID: UUID()))
        XCTAssertNil(defaults.data(forKey: FloorplanWorkspaceStore.layoutKey))
        XCTAssertEqual(store.snapshot.revision, 0)
    }

    func testWorldMapRoundTripPreservesHandPinnedRoomsAndOrderedAnnotations() throws {
        let room = SpatialRoom3D(name: "manual", type: .study, center: SIMD3(3, 1.4, 4),
                                 size: SIMD3(4, 2.8, 3), rotationY: Float.pi / 4)
        let points: [SIMD3<Float>] = [SIMD3(1, 0, 2), SIMD3(4, 0, 2)]
        let archive = try SpatialWorldMapArchive(mapData: Data([1, 2]), coordinateHeading: 90,
            annotations: SpatialMapAnnotations(cornerRooms: [room], cornerPoints: points, lubanPoints: Array(points.reversed())))
        let restored = try SpatialWorldMapArchive.decode(JSONEncoder().encode(archive))
        let annotations = try XCTUnwrap(restored.annotations)
        XCTAssertEqual(annotations.cornerRooms.map(\.id), [room.id])
        XCTAssertEqual(annotations.cornerRooms.first?.rotationY, room.rotationY)
        XCTAssertEqual(annotations.cornerRooms.first?.center, room.center)
        XCTAssertEqual(annotations.cornerPoints.map(\.position), points)
        XCTAssertEqual(annotations.lubanPoints.map(\.position), Array(points.reversed()))
        let anchors = annotations.makeAnchors()
        XCTAssertEqual(anchors.map(\.name), ["corner-pin", "corner-pin", "luban-anchor", "luban-anchor"])
        XCTAssertEqual(anchors[0].transform.columns.3.x, points[0].x)
        XCTAssertEqual(anchors[2].transform.columns.3.z, points[1].z)
        XCTAssertEqual(restored.coordinateHeading, 90)
    }

    func testVersionOneWorldMapsStillRestoreWithoutInventingManualRooms() throws {
        let archive = try SpatialWorldMapArchive(mapData: Data([1]), coordinateHeading: 270)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(archive)) as? [String: Any])
        json["version"] = 1
        json.removeValue(forKey: "annotations")
        let restored = try SpatialWorldMapArchive.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(restored.annotations)
        XCTAssertEqual(restored.coordinateHeading, 270)
    }

    @MainActor
    func testReturningParentMustOwnItsLeaseBeforeAnotherCameraCanRun() {
        let leases = CameraExclusivity()
        let parent = CameraLeaseToken(), child = CameraLeaseToken(), other = CameraLeaseToken()
        let sceneA = NSObject(), sceneB = NSObject()
        XCTAssertTrue(leases.acquire(parent, sceneID: ObjectIdentifier(sceneA)))
        XCTAssertTrue(leases.acquire(child, sceneID: ObjectIdentifier(sceneA)))
        leases.release(parent)
        XCTAssertFalse(leases.owns(parent))
        XCTAssertTrue(leases.owns(child))
        leases.release(child)
        XCTAssertTrue(leases.acquire(other, sceneID: ObjectIdentifier(sceneB)))
        XCTAssertFalse(leases.acquire(parent, sceneID: ObjectIdentifier(sceneA)))
        XCTAssertFalse(leases.owns(parent))
        leases.release(other)
        XCTAssertTrue(leases.acquire(parent, sceneID: ObjectIdentifier(sceneA)))
        XCTAssertTrue(leases.owns(parent))
    }

    @MainActor
    func testLeaseReacquisitionFromAPublisherDoesNotRepublishRecursively() {
        let leases = CameraExclusivity()
        let token = CameraLeaseToken(), scene = NSObject()
        let sceneID = ObjectIdentifier(scene)
        var publications = 0
        let subscription = leases.$holderSceneID.sink { _ in
            publications += 1
            if leases.owns(token) { XCTAssertTrue(leases.acquire(token, sceneID: sceneID)) }
        }
        XCTAssertTrue(leases.acquire(token, sceneID: sceneID))
        XCTAssertTrue(leases.acquire(token, sceneID: sceneID))
        XCTAssertEqual(publications, 2) // initial nil and the actual acquisition
        withExtendedLifetime(subscription) { leases.release(token) }
    }

    func testDraggingARecognizedRoomMovesItsRealCentroidAndKeepsItsArea() throws {
        let rect = CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2)
        let room = FloorplanRoom(name: "room", type: .study, rect: rect,
            polygonPoints: [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.3, y: 0.1), CGPoint(x: 0.3, y: 0.3), CGPoint(x: 0.1, y: 0.3)])
        let moved = room.transformed(to: rect.offsetBy(dx: 0.4, dy: 0.2))
        let center = FloorplanEngine.roomCentroid(moved)
        XCTAssertEqual(center.x, 0.6, accuracy: 0.000001)
        XCTAssertEqual(center.y, 0.4, accuracy: 0.000001)
        XCTAssertEqual(FloorplanEngine.roomArea(moved), FloorplanEngine.roomArea(room), accuracy: 0.000001)
        XCTAssertTrue(FloorplanEngine.roomContains(moved, point: center))
        let saved = try JSONDecoder().decode(FloorplanRoom.self, from: JSONEncoder().encode(moved))
        XCTAssertEqual(saved.polygonPoints, moved.polygonPoints)
    }

    func testScalingAConcaveRoomAppliesTheSameAffineTransformToItsOutline() throws {
        let points = [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.6, y: 0.1), CGPoint(x: 0.6, y: 0.3),
                      CGPoint(x: 0.3, y: 0.3), CGPoint(x: 0.3, y: 0.6), CGPoint(x: 0.1, y: 0.6)]
        let room = FloorplanRoom(name: "L", type: .study, rect: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5), polygonPoints: points)
        let edited = room.transformed(to: CGRect(x: 0.05, y: 0.05, width: 0.8, height: 0.4))
        XCTAssertEqual(FloorplanEngine.roomArea(edited), FloorplanEngine.roomArea(room) * 1.6 * 0.8, accuracy: 0.000001)
        let bounds = try XCTUnwrap(GeometryUtils.polygonBounds(try XCTUnwrap(edited.polygonPoints)))
        XCTAssertEqual(bounds.minX, edited.rect.minX, accuracy: 0.000001)
        XCTAssertEqual(bounds.maxY, edited.rect.maxY, accuracy: 0.000001)
        XCTAssertTrue(FloorplanEngine.roomContains(edited, point: CGPoint(x: 0.05, y: 0.2))) // boundary
        XCTAssertFalse(FloorplanEngine.roomContains(edited, point: CGPoint(x: 0.8, y: 0.4))) // notch
    }

    @MainActor
    func testConcaveBoundingBoxCannotStealTheCentralRoom() {
        let language = LocalizationManager.shared.effectiveLanguage
        defer { LocalizationManager.shared.effectiveLanguage = language }
        LocalizationManager.shared.effectiveLanguage = .zhHans
        let points = [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.6, y: 0.1), CGPoint(x: 0.6, y: 0.3),
                      CGPoint(x: 0.3, y: 0.3), CGPoint(x: 0.3, y: 0.6), CGPoint(x: 0.1, y: 0.6)]
        let concave = FloorplanRoom(id: "L", name: "L", type: .study,
            rect: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5), polygonPoints: points)
        let actual = FloorplanRoom(id: "actual", name: "actual", type: .livingRoom,
            rect: CGRect(x: 0.3, y: 0.3, width: 0.65, height: 0.65))
        let result = FloorplanEngine.shared.auditFloorplan(rooms: [concave, actual], centroid: CGPoint(x: 0.5, y: 0.5), heading: 0)
        XCTAssertFalse(result.auditedRooms[0].palaceName.contains("中央"))
        XCTAssertTrue(result.auditedRooms[1].palaceName.contains("中央"))
    }

    @MainActor
    func testPolygonPalaceUsesItsActualCentroid() {
        let language = LocalizationManager.shared.effectiveLanguage
        defer { LocalizationManager.shared.effectiveLanguage = language }
        LocalizationManager.shared.effectiveLanguage = .zhHans
        let room = FloorplanRoom(name: "triangle", type: .study, rect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
            polygonPoints: [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.9, y: 0.1), CGPoint(x: 0.1, y: 0.9)])
        let result = FloorplanEngine.shared.auditFloorplan(rooms: [room], centroid: CGPoint(x: 0.5, y: 0.6), heading: 0)
        XCTAssertTrue(result.auditedRooms[0].palaceName.contains("西北"))
    }

    private func facingSurvey(door: SpatialOpening3D, explicit: Double? = nil) -> HouseSpatialSurvey {
        HouseSpatialSurveyEngine.analyzeSpatialHouse(scanMethod: "VR", walls: [], openings: [door], beams: [],
            rooms: [SpatialRoom3D(name: "room", type: .study, center: SIMD3(0, 1.4, 0), size: SIMD3(10, 2.8, 8))],
            objects: [], compassHeading: 0, centroidOverride: .zero, houseFacingDegrees: explicit)
    }

    func testVirtualEntranceCorrectionRecomputesAnAutomaticFacing() throws {
        let old = facingSurvey(door: entrance(position: SIMD3(5, 1, 0), normal: SIMD3(1, 0, 0)))
        let restored = try JSONDecoder().decode(HouseSpatialSurvey.self, from: JSONEncoder().encode(old))
        XCTAssertEqual(restored.houseFacingWasExplicit, false)
        XCTAssertNil(restored.fixedHouseFacing)
        let corrected = facingSurvey(door: entrance(position: SIMD3(0, 1, 4), normal: SIMD3(0, 0, 1)), explicit: restored.fixedHouseFacing)
        XCTAssertEqual(old.resolvedHouseFacing, 90)
        XCTAssertEqual(corrected.resolvedHouseFacing, 180)
    }

    func testVirtualEntranceCorrectionPreservesAnExplicitFacing() throws {
        let old = facingSurvey(door: entrance(position: SIMD3(5, 1, 0), normal: SIMD3(1, 0, 0)), explicit: 270)
        let restored = try JSONDecoder().decode(HouseSpatialSurvey.self, from: JSONEncoder().encode(old))
        XCTAssertEqual(restored.houseFacingWasExplicit, true)
        let corrected = facingSurvey(door: entrance(position: SIMD3(0, 1, 4), normal: SIMD3(0, 0, 1)), explicit: restored.fixedHouseFacing)
        XCTAssertEqual(corrected.resolvedHouseFacing, 270)
    }

    func testLegacyFacingSourceIsInferredFromItsOriginalEntrance() throws {
        let original = facingSurvey(door: entrance(position: SIMD3(5, 1, 0), normal: SIMD3(1, 0, 0)))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json.removeValue(forKey: "houseFacingWasExplicit")
        let restored = try JSONDecoder().decode(HouseSpatialSurvey.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(restored.fixedHouseFacing)
        json["houseFacingDegrees"] = 270
        let fixed = try JSONDecoder().decode(HouseSpatialSurvey.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(fixed.fixedHouseFacing, 270)
        var layout = record(image: nil).layout
        layout.houseFacingWasExplicit = false
        XCTAssertEqual(try JSONDecoder().decode(SavedFloorplanLayout.self, from: JSONEncoder().encode(layout)).houseFacingWasExplicit, false)
    }

    func testRolledCameraProjectsTheTargetThroughAllThreeAxes() {
        let projection = ARTargetProjection(horizontalFOVDegrees: 50, aspectRatio: 0.5)
        let pose = ARCapturePose(heading: 0, elevation: 0, projection: projection, roll: 45)
        let point = CGPoint(x: 0.5, y: 0.25)
        XCTAssertEqual(pose.bearing(point: point), 18.248902383, accuracy: 0.00001)
        XCTAssertEqual(pose.elevation(point: point), 17.387718335, accuracy: 0.00001)
        let side = ARCapturePose(heading: 0, elevation: 0, projection: projection, roll: 90)
        XCTAssertEqual(side.bearing(point: point), 25, accuracy: 0.000001)
        XCTAssertEqual(side.elevation(point: point), 0, accuracy: 0.000001)
    }

    func testAiConsensusRejectsRollWithoutAChangeInHeadingOrPitch() {
        let projection = ARTargetProjection(horizontalFOVDegrees: 50, aspectRatio: 0.5)
        let first = ARCapturePose(heading: 0, elevation: 10, projection: projection, roll: 0)
        XCTAssertFalse(first.isCompatible(with: ARCapturePose(heading: 0, elevation: 10, projection: projection, roll: 10)))
        XCTAssertTrue(first.isCompatible(with: ARCapturePose(heading: 0, elevation: 10, projection: projection, roll: 2)))
    }

    func testWorldCameraPosePreservesPitchRollAndGeographicNorth() {
        let projection = ARTargetProjection(horizontalFOVDegrees: 50, aspectRatio: 0.5)
        let local = ARCapturePose(heading: 100, elevation: 20, projection: projection, roll: 45)
        func column(_ vector: SIMD3<Double>) -> SIMD4<Float> { SIMD4(Float(vector.x), Float(vector.y), Float(vector.z), 0) }
        let matrix = simd_float4x4(columns: (column(local.right), column(local.up), column(-local.forward), SIMD4(0, 0, 0, 1)))
        let captured = ARCapturePose(worldFromCamera: matrix, coordinateHeading: 17, projection: projection)
        let expected = ARCapturePose(heading: 117, elevation: 20, projection: projection, roll: 45)
        for point in [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.8, y: 0.2), CGPoint(x: 0.2, y: 0.7)] {
            XCTAssertEqual(captured.bearing(point: point), expected.bearing(point: point), accuracy: 0.00001)
            XCTAssertEqual(captured.elevation(point: point), expected.elevation(point: point), accuracy: 0.00001)
        }
    }

    func testOffAxisBearingAccountsForCameraPitch() {
        let projection = ARTargetProjection(horizontalFOVDegrees: 60, aspectRatio: 1)
        let pose = ARCapturePose(heading: 0, elevation: 60, projection: projection)
        let rightEdge = CGPoint(x: 1, y: 0.5)
        XCTAssertEqual(pose.bearing(point: rightEdge), atan2(tan(Double.pi / 6), 0.5) * 180 / .pi, accuracy: 0.000001)
        XCTAssertLessThan(pose.elevation(point: rightEdge), pose.elevation)
    }

    func testReportGanzhiUsesGregorianYearsForBuddhistCalendarDates() {
        let date = instant("2026-11-08T04:00:00Z")
        let zone = TimeZone(secondsFromGMT: 8 * 3600)!
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = zone
        XCTAssertEqual(buddhist.component(.year, from: date), 2569)
        XCTAssertEqual(TianJiAnalysisSnapshot(heading: 0, reportDate: date).ganzhiYear(timeZone: zone), "丙午")
    }

    func testReportGanzhiChangesAtLiChunAndKeepsPreviousYearInJanuary() {
        let boundary = liChunBoundary(), zone = TimeZone(secondsFromGMT: 8 * 3600)!
        XCTAssertEqual(TianJiAnalysisSnapshot(heading: 0, reportDate: boundary.addingTimeInterval(-1)).ganzhiYear(timeZone: zone), "乙巳")
        XCTAssertEqual(TianJiAnalysisSnapshot(heading: 0, reportDate: boundary.addingTimeInterval(1)).ganzhiYear(timeZone: zone), "丙午")
        XCTAssertEqual(TianJiAnalysisSnapshot(heading: 0, reportDate: instant("2026-01-01T04:00:00Z")).ganzhiYear(timeZone: zone), "乙巳")
    }

    private func guidanceCell(mountain: Int, facing: Int, period: Int) -> PalaceCell {
        PalaceCell(id: 0, palaceName: "坎一宫", trigram: "坎", direction: "正北", periodStar: period,
                   activePeriod: period, mountainStar: mountain, facingStar: facing, isCenter: false,
                   isWangMountain: mountain == period, isWangFacing: facing == period,
                   isShaWuHuang: mountain == 5 || facing == 5, isShaErHei: mountain == 2 || facing == 2)
    }

    func testPlainSectorGuideSeparatesActivityRestAndOrdinaryUse() {
        XCTAssertEqual(guidanceCell(mountain: 9, facing: 9, period: 9).suggestedUse, .separateUses)
        XCTAssertEqual(guidanceCell(mountain: 1, facing: 9, period: 9).suggestedUse, .activity)
        XCTAssertEqual(guidanceCell(mountain: 9, facing: 1, period: 9).suggestedUse, .rest)
        XCTAssertEqual(guidanceCell(mountain: 8, facing: 1, period: 9).suggestedUse, .everyday)
        XCTAssertEqual(guidanceCell(mountain: 8, facing: 1, period: 8).suggestedUse, .rest)
        XCTAssertEqual(guidanceCell(mountain: 1, facing: 8, period: 8).suggestedUse, .activity)
    }

    func testPlainSectorGuideNeverActivatesACautionEvenInPeriodsTwoOrFive() {
        for period in 1...9 {
            for other in 1...9 {
                for caution in [2, 5] {
                    XCTAssertEqual(guidanceCell(mountain: other, facing: caution, period: period).suggestedUse, .quiet)
                    XCTAssertEqual(guidanceCell(mountain: caution, facing: other, period: period).suggestedUse, .quiet)
                }
            }
        }
    }

    @MainActor
    func testPlainPatternAndFacingSidesMatchTheActualStarsForEveryChartMode() {
        let date = instant("2026-11-09T04:00:00Z")
        let palaceIDs = ["坎": 0, "坤": 1, "震": 2, "巽": 3, "乾": 5, "兑": 6, "艮": 7, "离": 8]
        for period in 1...9 {
            for heading in stride(from: 0, to: 360, by: 15) {
                let sitting = Mountain24Data.shared.mountain(for: Double((heading + 180) % 360))
                let facing = Mountain24Data.shared.mountain(for: Double(heading))
                for useTiGua in [false, true] {
                    let chart = FlyingStarsEngine.shared.calculateChart(period: period, sitting: sitting, facing: facing,
                                                                        useTiGua: useTiGua, date: date)
                    XCTAssertEqual(chart.sittingPalaceID, palaceIDs[sitting.palace])
                    XCTAssertEqual(chart.facingPalaceID, palaceIDs[facing.palace])
                    let front = chart.palaces[chart.facingPalaceID], back = chart.palaces[chart.sittingPalaceID]
                    let expected: XuanKongPattern
                    if front.facingStar == period && back.mountainStar == period { expected = .balancedFrontBack }
                    else if front.facingStar == period && front.mountainStar == period { expected = .bothAtFacing }
                    else if back.facingStar == period && back.mountainStar == period { expected = .bothAtSitting }
                    else if back.facingStar == period && front.mountainStar == period { expected = .reversed }
                    else { expected = .distributed }
                    XCTAssertEqual(chart.pattern, expected)
                    XCTAssertEqual(chart.isTiGua, useTiGua)
                }
            }
        }
    }

    @MainActor
    func testGuidePriorityShowsCautionsBeforeActivityAndKeepsAllSectorsReachable() {
        let chart = TianJiAnalysisSnapshot(heading: 90, period: 9, useTiGua: false).flyingStarsChart()
        let ordered = chart.priorityPalaces
        XCTAssertEqual(Set(ordered.map(\.id)), Set(0..<9))
        XCTAssertEqual(ordered.count, 9)
        XCTAssertEqual(ordered.first?.suggestedUse, .quiet)
        let priorities = ordered.map { $0.suggestedUse.priority }
        XCTAssertEqual(priorities, priorities.sorted())
        let cautions = ordered.filter { $0.suggestedUse == .quiet }
        let counts = cautions.map { ($0.mountainStar == 2 || $0.mountainStar == 5 ? 1 : 0)
            + ($0.facingStar == 2 || $0.facingStar == 5 ? 1 : 0) }
        XCTAssertEqual(counts, counts.sorted(by: >))
    }

    @MainActor
    func testGuideActionsAndExplanationsAreTranslatedInEveryLanguage() {
        let manager = LocalizationManager.shared, previous = LocalizationManager.shared.effectiveLanguage
        defer { manager.effectiveLanguage = previous }
        let chart = TianJiAnalysisSnapshot(heading: 90, period: 9, useTiGua: false).flyingStarsChart()
        for language in AppLanguage.allCases where language != .auto {
            manager.effectiveLanguage = language
            var keys = XuanKongPattern.allCases.flatMap { [$0.titleKey, $0.explanationKey] }
            keys += XuanKongSectorUse.allCases.flatMap { [$0.titleKey, $0.reasonKey, $0.actionKey, $0.avoidKey] }
            keys += ["xk_guide_center", "xk_guide_front", "xk_guide_back",
                     "xk_guide_priority", "xk_guide_map", "xk_guide_terms"]
            for key in keys {
                XCTAssertFalse(manager.t(key).isEmpty, "\(language): \(key)")
                XCTAssertNotEqual(manager.t(key), key, "\(language): \(key)")
            }
            for cell in chart.palaces where !cell.isCenter {
                XCTAssertEqual(cell.plainDirectionName, Direction8(rawValue: cell.direction)?.localizedName)
            }
            XCTAssertEqual(chart.palaces[4].plainDirectionName, manager.t("xk_guide_center"))
        }
    }

    func testHouseGuidePreservesEightDirectionsAndSeparatesPersonalGua() {
        let guas = ["坎", "坤", "震", "巽", "乾", "兑", "艮", "离"]
        for sitting in guas {
            for facing in guas {
                let chart = BaZhaiEngine.shared.analyze(sittingPalace: sitting, facingPalace: facing)
                XCTAssertEqual(chart.houseGua, sitting + "宅")
                XCTAssertEqual(Set(chart.items.map(\.guaName)), Set(guas))
                XCTAssertEqual(chart.items.count, 8)
                XCTAssertEqual(chart.items.filter { $0.star.isAuspicious }.count, 4)
                XCTAssertEqual(chart.items.filter { $0.star.suggestedHouseUse == .review }.count, 4)
                XCTAssertEqual(chart.items.first { $0.guaName == sitting }?.star.suggestedHouseUse, .study)
                XCTAssertEqual(chart.gateStar, chart.items.first { $0.guaName == facing }?.star)
            }
        }
    }

    @MainActor
    func testAnalysisMenuHasDistinctFeaturesAndAnExplicitOwnerVipRequirement() {
        let manager = LocalizationManager.shared, previous = LocalizationManager.shared.effectiveLanguage
        defer { manager.effectiveLanguage = previous }
        XCTAssertEqual(AnalysisFeature.allCases.count, 7)
        XCTAssertTrue(AnalysisFeature.owner.requiresVIP)
        XCTAssertTrue(AnalysisFeature.sanHe.requiresVIP)
        XCTAssertFalse(AnalysisFeature.dates.requiresVIP)
        XCTAssertFalse(AnalysisFeature.baZhai.requiresVIP)
        for language in AppLanguage.allCases where language != .auto {
            manager.effectiveLanguage = language
            for feature in AnalysisFeature.allCases {
                XCTAssertNotEqual(manager.t(feature.titleKey), feature.titleKey)
                XCTAssertNotEqual(manager.t(feature.subtitleKey), feature.subtitleKey)
            }
            for use in BaZhaiSuggestedUse.allCases {
                for key in [use.titleKey, use.actionKey, use.avoidKey] {
                    XCTAssertNotEqual(manager.t(key), key)
                    XCTAssertFalse(manager.t(key).isEmpty)
                }
            }
            XCTAssertNotEqual(manager.t("bz_owner_vip_desc"), "bz_owner_vip_desc")
        }
    }

    func testLegacyAnalysisRoutesStillResolveToTheRightMenuFeature() {
        XCTAssertEqual(AnalysisFeature.fromLegacySubTab(0), .xuanKong)
        XCTAssertEqual(AnalysisFeature.fromLegacySubTab(1), .baZhai)
        XCTAssertEqual(AnalysisFeature.fromLegacySubTab(2), .purpleWhite)
        XCTAssertEqual(AnalysisFeature.fromLegacySubTab(3), .qimen)
        XCTAssertNil(AnalysisFeature.fromLegacySubTab(-1))
        XCTAssertNil(AnalysisFeature.fromLegacySubTab(4))
        XCTAssertNotEqual(AnalysisFeature.baZhai, .sanHe)
    }

    @MainActor
    func testMenuRoutesSurviveUntilConsumedAndCanOpenTheSameFeatureAgain() throws {
        let router = AppNavigationRouter()
        for feature in AnalysisFeature.allCases {
            router.requestRoute(tab: 3, feature: feature)
            XCTAssertEqual(router.pendingTabRoute?.feature, feature)
            let route = try XCTUnwrap(router.consumeTabRoute())
            XCTAssertEqual(route.tab, 3)
            XCTAssertEqual(route.feature, feature)
            XCTAssertNil(router.consumeTabRoute())
            router.requestRoute(tab: 3, feature: feature)
            XCTAssertEqual(router.consumeTabRoute()?.feature, feature)
        }
        XCTAssertNotEqual(AnalysisFeatureRequest(feature: .dates).id, AnalysisFeatureRequest(feature: .dates).id)
    }

    @MainActor
    func testIndependentToolsAndDatePosterKeepTheOpeningHouseOrientation() {
        var live = Mountain24Data.shared.resolveHeadingState(heading: 94)
        let request = AnalysisToolRequest(tool: .dates, context: live)
        live = Mountain24Data.shared.resolveHeadingState(heading: 184)
        let card = DailyAuspiciousCardSheet(targetDate: instant("2026-11-09T04:00:00Z"), headingState: request.context)
        XCTAssertEqual(request.context.facingAngle, 94, accuracy: 0.000001)
        XCTAssertEqual(card.headingState.facingAngle, request.context.facingAngle)
        XCTAssertEqual(card.headingState.sittingMountain.id, request.context.sittingMountain.id)
        XCTAssertNotEqual(card.headingState.sittingMountain.id, live.sittingMountain.id)
    }

    private func deepLayout(rooms: [FloorplanRoom], heading: Double = 0, facing: Double = 180,
                            aspectRatio: Double = 1) -> SavedFloorplanLayout {
        SavedFloorplanLayout(rooms: rooms, centroidX: 0.5, centroidY: 0.5,
            compassRotation: heading, isSyncWithCompass: false, hasFloorplanAccess: false,
            floorplanAccessGrantID: nil, floorplanAccessGrantSignature: nil,
            aspectRatio: aspectRatio, houseFacingDegrees: facing)
    }

    @MainActor
    private func deepChart(mountain: Int = 1, facing: Int = 9, sanban: Bool = false) -> XuanKongChart {
        let base = TianJiAnalysisSnapshot(heading: 180, period: 9, useTiGua: false).flyingStarsChart()
        return XuanKongChart(period: 9, sittingMountain: base.sittingMountain, facingMountain: base.facingMountain,
            patternType: base.patternType, pattern: base.pattern, sittingPalaceID: base.sittingPalaceID,
            facingPalaceID: base.facingPalaceID, isSanBanGua: sanban, isQiXingDaJie: false,
            isTiGua: false, chartModeTitle: base.chartModeTitle,
            palaces: [guidanceCell(mountain: mountain, facing: facing, period: 9)],
            summaryAnalysis: base.summaryAnalysis, patternDesc: base.patternDesc, periodMeta: base.periodMeta)
    }

    private func deepTime(year: Int = 1, month: Int = 1) -> PurpleWhiteChart {
        PurpleWhiteChart(year: 2026, month: 11, yearCentralStar: year, monthCentralStar: month,
            currentFacingPalace: 1, taiSuiDescription: "", suiPoDescription: "", sanShaDescription: "",
            palaceItems: (1...9).map { id in
                PurpleWhitePalaceItem(palaceId: id, palaceName: "", direction: "", originalStar: id,
                    yearGuestStar: year, monthGuestStar: month, starName: "", isDanger25: false,
                    isTaiSui: false, isSuiPo: false, isSanSha: false, advice: "")
            })
    }

    func testAllEightyOneOrderedPairsHaveReciprocalElementRelations() {
        var counts = [Int](repeating: 0, count: 5)
        for a in 1...9 {
            for b in 1...9 {
                let relation = XuanKongStarPair(first: a, second: b).relation
                let reverse = XuanKongStarPair(first: b, second: a).relation
                switch relation {
                case .same: counts[0] += 1; XCTAssertEqual(reverse, .same)
                case .firstGeneratesSecond: counts[1] += 1; XCTAssertEqual(reverse, .secondGeneratesFirst)
                case .secondGeneratesFirst: counts[2] += 1; XCTAssertEqual(reverse, .firstGeneratesSecond)
                case .firstControlsSecond: counts[3] += 1; XCTAssertEqual(reverse, .secondControlsFirst)
                case .secondControlsFirst: counts[4] += 1; XCTAssertEqual(reverse, .firstControlsSecond)
                }
            }
        }
        XCTAssertEqual(counts, [19, 15, 15, 16, 16])
        XCTAssertEqual(XuanKongStarPair(first: 1, second: 4).relation, .firstGeneratesSecond)
        XCTAssertEqual(XuanKongStarPair(first: 9, second: 6).relation, .firstControlsSecond)
    }

    func testDeepSectorMappingUsesCenteredSectorsAndHandlesWraparound() {
        XCTAssertEqual(XuanKongDeepAnalyzer.palaceID(bearing: -1), 0)
        XCTAssertEqual(XuanKongDeepAnalyzer.palaceID(bearing: 22.499), 0)
        XCTAssertEqual(XuanKongDeepAnalyzer.palaceID(bearing: 22.5), 7)
        XCTAssertEqual(XuanKongDeepAnalyzer.palaceID(bearing: 360), 0)
        XCTAssertNil(XuanKongDeepAnalyzer.palaceID(bearing: .nan))
        for (angle, id) in zip(stride(from: 0, to: 360, by: 45), [0, 7, 2, 3, 8, 1, 6, 5]) {
            XCTAssertEqual(XuanKongDeepAnalyzer.palaceID(bearing: Double(angle)), id)
        }
    }

    func testRoomCoverageSpansSectorsWithoutInventingBedOrStovePositions() {
        let bedroom = FloorplanRoom(name: "wide bedroom", type: .masterBedroom,
            rect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.2))
        let home = XuanKongHomeContextBuilder.build(layout: deepLayout(rooms: [bedroom]), survey: nil,
            exterior: [], facts: [])
        XCTAssertTrue(Set(home.places.map(\.palaceID)).isSuperset(of: Set([0, 5, 7])))
        XCTAssertTrue(home.places.allSatisfy { $0.kind == .room })
        XCTAssertLessThanOrEqual(abs(home.places.reduce(0) { $0 + $1.coverage } - 100), 2)
        XCTAssertTrue(home.missingKeys.contains("xkd_missing_bed"))
        XCTAssertTrue(home.missingKeys.contains("xkd_missing_stove"))
    }

    func testBlueprintNorthAndAspectRatioBothAffectTheLocatedEntrance() {
        let door = FloorplanRoom(name: "door", type: .door,
            rect: CGRect(x: 0.59, y: 0.19, width: 0.02, height: 0.02))
        func sector(_ heading: Double, _ ratio: Double) -> Int? {
            XuanKongHomeContextBuilder.build(layout: deepLayout(rooms: [door], heading: heading, aspectRatio: ratio),
                survey: nil, exterior: [], facts: []).places.first?.palaceID
        }
        XCTAssertEqual(sector(0, 1), 0)
        XCTAssertEqual(sector(0, 3), 7)
        XCTAssertEqual(sector(90, 1), 2)
    }

    @MainActor
    func testArMarkersKeepGeographicSectorsWhenTheScanBasisRotates() {
        func home(heading: Double, bed: SIMD3<Float>) -> XuanKongHomeContext {
            let survey = HouseSpatialSurveyEngine.analyzeSpatialHouse(scanMethod: "test", walls: [], openings: [], beams: [],
                rooms: [SpatialRoom3D(name: "room", type: .masterBedroom, center: SIMD3(0, 1, 0), size: SIMD3(8, 3, 8))],
                objects: [SpatialObject3D(category: "bed", position: bed, size: SIMD3(2, 1, 2))],
                compassHeading: heading, centroidOverride: .zero, houseFacingDegrees: 180)
            return XuanKongHomeContextBuilder.build(layout: nil, survey: survey, exterior: [], facts: [])
        }
        let first = home(heading: 0, bed: SIMD3(0, 0.5, -3))
        let rotated = home(heading: 90, bed: SIMD3(-3, 0.5, 0))
        XCTAssertEqual(first.places.first { $0.kind == .bed }?.palaceID, 0)
        XCTAssertEqual(rotated.places.first { $0.kind == .bed }?.palaceID, 0)
        XCTAssertFalse(first.missingKeys.contains("xkd_missing_bed"))
    }

    @MainActor
    func testRotatedRoomCoverageUsesTheSameYawConventionAsTheSurveyGeometry() {
        let survey = HouseSpatialSurveyEngine.analyzeSpatialHouse(scanMethod: "test", walls: [], openings: [], beams: [],
            rooms: [SpatialRoom3D(name: "rotated", type: .study, center: SIMD3(0, 1, -3),
                size: SIMD3(6, 3, 1), rotationY: .pi / 4)], objects: [],
            compassHeading: 0, centroidOverride: .zero, houseFacingDegrees: 180)
        let home = XuanKongHomeContextBuilder.build(layout: nil, survey: survey, exterior: [], facts: [])
        let northeast = home.places.first { $0.palaceID == 7 }?.coverage ?? 0
        let northwest = home.places.first { $0.palaceID == 5 }?.coverage ?? 0
        XCTAssertGreaterThan(northeast, northwest)
    }

    @MainActor
    func testConflictingSurveyFacingDoesNotContaminateBlueprintMarkers() {
        let door = entrance(position: SIMD3(0, 1, -4), normal: SIMD3(0, 0, -1))
        let survey = facingSurvey(door: door, explicit: 180)
        let exterior = ExteriorShaRecord(shaID: "luchong", bearingDegrees: 90)
        let home = XuanKongHomeContextBuilder.build(layout: deepLayout(rooms: [], facing: 0),
            survey: survey, exterior: [exterior], facts: [])
        XCTAssertTrue(home.warningKeys.contains("xkd_orientation_conflict"))
        XCTAssertFalse(home.places.contains { $0.kind == .entrance })
        XCTAssertEqual(home.exterior, [exterior])
    }

    @MainActor
    func testYearAndMonthCautionsOverrideAnActiveNatalSector() throws {
        let chart = deepChart()
        let date = instant("2026-11-09T04:00:00Z")
        let original = XuanKongDeepAnalyzer.analyze(chart: chart, date: date, temporal: deepTime())
        XCTAssertEqual(original.sectors.first?.use, .activity)
        for star in [2, 5] {
            for time in [deepTime(year: star), deepTime(month: star)] {
                let sector = try XCTUnwrap(XuanKongDeepAnalyzer.analyze(chart: chart, date: date, temporal: time).sectors.first)
                XCTAssertEqual(sector.use, .quiet)
                XCTAssertTrue(sector.actions.contains(.reduceNoise))
                XCTAssertFalse(sector.actions.contains(.study))
                XCTAssertTrue(sector.reasonKeys.contains("xkd_reason_season"))
            }
        }
    }

    @MainActor
    func testSeasonalStarsJoinTheCorrectLuoShuPalaceWithoutReversingTheGrid() {
        let chart = TianJiAnalysisSnapshot(heading: 180, period: 9).flyingStarsChart()
        let date = instant("2026-11-09T04:00:00Z")
        let temporal = PurpleWhiteEngine.shared.calculateChart(date: date)
        let analysis = XuanKongDeepAnalyzer.analyze(chart: chart, date: date)
        for sector in analysis.sectors {
            let guest = temporal.palaceItems.first { $0.palaceId == sector.palaceID + 1 }
            XCTAssertEqual(sector.yearStar, guest?.yearGuestStar)
            XCTAssertEqual(sector.monthStar, guest?.monthGuestStar)
        }
    }

    @MainActor
    func testDeepAnalysisRecomputesAtLiChunAndWithinMonthSolarBoundaries() {
        let chart = deepChart()
        let spring = liChunBoundary()
        let before = XuanKongDeepAnalyzer.analyze(chart: chart, date: spring.addingTimeInterval(-1))
        let after = XuanKongDeepAnalyzer.analyze(chart: chart, date: spring.addingTimeInterval(1))
        XCTAssertNotEqual(before.sectors.first?.yearStar, after.sectors.first?.yearStar)
        var low = instant("2026-11-06T00:00:00Z"), high = instant("2026-11-09T00:00:00Z")
        while high.timeIntervalSince(low) > 0.01 {
            let middle = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
            if SolarTimeCalculator.shared.solarTermIndex(for: middle) < 20 { low = middle } else { high = middle }
        }
        let old = XuanKongDeepAnalyzer.analyze(chart: chart, date: high.addingTimeInterval(-1))
        let new = XuanKongDeepAnalyzer.analyze(chart: chart, date: high.addingTimeInterval(1))
        XCTAssertNotEqual(old.sectors.first?.monthStar, new.sectors.first?.monthStar)
        XCTAssertEqual(chart.period, 9)
    }

    @MainActor
    func testObservedSleepNeedsOverrideActivityAndActionsAreDeduplicated() throws {
        let context = XuanKongHomeContext(places: [XuanKongLocatedPlace(id: "bed", palaceID: 0, name: "bed",
            kind: .bed, roomType: nil)], facts: [XuanKongSiteFact(palaceID: 0, kind: .glare)])
        let result = XuanKongDeepAnalyzer.analyze(chart: deepChart(), date: Date(), context: context, temporal: deepTime())
        let sector = try XCTUnwrap(result.sectors.first)
        XCTAssertEqual(sector.use, .rest)
        XCTAssertTrue(sector.actions.contains(.protectSleep))
        XCTAssertEqual(sector.actions.first, .reduceGlare)
        XCTAssertFalse(sector.actions.contains(.study))
        XCTAssertEqual(Set(sector.actions).count, sector.actions.count)
    }

    @MainActor
    func testBathroomNeverBecomesAStudyThroughAnAuspiciousPair() throws {
        let context = XuanKongHomeContext(places: [XuanKongLocatedPlace(id: "bath", palaceID: 0, name: "bath",
            kind: .room, roomType: .bathroom)])
        let result = XuanKongDeepAnalyzer.analyze(chart: deepChart(mountain: 1, facing: 4), date: Date(),
            context: context, temporal: deepTime())
        let sector = try XCTUnwrap(result.sectors.first)
        XCTAssertTrue(sector.actions.contains(.wetRoom))
        XCTAssertFalse(sector.actions.contains(.study))
    }

    @MainActor
    func testKitchenAndMissingCornerDoNotReceiveSeatOrFurnitureInstructions() throws {
        let kitchen = XuanKongHomeContext(places: [XuanKongLocatedPlace(id: "kitchen", palaceID: 0, name: "kitchen",
            kind: .room, roomType: .kitchen)])
        let resting = XuanKongDeepAnalyzer.analyze(chart: deepChart(mountain: 9, facing: 1), date: Date(),
            context: kitchen, temporal: deepTime())
        XCTAssertTrue(resting.sectors.first?.actions.contains(.kitchen) == true)
        XCTAssertFalse(resting.sectors.first?.actions.contains(.rest) == true)
        let missing = XuanKongHomeContext(places: [XuanKongLocatedPlace(id: "corner", palaceID: 0, name: "corner",
            kind: .room, roomType: .missingCorner)])
        let absent = XuanKongDeepAnalyzer.analyze(chart: deepChart(), date: Date(), context: missing, temporal: deepTime())
        XCTAssertEqual(try XCTUnwrap(absent.sectors.first).actions, [.verifyCorner])
    }

    @MainActor
    func testQuietSectorWithRecordedWaterProducesReviewInsteadOfActivation() throws {
        let context = XuanKongHomeContext(facts: [XuanKongSiteFact(palaceID: 0, kind: .movingWater),
            XuanKongSiteFact(palaceID: 0, kind: .noise)])
        let result = XuanKongDeepAnalyzer.analyze(chart: deepChart(), date: Date(), context: context, temporal: deepTime(year: 5))
        let sector = try XCTUnwrap(result.sectors.first)
        XCTAssertEqual(sector.use, .quiet)
        XCTAssertTrue(sector.actions.contains(.waterReview))
        XCTAssertEqual(Set(sector.actions).count, sector.actions.count)
    }

    @MainActor
    func testObservedProblemsTakePriorityOverUnoccupiedStarCautions() throws {
        let chart = TianJiAnalysisSnapshot(heading: 0, period: 9).flyingStarsChart()
        let context = XuanKongHomeContext(facts: [XuanKongSiteFact(palaceID: 8, kind: .blockedAccess)])
        let result = XuanKongDeepAnalyzer.analyze(chart: chart, date: Date(), context: context, temporal: deepTime())
        XCTAssertEqual(result.priorities.first?.palaceID, 8)
        XCTAssertEqual(result.priorities.first?.actions.first, .clearAccess)
        XCTAssertEqual(result.summaryKey, "xkd_summary_observed")
    }

    @MainActor
    func testExteriorDistanceChangesReviewPriorityWithoutRotatingItsBearing() throws {
        func sector(distance: Float) throws -> XuanKongSectorAnalysis {
            let context = XuanKongHomeContext(exterior: [ExteriorShaRecord(shaID: "luchong", bearingDegrees: 0,
                distanceMeters: distance)])
            return try XCTUnwrap(XuanKongDeepAnalyzer.analyze(chart: deepChart(), date: Date(),
                context: context, temporal: deepTime()).sectors.first)
        }
        let near = try sector(distance: 10), far = try sector(distance: 200)
        XCTAssertEqual(near.palaceID, far.palaceID)
        XCTAssertLessThan(near.priority, far.priority)
        XCTAssertTrue(near.actions.contains(.exteriorTraffic))
        XCTAssertTrue(far.actions.contains(.exteriorTraffic))
    }

    @MainActor
    func testSpecialPatternChecksChangeWithRecordedConditions() throws {
        let chart = deepChart(sanban: true)
        let date = Date()
        let empty = XuanKongDeepAnalyzer.analyze(chart: chart, date: date, temporal: deepTime())
        XCTAssertEqual(empty.patternChecks.first?.statusKey, "xkd_pattern_unknown")
        let context = XuanKongHomeContext(facts: [XuanKongSiteFact(palaceID: 0, kind: .openBright)])
        let partial = XuanKongDeepAnalyzer.analyze(chart: chart, date: date, context: context, temporal: deepTime())
        XCTAssertEqual(partial.patternChecks.first?.statusKey, "xkd_pattern_partial")
        let noisy = XuanKongHomeContext(facts: [XuanKongSiteFact(palaceID: 0, kind: .noise)])
        let conflict = XuanKongDeepAnalyzer.analyze(chart: chart, date: date, context: noisy, temporal: deepTime())
        XCTAssertEqual(conflict.patternChecks.first?.statusKey, "xkd_pattern_conflict")
        XCTAssertTrue(conflict.sectors.first?.actions.contains(.sanban) == true)
    }

    @MainActor
    func testSevenStarGroupsProduceLinkedActionsOnlyForTheirActualPalaces() {
        var checked = 0
        for period in 1...9 {
            for heading in stride(from: 0, to: 360, by: 15) {
                let chart = TianJiAnalysisSnapshot(heading: Double(heading), period: period, useTiGua: false).flyingStarsChart()
                guard chart.isQiXingDaJie else { continue }
                checked += 1
                let groups = XuanKongDeepAnalyzer.qiXingSectorGroups(chart: chart)
                XCTAssertFalse(groups.isEmpty)
                let linked = Set(groups.flatMap { $0 })
                let result = XuanKongDeepAnalyzer.analyze(chart: chart, date: Date(), temporal: deepTime())
                for sector in result.sectors {
                    XCTAssertEqual(sector.actions.contains(.qixing), linked.contains(sector.id))
                }
                for check in result.patternChecks where check.id.hasPrefix("qixing") {
                    XCTAssertEqual(check.palaceIDs.count, 3)
                }
            }
        }
        XCTAssertGreaterThan(checked, 0)
    }

    func testSiteFactsPersistAndCannotLeakAcrossAPropertySwitch() throws {
        let suite = "site-facts-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShaSurveyStore(defaults: defaults), oldProperty = store.propertyID
        store.setSiteFact(.noise, palaceID: 0, present: true, propertyID: oldProperty)
        store.setSiteFact(.noise, palaceID: 0, present: true, propertyID: oldProperty)
        XCTAssertEqual(store.siteFacts.count, 1)
        XCTAssertEqual(ShaSurveyStore(defaults: defaults).siteFacts, store.siteFacts)
        store.replaceProperty(measured: nil, virtual: nil, exterior: [])
        store.setSiteFact(.movingWater, palaceID: 0, present: true, propertyID: oldProperty)
        XCTAssertTrue(store.siteFacts.isEmpty)
        let restored = [XuanKongSiteFact(palaceID: 2, kind: .solidBacking)]
        store.replaceProperty(measured: nil, virtual: nil, exterior: [], siteFacts: restored)
        XCTAssertEqual(ShaSurveyStore(defaults: defaults).siteFacts, restored)
    }

    func testCaseBackupKeepsSiteFactsAndOldCasesStillDecode() throws {
        var record = FloorplanCaseRecord(id: "case", title: "home", createdAt: Date(), sittingSummary: "",
            layout: deepLayout(rooms: []))
        record.siteFacts = [XuanKongSiteFact(palaceID: 8, kind: .openBright)]
        let data = try JSONEncoder().encode(record)
        XCTAssertEqual(try JSONDecoder().decode(FloorplanCaseRecord.self, from: data).siteFacts, record.siteFacts)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "siteFacts")
        XCTAssertNil(try JSONDecoder().decode(FloorplanCaseRecord.self, from: JSONSerialization.data(withJSONObject: json)).siteFacts)
    }

    @MainActor
    func testDeepActionsAndFactsHaveTranslationsInAllLanguages() {
        let manager = LocalizationManager.shared, previous = LocalizationManager.shared.effectiveLanguage
        defer { manager.effectiveLanguage = previous }
        let keys = XuanKongPracticalAction.allCases.map(\.textKey)
            + XuanKongSiteFactKind.allCases.map(\.titleKey)
            + XuanKongStarPair.Relation.allCases.map(\.titleKey)
        for language in AppLanguage.allCases where language != .auto {
            manager.effectiveLanguage = language
            for key in keys {
                XCTAssertFalse(manager.t(key).isEmpty)
                XCTAssertNotEqual(manager.t(key), key)
            }
        }
    }

    func testSourceNotesDistinguishASingleFiveFromActualDoubleFiveAndTwoFivePairs() {
        let single = TraditionalEvidenceCatalog.pair(5, 1, context: "mountain/facing")
        XCTAssertTrue(single.contains { $0.id == "stars.five" })
        XCTAssertFalse(single.contains { $0.id == "pair.five_five" || $0.id == "pair.two_five" })
        let doubled = TraditionalEvidenceCatalog.pair(5, 5, context: "year/month")
        XCTAssertTrue(doubled.contains { $0.id == "pair.five_five" })
        XCTAssertFalse(doubled.contains { $0.id == "pair.two_five" || $0.id == "stars.two" })
        for stars in [(2, 5), (5, 2)] {
            let pair = TraditionalEvidenceCatalog.pair(stars.0, stars.1, context: "year/month")
            XCTAssertTrue(pair.contains { $0.id == "pair.two_five" })
            XCTAssertFalse(pair.contains { $0.id == "pair.five_five" })
        }
    }

    @MainActor
    func testOneSixSourceAndEvaluationUseMetalWaterRatherThanWaterWood() throws {
        let references = TraditionalEvidenceCatalog.pair(1, 6, context: "N")
        let generating = try XCTUnwrap(references.first { $0.id == "elements.generating" })
        XCTAssertEqual(generating.quotes, ["金生水"])
        XCTAssertEqual(generating.sourceURL, TraditionalEvidenceCatalog.elementsURL)
        let manager = LocalizationManager.shared, previous = LocalizationManager.shared.effectiveLanguage
        defer { manager.effectiveLanguage = previous }
        for language in AppLanguage.allCases where language != .auto {
            manager.effectiveLanguage = language
            XCTAssertEqual(guidanceCell(mountain: 1, facing: 6, period: 9).localizedEvaluationSummary,
                           manager.t("ref_pair_one_six"))
        }
    }

    func testTheSameBookSectionSelectsDifferentExcerptsForDifferentPairs() throws {
        let wood = try XCTUnwrap(TraditionalEvidenceCatalog.pair(3, 7, context: "N").first { $0.id == "elements.controlling" })
        let metal = try XCTUnwrap(TraditionalEvidenceCatalog.pair(7, 9, context: "N").first { $0.id == "elements.controlling" })
        XCTAssertEqual(wood.sourceURL, metal.sourceURL)
        XCTAssertEqual(wood.quotes, ["金剋木"])
        XCTAssertEqual(metal.quotes, ["火剋金"])
        XCTAssertNotEqual(wood.matches, metal.matches)
    }

    func testEveryStarPairSourceHasItsOwnMatchAndOnlyVerifiedEntriesHaveQuotations() {
        for first in 1...9 {
            for second in 1...9 {
                let references = TraditionalEvidenceCatalog.pair(first, second, context: "selected")
                XCTAssertFalse(references.isEmpty)
                XCTAssertEqual(Set(references.map(\.id)).count, references.count)
                for reference in references {
                    XCTAssertEqual(reference.matches, ["selected \(first)/\(second)"])
                    if reference.kind == .classic {
                        XCTAssertEqual(reference.sourceURL, TraditionalEvidenceCatalog.elementsURL)
                        XCTAssertFalse(reference.quotes.isEmpty)
                    } else {
                        XCTAssertNil(reference.sourceURL)
                        XCTAssertTrue(reference.quotes.isEmpty)
                    }
                }
            }
        }
    }

    @MainActor
    func testChangingSelectedPalaceChangesTheSourceMatchesWithoutRebuildingTheChart() {
        let chart = TianJiAnalysisSnapshot(heading: 180, period: 9, useTiGua: false).flyingStarsChart()
        var matches: Set<String> = []
        for cell in chart.palaces {
            let references = chart.sourceReferences(palaceID: cell.id)
            let pairReferences = references.filter { $0.id.hasPrefix("elements.") || $0.id.hasPrefix("pair.") || $0.id.hasPrefix("stars.") }
            let expected = cell.plainDirectionName + " · " + LocalizationManager.shared.t("xkd_pair_natal")
                + " \(cell.mountainStar)/\(cell.facingStar)"
            XCTAssertFalse(pairReferences.isEmpty)
            for reference in pairReferences { XCTAssertEqual(reference.matches, [expected]) }
            matches.insert(expected)
            XCTAssertTrue(cell.localizedEvaluation.contains(expected))
        }
        XCTAssertEqual(matches.count, 9)
    }

    @MainActor
    func testChartSourcesContainOnlyTheCurrentPatternInsteadOfAllFourStockJudgments() {
        var patterns: Set<Int> = []
        for period in 1...9 {
            for heading in stride(from: 0, to: 360, by: 45) {
                let chart = TianJiAnalysisSnapshot(heading: Double(heading), period: period, useTiGua: false).flyingStarsChart()
                let source = chart.patternSourceReferences.filter { $0.id.hasPrefix("pattern.") && $0.id != "pattern.sanban" && $0.id != "pattern.qixing" }
                XCTAssertEqual(source.map(\.id), ["pattern.\(chart.pattern.rawValue)"])
                XCTAssertTrue(chart.analysisNote.contains(LocalizationManager.shared.t(chart.pattern.explanationKey)))
                patterns.insert(chart.pattern.rawValue)
            }
        }
        XCTAssertGreaterThan(patterns.count, 1)
    }

    @MainActor
    func testGuestSourceMatchesChangeWithTheYearMonthPairOnTheSameNatalChart() {
        let chart = deepChart()
        let first = chart.sourceReferences(palaceID: 0, yearStar: 2, monthStar: 5)
        let next = chart.sourceReferences(palaceID: 0, yearStar: 2, monthStar: 6)
        XCTAssertTrue(first.contains { $0.id == "pair.two_five" })
        XCTAssertFalse(first.contains { $0.id == "pair.five_five" })
        XCTAssertFalse(next.contains { $0.id == "pair.two_five" })
        XCTAssertTrue(next.contains { $0.id == "pair.one_six" })
        let cross = chart.sourceReferences(palaceID: 0, yearStar: 3, monthStar: 7)
        XCTAssertTrue(cross.contains { $0.id == "pair.three_seven" })
        XCTAssertTrue(cross.contains { $0.id == "pair.seven_nine" })
        XCTAssertFalse(next.contains { $0.id == "pair.three_seven" || $0.id == "pair.seven_nine" })
    }

    @MainActor
    func testInvalidGuestNumbersDoNotInventSourcesAndUnknownPalaceDoesNotReuseLastSources() {
        let chart = deepChart()
        let original = chart.sourceReferences(palaceID: 0)
        let invalid = chart.sourceReferences(palaceID: 0, yearStar: 0, monthStar: 10)
        XCTAssertEqual(original.map(\.localizedText), invalid.map(\.localizedText))
        XCTAssertTrue(chart.sourceReferences(palaceID: -1, yearStar: 2, monthStar: 5).isEmpty)
        XCTAssertTrue(TraditionalEvidenceCatalog.pair(0, 5, context: "unknown").isEmpty)
    }

    func testPurpleWhiteSourcesFollowTheAdviceBranchAndActualGuestNumbers() {
        let wealth = TraditionalEvidenceCatalog.purpleWhite(year: 8, month: 1, palace: "N")
        XCTAssertTrue(wealth.contains { $0.titleKey == "ref_year_eight" })
        XCTAssertFalse(wealth.contains { $0.id == "stars.five" || $0.titleKey == "ref_year_nine" })
        let caution = TraditionalEvidenceCatalog.purpleWhite(year: 8, month: 2, palace: "N")
        XCTAssertTrue(caution.contains { $0.id == "stars.two" })
        XCTAssertFalse(caution.contains { $0.titleKey == "ref_year_eight" || $0.id == "stars.five" })
        let joy = TraditionalEvidenceCatalog.purpleWhite(year: 9, month: 1, palace: "N")
        XCTAssertTrue(joy.contains { $0.titleKey == "ref_year_nine" })
        XCTAssertFalse(joy.contains { $0.titleKey == "ref_year_eight" || $0.id == "pair.five_five" })
        let cautionOverJoy = TraditionalEvidenceCatalog.purpleWhite(year: 9, month: 5, palace: "N")
        XCTAssertFalse(cautionOverJoy.contains { $0.titleKey == "ref_year_nine" })
    }

    func testEightMansionsSourcesSelectOneStarInsteadOfRepeatingAllEight() {
        let sources = StarLuckType.allCases.map(\.sourceReference)
        XCTAssertEqual(Set(sources.map(\.id)).count, 8)
        XCTAssertEqual(Set(sources.map(\.titleKey)).count, 8)
        for star in StarLuckType.allCases {
            let source = star.sourceReference
            XCTAssertEqual(source.matches, [star.localizedName])
            XCTAssertEqual(source.kind, .rule)
            XCTAssertTrue(source.quotes.isEmpty)
            XCTAssertNil(source.sourceURL)
        }
    }

    func testQimenSourcesFollowTheSelectedGateInsteadOfListingAllEight() {
        for (names, key) in [(["休门", "生门", "开门"], "ref_qimen_good"),
                             (["死门", "惊门", "伤门"], "ref_qimen_bad"),
                             (["杜门", "景门"], "ref_qimen_neutral")] {
            for name in names {
                let door = QimenDoor(name: name, palace: 6, isAuspicious: key == "ref_qimen_good", luckType: "", lore: "")
                XCTAssertEqual(door.sourceReference.titleKey, key)
                XCTAssertEqual(door.sourceReference.matches, [door.localizedName + " · 6"])
                XCTAssertEqual(door.sourceReference.kind, .rule)
                XCTAssertTrue(door.sourceReference.quotes.isEmpty)
                XCTAssertTrue(door.localizedLore.contains(door.sourceReference.localizedText))
            }
        }
    }

    @MainActor
    func testHuangQuanReferencesFollowFacingAndNonMatchingDirectionsUseTheirOwnRule() {
        let groups = [(Set(["庚", "丁", "坤"]), "ref_hq_kun"), (Set(["乙", "丙", "巽"]), "ref_hq_xun"),
                      (Set(["甲", "癸", "艮"]), "ref_hq_gen"), (Set(["辛", "壬", "乾"]), "ref_hq_qian")]
        for heading in stride(from: 0, to: 360, by: 15) {
            let mountain = Mountain24Data.shared.mountain(for: Double(heading))
            let result = SanHeWaterEngine.shared.resolveHuangQuanWater(facing: mountain)
            let expected = groups.first { $0.0.contains(mountain.name) }?.1 ?? "ref_hq_other"
            XCTAssertEqual(result.sourceReference.titleKey, expected)
            XCTAssertTrue(result.waterDesc.contains(result.sourceReference.localizedText))
            XCTAssertEqual(result.sourceReference.matches, [mountain.name + " · " + result.badgeText])
        }
    }

    @MainActor
    func testBaShaReferencesTrackTheCurrentSittingTrigramAndMatchedBranch() {
        var ids: Set<String> = []
        for heading in stride(from: 0, to: 360, by: 45) {
            let mountain = Mountain24Data.shared.mountain(for: Double(heading))
            let result = SanHeWaterEngine.shared.resolveBaSha(sitting: mountain)
            XCTAssertEqual(result.sourceReference.matches, [mountain.name + " · " + mountain.palace + " → " + result.shaZhi])
            XCTAssertTrue(result.lore.contains(result.sourceReference.localizedText))
            ids.insert(result.sourceReference.id)
        }
        XCTAssertEqual(ids.count, 8)
    }

    @MainActor
    func testSpecialPatternReferencesAppearOnlyForTheCurrentlyMatchedPatternsAndGroups() {
        var checked = 0
        for period in 1...9 {
            for heading in stride(from: 0, to: 360, by: 15) {
                let chart = TianJiAnalysisSnapshot(heading: Double(heading), period: period, useTiGua: false).flyingStarsChart()
                XCTAssertEqual(chart.patternSourceReferences.contains { $0.id == "pattern.sanban" }, chart.isSanBanGua)
                XCTAssertEqual(chart.patternSourceReferences.contains { $0.id == "pattern.qixing" }, chart.isQiXingDaJie)
                guard chart.isQiXingDaJie else { continue }
                checked += 1
                let linked = Set(XuanKongDeepAnalyzer.qiXingSectorGroups(chart: chart).flatMap { $0 })
                for cell in chart.palaces {
                    XCTAssertEqual(chart.sourceReferences(palaceID: cell.id).contains { $0.id == "pattern.qixing" }, linked.contains(cell.id))
                }
            }
        }
        XCTAssertGreaterThan(checked, 0)
    }

    @MainActor
    func testSourceMatchesRefreshAcrossLiChunWithTheSameNatalChart() throws {
        let boundary = liChunBoundary()
        let natal = TianJiAnalysisSnapshot(heading: 180, period: 9, useTiGua: false).flyingStarsChart()
        let before = PurpleWhiteEngine.shared.calculateChart(date: boundary.addingTimeInterval(-1))
        let after = PurpleWhiteEngine.shared.calculateChart(date: boundary.addingTimeInterval(1))
        let old = try XCTUnwrap(before.palaceItems.first { $0.palaceId == 1 })
        let new = try XCTUnwrap(after.palaceItems.first { $0.palaceId == 1 })
        let oldSources = natal.sourceReferences(palaceID: 0, yearStar: old.yearGuestStar, monthStar: old.monthGuestStar)
        let newSources = natal.sourceReferences(palaceID: 0, yearStar: new.yearGuestStar, monthStar: new.monthGuestStar)
        XCTAssertNotEqual(oldSources.map(\.localizedText), newSources.map(\.localizedText))
        XCTAssertNotEqual(old.sourceReferences.map(\.localizedText), new.sourceReferences.map(\.localizedText))
    }

    func testSourceDeduplicationPreservesAllMatchingPairsAndDistinctExcerpts() throws {
        let first = TraditionalEvidenceCatalog.pair(1, 9, context: "mountain/year")
        let second = TraditionalEvidenceCatalog.pair(3, 7, context: "facing/month")
        let merged = TraditionalEvidenceCatalog.merged(first + second + first)
        XCTAssertEqual(Set(merged.map(\.id)).count, merged.count)
        let source = try XCTUnwrap(merged.first { $0.id == "elements.controlling" })
        XCTAssertEqual(source.quotes, ["水剋火", "金剋木"])
        XCTAssertEqual(source.matches, ["mountain/year 1/9", "facing/month 3/7"])
    }

    @MainActor
    func testDynamicSourceLabelsTranslateAndQuotationsRemainVerbatim() {
        let manager = LocalizationManager.shared, previous = LocalizationManager.shared.effectiveLanguage
        defer { manager.effectiveLanguage = previous }
        for language in AppLanguage.allCases where language != .auto {
            manager.effectiveLanguage = language
            var sources = StarLuckType.allCases.map(\.sourceReference)
            for first in 1...9 {
                for second in 1...9 { sources += TraditionalEvidenceCatalog.pair(first, second, context: "test") }
            }
            for pattern in XuanKongPattern.allCases { sources += TraditionalEvidenceCatalog.pattern(pattern, context: "test") }
            for star in 1...9 { sources += TraditionalEvidenceCatalog.purpleWhite(year: star, month: 1, palace: "test") }
            for mountain in ["庚", "乙", "甲", "辛", "子"] {
                sources.append(HuangQuanWaterResult.reference(facingMountain: mountain, badgeText: "test"))
            }
            sources.append(BaShaResult.reference(sittingMountain: "子", sittingPalace: "坎", shaZhi: "辰"))
            for name in ["休门", "死门", "杜门", "unknown"] {
                sources.append(QimenDoor(name: name, palace: 1, isAuspicious: false, luckType: "", lore: "").sourceReference)
            }
            let keys = Set(sources.map(\.titleKey) + ["ref_classic", "ref_rule", "ref_matches", "ref_read_original",
                "ref_scope_note", "ref_sanban", "ref_qixing"])
            for key in keys {
                XCTAssertNotEqual(manager.t(key), key, "\(language): \(key)")
                XCTAssertFalse(manager.t(key).isEmpty)
            }
            XCTAssertTrue(TraditionalEvidenceCatalog.text(TraditionalEvidenceCatalog.pair(1, 6, context: "test")).contains("金生水"))
        }
    }

    @MainActor
    func testReportSnapshotKeepsHouseDatePeriodAndModeAfterLeavingAnalysis() throws {
        let date = instant("2026-11-09T04:00:00Z")
        var facts = XuanKongHomeContext(facts: [XuanKongSiteFact(palaceID: 8, kind: .noise)])
        let snapshot = TianJiAnalysisSnapshot(heading: 180, period: 8, useTiGua: true, reportDate: date)
            .capturing(context: facts, propertyKey: "home-A", floorplanReport: [], panoramaArchive: nil)
        // A menu transition/phone movement must have no authority over this value snapshot.
        let live = Mountain24Data.shared.resolveHeadingState(heading: 90)
        facts.facts.removeAll()
        XCTAssertEqual(snapshot.heading, 180)
        XCTAssertEqual(snapshot.reportDate, date)
        XCTAssertEqual(snapshot.period, 8)
        XCTAssertTrue(snapshot.useTiGua)
        XCTAssertNotEqual(snapshot.heading, live.facingAngle)
        XCTAssertEqual(snapshot.homeContext?.facts.count, 1)
        XCTAssertTrue(snapshot.hasSpatialSnapshot)
        XCTAssertEqual(snapshot.propertyKey, "home-A")
        XCTAssertEqual(snapshot.flyingStarsChart().period, 8)
        XCTAssertTrue(snapshot.flyingStarsChart().isTiGua)
    }

    @MainActor
    func testYearFiveAtTheNatalFacingNineExportsQuietGuidanceInsteadOfWaterActivation() throws {
        let manager = LocalizationManager.shared, previous = LocalizationManager.shared.effectiveLanguage
        defer { manager.effectiveLanguage = previous }
        manager.effectiveLanguage = .zhHans
        let snapshot = TianJiAnalysisSnapshot(heading: 345, period: 9, useTiGua: false,
            reportDate: instant("2026-11-09T04:00:00Z"))
        let chart = snapshot.flyingStarsChart()
        let south = try XCTUnwrap(chart.palaces.first { $0.id == 8 })
        let sector = try XCTUnwrap(snapshot.deepAnalysis(chart: chart).sectors.first { $0.id == 8 })
        XCTAssertEqual(south.facingStar, 9)
        XCTAssertEqual(sector.yearStar, 5)
        XCTAssertEqual(sector.use, .quiet)
        let text = snapshot.guidanceText(chart: chart)
        XCTAssertTrue(text.contains(south.plainDirectionName + " · " + manager.t("xk_use_quiet")))
        XCTAssertTrue(text.contains(manager.t(XuanKongPracticalAction.reduceNoise.textKey)))
        XCTAssertFalse(text.contains("鱼缸"))
        XCTAssertFalse(text.contains("安设动水"))
    }

    @MainActor
    func testExportUsesEveryComputedRoomActionAndRetainsTheOriginalHouseContext() throws {
        let manager = LocalizationManager.shared, previous = LocalizationManager.shared.effectiveLanguage
        defer { manager.effectiveLanguage = previous }
        manager.effectiveLanguage = .en
        var home = XuanKongHomeContext(places: [XuanKongLocatedPlace(id: "bed", palaceID: 2,
            name: "Guest bed", kind: .bed, roomType: nil)], facts: [XuanKongSiteFact(palaceID: 2, kind: .glare)])
        let snapshot = TianJiAnalysisSnapshot(heading: 90, period: 9, useTiGua: false)
            .capturing(context: home, propertyKey: "original", floorplanReport: [], panoramaArchive: nil)
        home.places.removeAll()
        home.facts.removeAll()
        let deep = snapshot.deepAnalysis()
        let text = snapshot.guidanceText(analysis: deep)
        XCTAssertTrue(text.contains("Guest bed"))
        for sector in deep.sectors {
            for action in sector.actions { XCTAssertTrue(text.contains(manager.t(action.textKey))) }
        }
        XCTAssertTrue(try XCTUnwrap(deep.sectors.first { $0.id == 2 }).actions.contains(.protectSleep))
        XCTAssertTrue(try XCTUnwrap(deep.sectors.first { $0.id == 2 }).actions.contains(.reduceGlare))
    }

    @MainActor
    func testExplicitCompassReportSnapshotDoesNotInheritOtherHouseSpatialData() {
        let snapshot = TianJiAnalysisSnapshot(heading: 90).capturing(context: nil, propertyKey: nil,
            floorplanReport: [], panoramaArchive: nil)
        XCTAssertTrue(snapshot.hasSpatialSnapshot)
        XCTAssertNil(snapshot.propertyKey)
        XCTAssertNil(snapshot.homeContext)
        XCTAssertNil(snapshot.capturedPanoramaArchive)
        XCTAssertTrue(snapshot.capturedFloorplanReport.isEmpty)
    }

    private func mappedSurvey() -> HouseSpatialSurvey {
        HouseSpatialSurvey(scanMethod: "RoomPlan", dimensions: HouseDimensions(totalWidth: 12, totalDepth: 8,
            ceilingHeight: 3, grossFloorArea: 96, usableFloorArea: 96), walls: [], openings: [], beams: [],
            rooms: [SpatialRoom3D(name: "bedroom", type: .masterBedroom, center: SIMD3(7.8, 1, 4), size: SIMD3(1, 3, 1))],
            objects: [SpatialObject3D(category: "bed", position: SIMD3(7.8, 0.5, 4), size: SIMD3(1, 1, 1))],
            centroid: SIMD3(6, 0, 4), compassHeading: 0, shaItems: [], fengshuiScore: 80, houseFacingDegrees: 180)
    }

    func testMeasuredBedMovesWithTheCurrentBlueprintTaiJiRatherThanTheOldSurveyCenter() throws {
        let survey = mappedSurvey()
        let room = FloorplanRoom(name: "bedroom", type: .masterBedroom,
            rect: CGRect(x: 0.59, y: 0.48, width: 0.12, height: 0.04))
        var layout = deepLayout(rooms: [room])
        layout.surveyMapping = FloorplanSurveyMapping(surveyID: survey.id, minX: 0, minZ: 0,
            spanX: 12, spanZ: 8, padding: 0)
        let before = XuanKongHomeContextBuilder.build(layout: layout, survey: survey, exterior: [], facts: [])
        XCTAssertEqual(before.places.first { $0.kind == .bed }?.palaceID, 2)
        let shifted = SavedFloorplanLayout(rooms: layout.rooms, centroidX: 0.8, centroidY: 0.5,
            compassRotation: 0, isSyncWithCompass: false, hasFloorplanAccess: false,
            floorplanAccessGrantID: nil, floorplanAccessGrantSignature: nil,
            aspectRatio: 1, houseFacingDegrees: 180, surveyMapping: layout.surveyMapping)
        let after = XuanKongHomeContextBuilder.build(layout: shifted, survey: survey, exterior: [], facts: [])
        XCTAssertEqual(after.places.first { $0.kind == .bed }?.palaceID, 6)
        XCTAssertEqual(Set(after.places.filter { $0.roomType == .masterBedroom }.map(\.palaceID)), Set([6]))
        XCTAssertFalse(after.warningKeys.contains("xkd_alignment_missing"))
    }

    func testUnalignedOrReplacedSurveyDoesNotMergeBedPointsIntoTheBlueprint() {
        let survey = mappedSurvey()
        let room = FloorplanRoom(name: "bedroom", type: .masterBedroom,
            rect: CGRect(x: 0.59, y: 0.48, width: 0.12, height: 0.04))
        var layout = deepLayout(rooms: [room])
        for mapping in [nil, FloorplanSurveyMapping(surveyID: UUID(), minX: 0, minZ: 0, spanX: 12, spanZ: 8, padding: 0)] {
            layout.surveyMapping = mapping
            let context = XuanKongHomeContextBuilder.build(layout: layout, survey: survey, exterior: [], facts: [])
            XCTAssertFalse(context.places.contains { $0.kind == .bed })
            XCTAssertTrue(context.warningKeys.contains("xkd_alignment_missing"))
            XCTAssertTrue(context.missingKeys.contains("xkd_missing_bed"))
            XCTAssertTrue(context.places.contains { $0.roomType == .masterBedroom })
        }
    }

    func testRoomPlanMappingRestoresItsPaddingAndSurvivesLayoutEncoding() throws {
        let id = UUID()
        var layout = deepLayout(rooms: [])
        layout.surveyMapping = FloorplanSurveyMapping(surveyID: id, minX: -2, minZ: 3,
            spanX: 10, spanZ: 20, padding: 0.1)
        let restored = try JSONDecoder().decode(SavedFloorplanLayout.self, from: JSONEncoder().encode(layout))
        let mapping = try XCTUnwrap(restored.surveyMapping)
        let point = try XCTUnwrap(mapping.point(x: 3, z: 13, surveyID: id))
        XCTAssertEqual(point.x, 0.5, accuracy: 0.000001)
        XCTAssertEqual(point.y, 0.5, accuracy: 0.000001)
        XCTAssertNil(mapping.point(x: 3, z: 13, surveyID: UUID()))
        XCTAssertNil(mapping.point(x: .nan, z: 13, surveyID: id))
        XCTAssertNil(try JSONDecoder().decode(SavedFloorplanLayout.self,
            from: JSONEncoder().encode(deepLayout(rooms: []))).surveyMapping)
        let corrected = HouseSpatialSurveyEngine.analyzeSpatialHouse(scanMethod: "RoomPlan", walls: [], openings: [],
            beams: [], rooms: [], objects: [], compassHeading: 0, surveyID: id)
        XCTAssertEqual(corrected.id, id)
        XCTAssertNotNil(mapping.point(x: 3, z: 13, surveyID: corrected.id))
    }

    func testRepeatedVirtualSavesRefreshTheActiveModelAndTheDurableSnapshot() throws {
        let suite = "virtual-refresh-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShaSurveyStore(defaults: defaults), id = store.propertyID
        let first = survey("VR first"), updated = survey("VR updated")
        XCTAssertTrue(store.saveSurvey(first, key: SpatialSurveyArchiveKeys.virtual, propertyID: id))
        XCTAssertTrue(store.saveSurvey(updated, key: SpatialSurveyArchiveKeys.virtual, propertyID: id))
        XCTAssertEqual(store.latestInterior?.id, updated.id)
        XCTAssertEqual(store.interiorSource, .virtual)
        XCTAssertEqual(ShaSurveyStore(defaults: defaults).latestInterior?.id, updated.id)
    }

    func testLegacySurveySnapshotMigratesItsSourceAndDurableHouseIdentity() throws {
        let suite = "legacy-survey-source-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let oldSurvey = survey("VR legacy")
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(oldSurvey))
        let data = try JSONSerialization.data(withJSONObject: ["records": [], "latestInterior": object])
        defaults.set(data, forKey: "tianji.sha_survey_store.v1")
        let migrated = ShaSurveyStore(defaults: defaults)
        XCTAssertEqual(migrated.interiorSource, .virtual)
        let updated = survey("VR corrected")
        XCTAssertTrue(migrated.saveSurvey(updated, key: SpatialSurveyArchiveKeys.virtual, propertyID: migrated.propertyID))
        let relaunched = ShaSurveyStore(defaults: defaults)
        XCTAssertEqual(relaunched.propertyKey, migrated.propertyKey)
        XCTAssertEqual(relaunched.interiorSource, .virtual)
        XCTAssertEqual(relaunched.latestInterior?.id, updated.id)
    }

    func testVirtualEditDoesNotOverwriteAMeasuredArchiveOrAnExplicitProjection() throws {
        let suite = "measured-priority-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShaSurveyStore(defaults: defaults), id = store.propertyID
        let measured = survey("RoomPlan"), virtual = survey("VR")
        XCTAssertTrue(store.saveSurvey(measured, key: SpatialSurveyArchiveKeys.measured, propertyID: id))
        XCTAssertTrue(store.saveSurvey(virtual, key: SpatialSurveyArchiveKeys.virtual, propertyID: id))
        XCTAssertEqual(store.latestInterior?.id, measured.id)
        XCTAssertEqual(store.interiorSource, .measured)
        let projection = survey("projection")
        XCTAssertTrue(store.updateInterior(projection, propertyID: id))
        XCTAssertTrue(store.saveSurvey(survey("VR changed"), key: SpatialSurveyArchiveKeys.virtual, propertyID: id))
        XCTAssertEqual(store.latestInterior?.id, projection.id)
        XCTAssertEqual(store.interiorSource, .projection)
    }

    func testSamePropertyRoomPlanRefreshPreservesFactsExteriorAndIdentity() throws {
        let suite = "same-house-import-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShaSurveyStore(defaults: defaults), id = store.propertyID, key = store.propertyKey
        store.setSiteFact(.noise, palaceID: 0, present: true, propertyID: id)
        let exterior = ExteriorShaRecord(shaID: "luchong", bearingDegrees: 180)
        XCTAssertTrue(store.addRecord(exterior, propertyID: id))
        let measured = survey("RoomPlan update")
        XCTAssertTrue(store.refreshMeasuredSurvey(measured, propertyID: id))
        XCTAssertEqual(store.propertyID, id)
        XCTAssertEqual(store.propertyKey, key)
        XCTAssertEqual(store.siteFacts, [XuanKongSiteFact(palaceID: 0, kind: .noise)])
        XCTAssertEqual(store.records, [exterior])
        XCTAssertEqual(ShaSurveyStore(defaults: defaults).siteFacts, store.siteFacts)
        XCTAssertFalse(store.refreshMeasuredSurvey(survey("stale"), propertyID: UUID()))
        XCTAssertEqual(store.latestInterior?.id, measured.id)
    }

    func testDurableHouseIdentitySurvivesRelaunchAndArchiveRestorationWhileWriterIDsChange() throws {
        let suite = "property-reminders-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = ShaSurveyStore(defaults: defaults), relaunched = ShaSurveyStore(defaults: defaults)
        let originalKey = first.propertyKey
        XCTAssertEqual(relaunched.propertyKey, originalKey)
        XCTAssertNotEqual(relaunched.propertyID, first.propertyID)
        relaunched.replaceProperty(measured: nil, virtual: nil, exterior: [])
        XCTAssertNotEqual(relaunched.propertyKey, originalKey)
        let previousWriter = relaunched.propertyID
        relaunched.replaceProperty(measured: nil, virtual: nil, exterior: [], propertyKey: originalKey)
        XCTAssertEqual(relaunched.propertyKey, originalKey)
        XCTAssertNotEqual(relaunched.propertyID, previousWriter)
        XCTAssertEqual(ShaSurveyStore(defaults: defaults).propertyKey, originalKey)
    }

    @MainActor
    func testPkHouseFacingRemainsStableAcrossDifferentBlueprintAxes() {
        let expected = Mountain24Data.shared.resolveHeadingState(heading: 180)
        for coordinate in [0.0, 90, 180, 270] {
            let orientation = FloorplanOrientation(coordinateHeading: coordinate, houseFacingDegrees: 180)
            XCTAssertEqual(orientation.houseHeadingState.sittingMountain.id, expected.sittingMountain.id)
            XCTAssertEqual(orientation.houseHeadingState.facingMountain.id, expected.facingMountain.id)
        }
        XCTAssertEqual(FloorplanOrientation(coordinateHeading: 90, houseFacingDegrees: nil).houseHeadingState.facingAngle, 90)
    }

    func testReminderKeysSeparateHomesSittingMountainsAndFullCalendarYears() {
        let date = instant("2026-11-09T04:00:00Z"), zone = TimeZone(secondsFromGMT: 8 * 3600)!
        let first = AuspiciousReminderContext(propertyKey: "house-A", sittingMountain: "子")
        let second = AuspiciousReminderContext(propertyKey: "house-B", sittingMountain: "子")
        let otherSitting = AuspiciousReminderContext(propertyKey: "house-A", sittingMountain: "午")
        XCTAssertNotEqual(first.key(for: date, timeZone: zone), second.key(for: date, timeZone: zone))
        XCTAssertNotEqual(first.key(for: date, timeZone: zone), otherSitting.key(for: date, timeZone: zone))
        XCTAssertTrue(first.key(for: date, timeZone: zone).hasPrefix("2026-11-09-"))
        XCTAssertNotEqual(first.key(for: date, timeZone: zone), first.key(for: instant("2027-11-09T04:00:00Z"), timeZone: zone))
        XCTAssertEqual(first.key(for: date, timeZone: zone), first.key(for: date.addingTimeInterval(3600), timeZone: zone))
    }

    func testReminderArchiveMigratesUnassignedRequestsWithoutAssigningThemToTheCurrentHouse() throws {
        let suite = "legacy-reminders-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let legacy = ["11-09-甲子", "11-10-乙丑"]
        defaults.set(legacy, forKey: AuspiciousReminderArchive.legacyKey)
        var archive = AuspiciousReminderArchive.restore(defaults: defaults)
        XCTAssertEqual(archive.legacyIDs, Set(legacy))
        XCTAssertTrue(archive.records.isEmpty)
        XCTAssertNil(defaults.object(forKey: AuspiciousReminderArchive.legacyKey))
        let date = instant("2026-11-09T04:00:00Z")
        let record = AuspiciousReminderRecord(date: date,
            context: AuspiciousReminderContext(propertyKey: "current", sittingMountain: "子"))
        archive.records.append(record)
        archive.save(defaults: defaults)
        let restored = AuspiciousReminderArchive.restore(defaults: defaults)
        XCTAssertEqual(restored.records, [record])
        XCTAssertEqual(restored.legacyIDs, Set(legacy))
        XCTAssertFalse(restored.legacyIDs.contains(record.id))
        XCTAssertEqual(record.requestID, "tiandi_zeri_" + record.id)
    }

    func testArchivedPropertyKeepsItsReminderIdentityAndOldRecordsRemainReadable() throws {
        var record = self.record(image: nil)
        record.propertyKey = "durable-house"
        let data = try JSONEncoder().encode(record)
        XCTAssertEqual(try JSONDecoder().decode(FloorplanCaseRecord.self, from: data).propertyKey, "durable-house")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "propertyKey")
        XCTAssertNil(try JSONDecoder().decode(FloorplanCaseRecord.self, from: JSONSerialization.data(withJSONObject: json)).propertyKey)
    }

    private func allocationRoom(_ id: String, _ type: FloorplanRoomType, x: CGFloat, y: CGFloat) -> FloorplanRoom {
        FloorplanRoom(id: id, name: id, type: type, rect: CGRect(x: x, y: y, width: 0.1, height: 0.1))
    }

    func testFamilyRoomServiceIncludesVerifiedLifetimeAndAnnualMembership() {
        let now = instant("2026-11-09T00:00:00Z")
        var mirror = StoreKitIAPManager.EntitlementMirror(verifiedAt: now, isAuthoritative: true,
            isLifetime: true, vipActive: false, vipExpireDate: 0, floorplanCredits: 5, tianjiCredits: 5,
            purchasedProductIDs: [IAPProductID.proLifetime.rawValue, IAPProductID.vipYearly.rawValue])
        XCTAssertTrue(mirror.allowsFamilyRoomAllocation(at: now))
        mirror.isLifetime = false
        XCTAssertFalse(mirror.allowsFamilyRoomAllocation(at: now)) // Product history and credits are insufficient.
        mirror.vipExpireDate = now.addingTimeInterval(10).timeIntervalSince1970
        XCTAssertTrue(mirror.allowsFamilyRoomAllocation(at: now))
        XCTAssertFalse(mirror.allowsFamilyRoomAllocation(at: now.addingTimeInterval(10)))
        mirror.vipActive = true // Apple-confirmed grace period remains usable.
        XCTAssertTrue(mirror.allowsFamilyRoomAllocation(at: now.addingTimeInterval(20)))
        mirror.isAuthoritative = false
        XCTAssertFalse(mirror.allowsFamilyRoomAllocation(at: now))
        mirror.isAuthoritative = true
        mirror.revokePaidProduct(IAPProductID.vipYearly.rawValue)
        XCTAssertFalse(mirror.allowsFamilyRoomAllocation(at: now))
    }

    func testPurchaseBenefitsExcludeSingleUseProducts() {
        XCTAssertTrue(IAPProductID.vipYearly.includesAllFeatures)
        XCTAssertTrue(IAPProductID.proLifetime.includesAllFeatures)
        XCTAssertFalse(IAPProductID.floorplanSingle.includesAllFeatures)
        XCTAssertFalse(IAPProductID.tianjiSingle.includesAllFeatures)
    }

    func testUnverifiedLifetimeDoesNotUnlockFeaturesAndRevokedLifetimeLosesAccess() {
        let now = instant("2026-11-10T00:00:00Z")
        var mirror = StoreKitIAPManager.EntitlementMirror(verifiedAt: now, isAuthoritative: false,
            isLifetime: true, vipActive: false, vipExpireDate: 0, floorplanCredits: 1, tianjiCredits: 1,
            purchasedProductIDs: [IAPProductID.proLifetime.rawValue])
        XCTAssertFalse(mirror.allowsFamilyRoomAllocation(at: now))
        mirror.isAuthoritative = true
        XCTAssertTrue(mirror.allowsFamilyRoomAllocation(at: now.addingTimeInterval(86400 * 365 * 10)))
        mirror.revokePaidProduct(IAPProductID.proLifetime.rawValue)
        XCTAssertFalse(mirror.allowsFamilyRoomAllocation(at: now))
    }

    @MainActor
    func testUnpaidProfileDeletionErasesBothStoresAndStaysDeletedAfterReload() throws {
        let localID = "profile-local-" + UUID().uuidString
        let groupID = "profile-group-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: localID))
        let shared = try XCTUnwrap(UserDefaults(suiteName: groupID))
        defer { defaults.removePersistentDomain(forName: localID); shared.removePersistentDomain(forName: groupID) }
        let profile = UserKuaProfileManager(defaults: defaults, sharedDefaults: shared, legacyCloud: nil)
        profile.updateOwnerBirthYear(1985, isMale: false)
        profile.addFamilyMember(role: .son, customName: "Child", birthYear: 2010, isMale: true)
        XCTAssertNotNil(defaults.data(forKey: "tiandi_family_members_v1"))
        XCTAssertNotNil(shared.data(forKey: "tiandi_family_members_v1"))
        profile.deleteAllPersonalProfiles()
        XCTAssertTrue(profile.familyMembers.isEmpty)
        XCTAssertFalse(profile.isProfileEnabled)
        for key in ["tiandi_owner_birth_year", "tiandi_owner_birth_date", "tiandi_owner_is_male", "tiandi_family_members_v1"] {
            XCTAssertNil(defaults.object(forKey: key), key)
            XCTAssertNil(shared.object(forKey: key), key)
        }
        let reloaded = UserKuaProfileManager(defaults: defaults, sharedDefaults: shared, legacyCloud: nil)
        XCTAssertTrue(reloaded.familyMembers.isEmpty)
        XCTAssertFalse(reloaded.isProfileEnabled)
        XCTAssertTrue(FamilyRoomAllocationEngine.people(profile: reloaded).isEmpty)
    }

    @MainActor
    func testIndividualProfileDeletionPreservesOtherMembersAcrossReload() throws {
        let suite = "profile-delete-one-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let profile = UserKuaProfileManager(defaults: defaults, sharedDefaults: nil, legacyCloud: nil)
        profile.addFamilyMember(role: .son, customName: "First", birthYear: 2010, isMale: true)
        profile.addFamilyMember(role: .daughter, customName: "Second", birthYear: 2012, isMale: false)
        let removed = profile.familyMembers[0].id
        let survivor = profile.familyMembers[1].id
        profile.removeFamilyMember(id: removed)
        let reloaded = UserKuaProfileManager(defaults: defaults, sharedDefaults: nil, legacyCloud: nil)
        XCTAssertEqual(reloaded.familyMembers.map(\.id), [survivor])
        XCTAssertEqual(reloaded.familyMembers[0].displayName, "Second")
    }

    @MainActor
    func testNavigationRequestsWakeMountedViewsAndSurviveWithoutSubscribers() {
        let center = NotificationCenter()
        let router = AppNavigationRouter(notificationCenter: center)
        var deliveredTab: Int?
        let subscription = center.publisher(for: .didRequestAppNavigation).sink { _ in
            deliveredTab = router.consumeTabRoute()?.tab
        }
        router.requestRoute(tab: 2)
        XCTAssertEqual(deliveredTab, 2)
        XCTAssertNil(router.consumeTabRoute())
        subscription.cancel()
        router.requestRoute(tab: 1)
        XCTAssertEqual(router.consumeTabRoute()?.tab, 1)
        router.requestAlmanac()
        XCTAssertTrue(router.consumeAlmanac())
        XCTAssertFalse(router.consumeAlmanac())
    }

    @MainActor
    func testFamilyExportHonorsVisibilityAndAnnualAccessForBothTextAndLabels() {
        let rooms = [allocationRoom("bed", .masterBedroom, x: 0.45, y: 0.75)]
        let people = [FamilyRoomPerson(id: "owner", name: "Private name", guaKey: "坎")]
        let manual = [FamilyRoomAssignment(personID: "owner", roomID: "bed")]
        for access in [false, true] {
            for visible in [false, true] where !access || !visible {
                let snapshot = FamilyRoomExportSnapshot(manual: manual, rooms: rooms, people: people,
                    centroid: CGPoint(x: 0.5, y: 0.5), heading: 0, aspectRatio: 1,
                    hasMembershipAccess: access, includePeople: visible)
                XCTAssertTrue(snapshot.labels.isEmpty)
                XCTAssertTrue(snapshot.report.isEmpty)
            }
        }
    }

    @MainActor
    func testFamilyExportIncludesSuggestionStatusAndPeopleWithoutBedrooms() throws {
        let rooms = [allocationRoom("south-bed", .masterBedroom, x: 0.45, y: 0.75)]
        let people = [FamilyRoomPerson(id: "owner", name: "Owner", guaKey: "坎"),
                      FamilyRoomPerson(id: "elder", name: "Elder", guaKey: "乾")]
        let snapshot = FamilyRoomExportSnapshot(manual: nil, rooms: rooms, people: people,
            centroid: CGPoint(x: 0.5, y: 0.5), heading: 0, aspectRatio: 1,
            hasMembershipAccess: true, includePeople: true)
        let roomItem = try XCTUnwrap(snapshot.report.first { $0.id == "family-room-south-bed" })
        XCTAssertTrue(roomItem.title.contains(LocalizationManager.shared.t("fra_suggested")))
        XCTAssertTrue(roomItem.isGood)
        let unassigned = try XCTUnwrap(snapshot.report.first { $0.id == "family-unassigned" })
        XCTAssertTrue(unassigned.lore.contains("Elder"))
        XCTAssertFalse(unassigned.lore.contains("Owner"))
    }

    @MainActor
    func testManualFamilyExportAndDiagramFlagWeakMatches() throws {
        let rooms = [allocationRoom("south-bed", .masterBedroom, x: 0.45, y: 0.75)]
        let people = [FamilyRoomPerson(id: "elder", name: "Elder", guaKey: "乾")]
        let manual = [FamilyRoomAssignment(personID: "elder", roomID: "south-bed")]
        let snapshot = FamilyRoomExportSnapshot(manual: manual, rooms: rooms, people: people,
            centroid: CGPoint(x: 0.5, y: 0.5), heading: 0, aspectRatio: 1,
            hasMembershipAccess: true, includePeople: true)
        XCTAssertTrue(try XCTUnwrap(snapshot.labels["south-bed"]).hasPrefix("⚠︎"))
        let item = try XCTUnwrap(snapshot.report.first)
        XCTAssertTrue(item.title.contains(LocalizationManager.shared.t("fra_assigned")))
        XCTAssertTrue(item.lore.contains(LocalizationManager.shared.t("fra_review")))
        XCTAssertFalse(item.isGood)
        XCTAssertEqual(FamilyRoomAllocationEngine.reviewRoomIDs(assignments: manual, rooms: rooms, people: people,
            centroid: CGPoint(x: 0.5, y: 0.5), heading: 0, aspectRatio: 1), Set(["south-bed"]))
    }

    func testChangingRoomUseClearsAssignmentsWithoutRevivingOldOccupants() throws {
        let manual = [FamilyRoomAssignment(personID: "owner", roomID: "changed"),
                      FamilyRoomAssignment(personID: "child", roomID: "other")]
        XCTAssertEqual(FamilyRoomAllocationEngine.afterChangingRoomUse(manual, roomID: "changed",
            from: .masterBedroom, to: .secondBedroom), manual)
        let changed = try XCTUnwrap(FamilyRoomAllocationEngine.afterChangingRoomUse(manual, roomID: "changed",
            from: .masterBedroom, to: .kitchen))
        XCTAssertEqual(changed, [manual[1]])
        XCTAssertEqual(FamilyRoomAllocationEngine.afterChangingRoomUse(changed, roomID: "changed",
            from: .kitchen, to: .masterBedroom), changed)
        XCTAssertEqual(FamilyRoomAllocationEngine.afterChangingRoomUse(manual, roomID: "changed",
            from: .masterBedroom, to: .study), [manual[1]])
        XCTAssertNil(FamilyRoomAllocationEngine.afterChangingRoomUse(nil, roomID: "changed",
            from: .masterBedroom, to: .study))
    }

    @MainActor
    func testFloorplanReportPositionsLongParagraphsWithoutOverlap() {
        let item = FloorplanAuditItem(id: "family", title: String(repeating: "Family room recommendation ", count: 10),
            palace: "", severity: "", lore: String(repeating: "Member · This bedroom is a closer match for rest.\n", count: 8),
            solution: String(repeating: "Check actual bed space and clear access. ", count: 8))
        let layout = FloorplanReportRowLayout(item: item, solutionPrefix: "Action:", width: 200)
        XCTAssertGreaterThan(layout.titleRect.height, FloorplanReportRowLayout.titleFont.lineHeight * 2)
        XCTAssertGreaterThan(layout.loreRect.height, FloorplanReportRowLayout.bodyFont.lineHeight * 8)
        XCTAssertGreaterThanOrEqual(layout.loreRect.minY, layout.titleRect.maxY + 8)
        XCTAssertGreaterThanOrEqual(layout.solutionRect.minY, layout.loreRect.maxY + 8)
        XCTAssertGreaterThanOrEqual(layout.height - 12, layout.solutionRect.maxY + 16)
    }

    @MainActor
    func testFamilyExportSnapshotRetainsCapturedNamesAndAssignments() {
        let rooms = [allocationRoom("bed", .masterBedroom, x: 0.45, y: 0.75)]
        var people = [FamilyRoomPerson(id: "owner", name: "Original name", guaKey: "坎")]
        var manual = [FamilyRoomAssignment(personID: "owner", roomID: "bed")]
        let snapshot = FamilyRoomExportSnapshot(manual: manual, rooms: rooms, people: people,
            centroid: CGPoint(x: 0.5, y: 0.5), heading: 0, aspectRatio: 1,
            hasMembershipAccess: true, includePeople: true)
        people[0] = FamilyRoomPerson(id: "owner", name: "New name", guaKey: "乾")
        manual.removeAll()
        XCTAssertEqual(snapshot.labels["bed"], "Original name")
        XCTAssertTrue(snapshot.report.first?.lore.contains("Original name") == true)
        XCTAssertFalse(snapshot.report.first?.lore.contains("New name") == true)
    }

    @MainActor
    func testFamilyRoomSuggestionsRankBedroomsAndStudySeparately() {
        let rooms = [allocationRoom("north-bed", .secondBedroom, x: 0.45, y: 0.15),
                     allocationRoom("south-bed", .masterBedroom, x: 0.45, y: 0.75),
                     allocationRoom("north-study", .study, x: 0.45, y: 0.15),
                     allocationRoom("south-study", .study, x: 0.45, y: 0.75),
                     allocationRoom("kitchen", .kitchen, x: 0.75, y: 0.45)]
        let person = FamilyRoomPerson(id: "owner", name: "Owner", guaKey: "坎")
        let plan = FamilyRoomAllocationEngine.recommend(rooms: rooms, people: [person],
            centroid: CGPoint(x: 0.5, y: 0.5), heading: 0, aspectRatio: 1, hasMembershipAccess: true)
        XCTAssertEqual(plan, [FamilyRoomAssignment(personID: "owner", roomID: "south-bed"),
                              FamilyRoomAssignment(personID: "owner", roomID: "north-study")])
        XCTAssertEqual(plan, FamilyRoomAllocationEngine.recommend(rooms: Array(rooms.reversed()), people: [person],
            centroid: CGPoint(x: 0.5, y: 0.5), heading: 0, aspectRatio: 1, hasMembershipAccess: true))
    }

    @MainActor
    func testFamilySuggestionsEvaluateEveryPersonAndAllowSharedUse() {
        let rooms = [allocationRoom("south-bed", .masterBedroom, x: 0.45, y: 0.75),
                     allocationRoom("southwest-bed", .secondBedroom, x: 0.15, y: 0.75),
                     allocationRoom("north-study", .study, x: 0.45, y: 0.15),
                     allocationRoom("west-study", .study, x: 0.15, y: 0.45)]
        let people = [FamilyRoomPerson(id: "owner", name: "Owner", guaKey: "坎"),
                      FamilyRoomPerson(id: "elder", name: "Elder", guaKey: "乾"),
                      FamilyRoomPerson(id: "child", name: "Child", guaKey: "坎")]
        let plan = FamilyRoomAllocationEngine.recommend(rooms: rooms, people: people,
            centroid: CGPoint(x: 0.5, y: 0.5), heading: 0, aspectRatio: 1, hasMembershipAccess: true)
        XCTAssertEqual(plan.count, 6)
        XCTAssertTrue(plan.contains(FamilyRoomAssignment(personID: "owner", roomID: "south-bed")))
        XCTAssertTrue(plan.contains(FamilyRoomAssignment(personID: "elder", roomID: "southwest-bed")))
        XCTAssertTrue(plan.contains(FamilyRoomAssignment(personID: "elder", roomID: "west-study")))
        XCTAssertTrue(plan.contains(FamilyRoomAssignment(personID: "child", roomID: "south-bed")))
        let names = FamilyRoomAllocationEngine.labels(assignments: plan, people: people)
        XCTAssertEqual(names["south-bed"], "Owner、Child")
    }

    @MainActor
    func testFamilyRoomSuggestionsDoNotForceUnfavorableOrCentralRooms() {
        let rooms = [allocationRoom("west-bed", .secondBedroom, x: 0.15, y: 0.45),
                     allocationRoom("center-bed", .masterBedroom, x: 0.45, y: 0.45)]
        let person = FamilyRoomPerson(id: "child", name: "Child", guaKey: "坎")
        let plan = FamilyRoomAllocationEngine.recommend(rooms: rooms, people: [person],
            centroid: CGPoint(x: 0.5, y: 0.5), heading: 0, aspectRatio: 1, hasMembershipAccess: true)
        XCTAssertTrue(plan.isEmpty)
        let fit = FamilyRoomAllocationEngine.fits(room: rooms[1], rooms: rooms, people: [person],
            centroid: CGPoint(x: 0.5, y: 0.5), heading: 0, aspectRatio: 1).first
        XCTAssertNil(fit?.star)
        XCTAssertEqual(fit?.reasonKey, "fra_center")
    }

    func testFamilyRoomDirectionsRespectAspectRatioAndBlueprintNorth() {
        let room = allocationRoom("diagonal", .secondBedroom, x: 0.65, y: 0.25)
        let center = CGPoint(x: 0.5, y: 0.5)
        XCTAssertEqual(FamilyRoomAllocationEngine.palace(room: room, rooms: [room], centroid: center,
            heading: 0, aspectRatio: 1), "艮")
        XCTAssertEqual(FamilyRoomAllocationEngine.palace(room: room, rooms: [room], centroid: center,
            heading: 0, aspectRatio: 3), "震")
        XCTAssertEqual(FamilyRoomAllocationEngine.palace(room: room, rooms: [room], centroid: center,
            heading: 90, aspectRatio: 3), "离")
        XCTAssertEqual(FamilyRoomAllocationEngine.palace(room: room, rooms: [room], centroid: center,
            heading: -270, aspectRatio: 3), "离")
        XCTAssertNil(FamilyRoomAllocationEngine.palace(room: room, rooms: [room], centroid: center,
            heading: .nan, aspectRatio: 1))
    }

    func testManualFamilyMovesPreserveStudyAndAllowSharedBedrooms() {
        let rooms = [allocationRoom("a", .masterBedroom, x: 0.2, y: 0.2),
                     allocationRoom("b", .secondBedroom, x: 0.7, y: 0.7),
                     allocationRoom("study", .study, x: 0.7, y: 0.2)]
        let people = [FamilyRoomPerson(id: "one", name: "One", guaKey: "坎"),
                      FamilyRoomPerson(id: "two", name: "Two", guaKey: "乾")]
        var plan = [FamilyRoomAssignment(personID: "one", roomID: "a"),
                    FamilyRoomAssignment(personID: "one", roomID: "study"),
                    FamilyRoomAssignment(personID: "two", roomID: "b")]
        plan = FamilyRoomAllocationEngine.toggling(personID: "one", room: rooms[1], assignments: plan, rooms: rooms, people: people)
        XCTAssertFalse(plan.contains { $0.personID == "one" && $0.roomID == "a" })
        XCTAssertTrue(plan.contains { $0.personID == "one" && $0.roomID == "study" })
        XCTAssertEqual(plan.filter { $0.roomID == "b" }.count, 2)
        plan = FamilyRoomAllocationEngine.toggling(personID: "one", room: rooms[1], assignments: plan, rooms: rooms, people: people)
        XCTAssertFalse(plan.contains { $0.personID == "one" && $0.roomID == "b" })
        XCTAssertTrue(plan.contains { $0.personID == "two" && $0.roomID == "b" })
    }

    func testRemovedFamilyAndNonResidentialRoomsCannotRemainAssigned() {
        let rooms = [allocationRoom("bed", .secondBedroom, x: 0.2, y: 0.2),
                     allocationRoom("bath", .bathroom, x: 0.7, y: 0.7)]
        let people = [FamilyRoomPerson(id: "live", name: "Renamed", guaKey: "坎")]
        let raw = [FamilyRoomAssignment(personID: "removed", roomID: "bed"),
                   FamilyRoomAssignment(personID: "live", roomID: "removed-room"),
                   FamilyRoomAssignment(personID: "live", roomID: "bath"),
                   FamilyRoomAssignment(personID: "live", roomID: "bed"),
                   FamilyRoomAssignment(personID: "live", roomID: "bed")]
        let cleaned = FamilyRoomAllocationEngine.cleaned(raw, rooms: rooms, people: people)
        XCTAssertEqual(cleaned, [FamilyRoomAssignment(personID: "live", roomID: "bed")])
        XCTAssertEqual(FamilyRoomAllocationEngine.labels(assignments: cleaned, people: people)["bed"], "Renamed")
    }

    @MainActor
    func testClearedFamilyPlanAndExpiredAccessNeverRestoreAutomaticAssignments() {
        let rooms = [allocationRoom("bed", .masterBedroom, x: 0.45, y: 0.75)]
        let people = [FamilyRoomPerson(id: "owner", name: "Owner", guaKey: "坎")]
        let center = CGPoint(x: 0.5, y: 0.5)
        XCTAssertFalse(FamilyRoomAllocationEngine.resolve(manual: nil, rooms: rooms, people: people,
            centroid: center, heading: 0, aspectRatio: 1, hasMembershipAccess: true).isEmpty)
        XCTAssertTrue(FamilyRoomAllocationEngine.resolve(manual: [], rooms: rooms, people: people,
            centroid: center, heading: 0, aspectRatio: 1, hasMembershipAccess: true).isEmpty)
        let manual = [FamilyRoomAssignment(personID: "owner", roomID: "bed")]
        XCTAssertTrue(FamilyRoomAllocationEngine.resolve(manual: manual, rooms: rooms, people: people,
            centroid: center, heading: 0, aspectRatio: 1, hasMembershipAccess: false).isEmpty)
        XCTAssertTrue(FamilyRoomAllocationEngine.resolve(manual: nil, rooms: rooms, people: people,
            centroid: center, heading: 0, aspectRatio: 1, hasMembershipAccess: false).isEmpty)
    }

    func testFamilyAssignmentsRoundTripWithCaseAndDecodeLegacyPlans() throws {
        var layout = record(image: nil).layout
        layout.familyRoomAssignments = [FamilyRoomAssignment(personID: "family:stable-id", roomID: "bed")]
        let savedCase = FloorplanCaseRecord(id: "house-a", title: "A", createdAt: Date(), sittingSummary: "", layout: layout, imageFileName: nil)
        let restored = try JSONDecoder().decode(FloorplanCaseRecord.self, from: JSONEncoder().encode(savedCase))
        XCTAssertEqual(restored.layout.familyRoomAssignments, layout.familyRoomAssignments)
        XCTAssertNil(record(image: nil).layout.familyRoomAssignments) // A separate house does not inherit the plan.
        layout.familyRoomAssignments = []
        XCTAssertEqual(try JSONDecoder().decode(SavedFloorplanLayout.self, from: JSONEncoder().encode(layout)).familyRoomAssignments, [])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(layout)) as? [String: Any])
        json.removeValue(forKey: "familyRoomAssignments")
        XCTAssertNil(try JSONDecoder().decode(SavedFloorplanLayout.self, from: JSONSerialization.data(withJSONObject: json)).familyRoomAssignments)
    }

    @MainActor
    func testLegacyFamilyIDsAreRepairedAndRemainStableAfterReload() throws {
        let profiles = [FamilyMemberProfile(id: "first", role: .father, birthYear: 1960, isMale: true),
                        FamilyMemberProfile(id: "second", role: .mother, birthYear: 1963, isMale: false),
                        FamilyMemberProfile(id: "duplicate", role: .son, birthYear: 2010, isMale: true),
                        FamilyMemberProfile(id: "duplicate", role: .daughter, birthYear: 2012, isMale: false)]
        var rows = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(profiles)) as? [[String: Any]])
        rows[0].removeValue(forKey: "id")
        rows[1]["id"] = " "
        let restored = try UserKuaProfileManager.restoringFamilyMembers(from: JSONSerialization.data(withJSONObject: rows))
        XCTAssertEqual(Set(restored.profiles.map(\.id)).count, 4)
        XCTAssertFalse(restored.profiles.contains { $0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        let migrated = try XCTUnwrap(restored.migratedData)
        let reloaded = try UserKuaProfileManager.restoringFamilyMembers(from: migrated)
        XCTAssertEqual(reloaded.profiles, restored.profiles)
        XCTAssertNil(reloaded.migratedData)
    }

    @MainActor
    func testFamilyPeopleUseStableIDsAndHonorDisabledProfile() {
        let profile = UserKuaProfileManager.shared
        let oldEnabled = profile.isProfileEnabled
        let oldFamily = profile.familyMembers
        defer { profile.familyMembers = oldFamily; profile.isProfileEnabled = oldEnabled }
        profile.familyMembers = [FamilyMemberProfile(id: "child-id", role: .daughter, customName: "Child",
                                                     birthYear: 2015, isMale: false)]
        profile.isProfileEnabled = true
        let people = FamilyRoomAllocationEngine.people(profile: profile)
        XCTAssertEqual(people.map(\.id), ["owner", "family:child-id"])
        XCTAssertEqual(people[1].guaKey, profile.familyMembers[0].guaKey)
        profile.updateFamilyMember(id: "child-id", customName: "New name")
        XCTAssertEqual(FamilyRoomAllocationEngine.people(profile: profile)[1].id, "family:child-id")
        XCTAssertEqual(FamilyRoomAllocationEngine.people(profile: profile)[1].name, "New name")
        profile.isProfileEnabled = false
        XCTAssertTrue(FamilyRoomAllocationEngine.people(profile: profile).isEmpty)
    }

    @MainActor
    func testLongReportAllocatesEnoughHeightForAllRoomGuidanceAndSources() {
        autoreleasepool {
            let place = XuanKongLocatedPlace(id: "long-room", palaceID: 0,
                name: String(repeating: "房间", count: 12_000), kind: .room, roomType: .study)
            let snapshot = TianJiAnalysisSnapshot(heading: 345, period: 9, useTiGua: false,
                reportDate: instant("2026-11-09T04:00:00Z"))
                .capturing(context: XuanKongHomeContext(places: [place]), propertyKey: "large-report",
                    floorplanReport: [], panoramaArchive: nil)
            let image = TianJiShuEngine.shared.generateScrollImage(heading: snapshot.heading,
                coordsDesc: "", solarTimeDesc: "", isPro: true, analysis: snapshot)
            XCTAssertEqual(image.size.width, 1080)
            XCTAssertGreaterThan(image.size.height, 15_000)
        }
    }
}
