import Foundation
import CoreGraphics

/// IDs, rather than names or birth data, keep saved plans linked to the live family profile.
struct FamilyRoomAssignment: Codable, Equatable {
    let personID: String
    let roomID: String
}

struct FamilyRoomPerson: Identifiable {
    let id: String
    let name: String
    let guaKey: String
}

struct FamilyRoomFit {
    let person: FamilyRoomPerson
    let star: StarLuckType?
    let rank: Int
    let reasonKey: String
    var isRecommended: Bool { star?.isAuspicious == true }
}

enum FamilyRoomAllocationEngine {
    enum RoomUse: Equatable { case bedroom, study }

    static func use(for type: FloorplanRoomType) -> RoomUse? {
        switch type {
        case .masterBedroom, .secondBedroom: return .bedroom
        case .study: return .study
        default: return nil
        }
    }

    static func afterChangingRoomUse(_ manual: [FamilyRoomAssignment]?, roomID: String,
                                     from oldType: FloorplanRoomType, to newType: FloorplanRoomType) -> [FamilyRoomAssignment]? {
        guard let manual else { return nil }
        guard use(for: oldType) != use(for: newType) else { return manual }
        return manual.filter { $0.roomID != roomID }
    }

    static func reviewRoomIDs(assignments: [FamilyRoomAssignment], rooms: [FloorplanRoom], people: [FamilyRoomPerson],
                              centroid: CGPoint, heading: Double, aspectRatio: CGFloat) -> Set<String> {
        guard !assignments.isEmpty else { return [] }
        return Set(rooms.filter { room in
            fits(room: room, rooms: rooms, people: people, centroid: centroid, heading: heading, aspectRatio: aspectRatio)
                .contains { fit in !fit.isRecommended && assignments.contains { $0.roomID == room.id && $0.personID == fit.person.id } }
        }.map(\.id))
    }

    static func resolve(manual: [FamilyRoomAssignment]?, rooms: [FloorplanRoom], people: [FamilyRoomPerson],
                        centroid: CGPoint, heading: Double, aspectRatio: CGFloat,
                        hasMembershipAccess: Bool) -> [FamilyRoomAssignment] {
        guard hasMembershipAccess else { return [] }
        if let manual { return cleaned(manual, rooms: rooms, people: people) }
        return recommend(rooms: rooms, people: people, centroid: centroid, heading: heading,
                         aspectRatio: aspectRatio, hasMembershipAccess: true)
    }

    static func labels(assignments: [FamilyRoomAssignment], people: [FamilyRoomPerson]) -> [String: String] {
        Dictionary(grouping: assignments, by: \.roomID).mapValues { roomAssignments in
            people.filter { person in roomAssignments.contains { $0.personID == person.id } }
                .map(\.name).joined(separator: "、")
        }
    }

    static func people(profile: UserKuaProfileManager) -> [FamilyRoomPerson] {
        guard profile.isProfileEnabled else { return [] }
        return [FamilyRoomPerson(id: "owner", name: LocalizationManager.shared.t("fra_owner"),
                                 guaKey: profile.ownerGuaKey)] + profile.familyMembers.map {
            FamilyRoomPerson(id: "family:\($0.id)", name: $0.displayName, guaKey: $0.guaKey)
        }
    }

    static func isAssignable(_ room: FloorplanRoom) -> Bool {
        use(for: room.type) != nil
            && room.rect.minX.isFinite && room.rect.minY.isFinite
            && room.rect.width.isFinite && room.rect.height.isFinite
            && room.rect.width > 0 && room.rect.height > 0
    }

    /// Use blueprint north and its actual aspect ratio, independently of the house facing.
    /// The room containing the Tai Ji point has no single personal direction to rank.
    static func palace(room: FloorplanRoom, rooms: [FloorplanRoom], centroid: CGPoint,
                       heading: Double, aspectRatio: CGFloat) -> String? {
        guard isAssignable(room), heading.isFinite, centroid.x.isFinite, centroid.y.isFinite,
              aspectRatio.isFinite, aspectRatio > 0 else { return nil }
        let centralRoom = rooms.filter { $0.type != .missingCorner && FloorplanEngine.roomContains($0, point: centroid) }
            .min { FloorplanEngine.roomArea($0) < FloorplanEngine.roomArea($1) }
        guard centralRoom?.id != room.id else { return nil }
        let bearing = GeometryUtils.bearing(from: centroid, to: FloorplanEngine.roomCentroid(room), aspectRatio: aspectRatio)
        guard bearing.isFinite else { return nil }
        let degrees = (bearing + heading.truncatingRemainder(dividingBy: 360)).truncatingRemainder(dividingBy: 360)
        let normalized = degrees < 0 ? degrees + 360 : degrees
        let index = Int((normalized + 22.5).truncatingRemainder(dividingBy: 360) / 45)
        return ["坎", "艮", "震", "巽", "离", "坤", "兑", "乾"][index]
    }

    static func fits(room: FloorplanRoom, rooms: [FloorplanRoom], people: [FamilyRoomPerson],
                     centroid: CGPoint, heading: Double, aspectRatio: CGFloat) -> [FamilyRoomFit] {
        guard isAssignable(room) else { return [] }
        let gua = palace(room: room, rooms: rooms, centroid: centroid, heading: heading, aspectRatio: aspectRatio)
        return people.map { person in
            let star = gua.flatMap { gua in
                BaZhaiEngine.shared.analyze(sittingPalace: person.guaKey, facingPalace: "离")
                    .items.first { $0.guaName == gua }?.star
            }
            let rank: Int
            switch star {
            case .fuWei: rank = room.type == .study ? 100 : 80
            case .yanNian: rank = room.type == .study ? 80 : 100
            case .tianYi: rank = room.type == .study ? 70 : 95
            case .shengQi: rank = room.type == .study ? 90 : 75
            default: rank = 0
            }
            let reasonKey = star == nil ? "fra_center"
                : (star?.isAuspicious == true ? (room.type == .study ? "fra_fit_study" : "fra_fit_rest") : "fra_review")
            return FamilyRoomFit(person: person, star: star, rank: rank, reasonKey: reasonKey)
        }.sorted { $0.rank == $1.rank ? $0.person.id < $1.person.id : $0.rank > $1.rank }
    }

