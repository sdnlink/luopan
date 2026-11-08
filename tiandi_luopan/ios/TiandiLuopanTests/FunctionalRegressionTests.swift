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
        var reservations = TianjiCreditReservations()
        let token = try XCTUnwrap(reservations.reserve(availableCredits: 1))
        // Repeated availability checks must not evict a still-presented share.
        for _ in 0..<100 { XCTAssertNil(reservations.reserve(availableCredits: 1)) }
        XCTAssertEqual(reservations.count, 1)
        XCTAssertTrue(reservations.finish(token))
        XCTAssertFalse(reservations.finish(token))
        XCTAssertEqual(reservations.count, 0)
    }

    func testCancellingOneExportDoesNotReleaseAnotherExportsCredit() throws {
        var reservations = TianjiCreditReservations()
        let first = try XCTUnwrap(reservations.reserve(availableCredits: 2))
        let second = try XCTUnwrap(reservations.reserve(availableCredits: 2))
        XCTAssertTrue(reservations.finish(first))
        XCTAssertFalse(reservations.finish(first))
        XCTAssertEqual(reservations.count, 1)
        XCTAssertNil(reservations.reserve(availableCredits: 1))
        XCTAssertTrue(reservations.finish(second))
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

}
