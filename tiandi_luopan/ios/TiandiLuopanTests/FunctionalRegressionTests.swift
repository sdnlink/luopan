import XCTest
import UIKit
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
}