    /// Each person gets at most one bedroom and one shared study. Never propose sleeping
    /// in a kitchen/bathroom, or force an unfavorable bedroom when there is no match.
    static func recommend(rooms: [FloorplanRoom], people: [FamilyRoomPerson], centroid: CGPoint,
                          heading: Double, aspectRatio: CGFloat, hasMembershipAccess: Bool) -> [FamilyRoomAssignment] {
        guard hasMembershipAccess else { return [] }
        var result: [FamilyRoomAssignment] = []
        for person in people {
            for study in [false, true] {
                let candidates = rooms.filter { isAssignable($0) && ($0.type == .study) == study }.compactMap { room -> (String, Int)? in
                    guard let fit = fits(room: room, rooms: rooms, people: [person], centroid: centroid,
                                         heading: heading, aspectRatio: aspectRatio).first, fit.isRecommended else { return nil }
                    return (room.id, fit.rank)
                }.sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
                if let best = candidates.first { result.append(FamilyRoomAssignment(personID: person.id, roomID: best.0)) }
            }
        }
        return result
    }

    static func cleaned(_ assignments: [FamilyRoomAssignment], rooms: [FloorplanRoom],
                        people: [FamilyRoomPerson]) -> [FamilyRoomAssignment] {
        let personIDs = Set(people.map(\.id))
        var occupied = Set<String>()
        return assignments.filter { assignment in
            guard personIDs.contains(assignment.personID),
                  let room = rooms.first(where: { $0.id == assignment.roomID }), isAssignable(room) else { return false }
            return occupied.insert(assignment.personID + (room.type == .study ? ":study" : ":bedroom")).inserted
        }
    }

    static func toggling(personID: String, room: FloorplanRoom, assignments: [FamilyRoomAssignment],
                         rooms: [FloorplanRoom], people: [FamilyRoomPerson]) -> [FamilyRoomAssignment] {
        var result = cleaned(assignments, rooms: rooms, people: people)
        guard isAssignable(room), people.contains(where: { $0.id == personID }) else { return result }
        let wasAssigned = result.contains { $0.personID == personID && $0.roomID == room.id }
        result.removeAll { assignment in
            assignment.personID == personID && rooms.contains {
                $0.id == assignment.roomID && ($0.type == .study) == (room.type == .study)
            }
        }
        if !wasAssigned { result.append(FamilyRoomAssignment(personID: personID, roomID: room.id)) }
        return result
    }
}

/// Capture the privacy choice, access and family profile together before background rendering.
struct FamilyRoomExportSnapshot {
    let labels: [String: String]
    let report: [FloorplanAuditItem]

    init(manual: [FamilyRoomAssignment]?, rooms: [FloorplanRoom], people: [FamilyRoomPerson],
         centroid: CGPoint, heading: Double, aspectRatio: CGFloat, hasMembershipAccess: Bool, includePeople: Bool) {
        guard hasMembershipAccess, includePeople, !people.isEmpty else {
            labels = [:]
            report = []
            return
        }
        let assignments = FamilyRoomAllocationEngine.resolve(manual: manual, rooms: rooms, people: people,
            centroid: centroid, heading: heading, aspectRatio: aspectRatio, hasMembershipAccess: true)
        var capturedLabels = FamilyRoomAllocationEngine.labels(assignments: assignments, people: people)
        var items: [FloorplanAuditItem] = []
        let lang = LocalizationManager.shared
        let mode = lang.t(manual == nil ? "fra_suggested" : "fra_assigned")
        for room in rooms {
            let fits = FamilyRoomAllocationEngine.fits(room: room, rooms: rooms, people: people,
                centroid: centroid, heading: heading, aspectRatio: aspectRatio)
                .filter { fit in assignments.contains { $0.roomID == room.id && $0.personID == fit.person.id } }
            guard !fits.isEmpty else { continue }
            let needsReview = fits.contains { !$0.isRecommended }
            if needsReview, let names = capturedLabels[room.id] { capturedLabels[room.id] = "⚠︎ " + names }
            items.append(FloorplanAuditItem(id: "family-room-\(room.id)",
                title: lang.t("fra_title") + " · " + room.name + " · " + mode,
                palace: room.palaceName, severity: needsReview ? "提示" : "吉",
                lore: fits.map { $0.person.name + " · " + lang.t($0.reasonKey) }.joined(separator: "\n"),
                solution: lang.t("fra_note")))
        }
        let unassigned = people.filter { person in
            !assignments.contains { assignment in
                assignment.personID == person.id && rooms.contains { $0.id == assignment.roomID && $0.type != .study }
            }
        }
        if !unassigned.isEmpty {
            items.append(FloorplanAuditItem(id: "family-unassigned", title: lang.t("fra_title") + " · " + lang.t("fra_check"),
                palace: "", severity: "提示",
                lore: unassigned.map(\.name).joined(separator: "、") + " · " + lang.t("fra_no_bedroom"),
                solution: lang.t("fra_no_match")))
        }
        labels = capturedLabels
        report = items
    }
}
