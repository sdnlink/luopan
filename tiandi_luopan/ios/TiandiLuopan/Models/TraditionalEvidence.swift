import Foundation

// Shared by the app and widget; depends only on Foundation and LocalizationManager.

/// All 81 ordered star pairs have a deterministic elemental relationship.
/// Motifs supplement the relation; they do not turn an observed room into a prediction.
struct XuanKongStarPair {
    enum Relation: CaseIterable, Equatable {
        case same, firstGeneratesSecond, secondGeneratesFirst, firstControlsSecond, secondControlsFirst
        var titleKey: String {
            switch self {
            case .same: return "xkd_pair_same"
            case .firstGeneratesSecond: return "xkd_pair_generate_forward"
            case .secondGeneratesFirst: return "xkd_pair_generate_back"
            case .firstControlsSecond: return "xkd_pair_control_forward"
            case .secondControlsFirst: return "xkd_pair_control_back"
            }
        }
    }
    let first: Int
    let second: Int
    // Generating cycle: Wood, Fire, Earth, Metal, Water.
    private static let elements = [1: 4, 2: 2, 3: 0, 4: 0, 5: 2, 6: 3, 7: 3, 8: 2, 9: 1]
    var firstElementIndex: Int? { Self.elements[first] }
    var secondElementIndex: Int? { Self.elements[second] }
    var relation: Relation {
        let a = Self.elements[first] ?? 2, b = Self.elements[second] ?? 2
        if a == b { return .same }
        if (a + 1) % 5 == b { return .firstGeneratesSecond }
        if (b + 1) % 5 == a { return .secondGeneratesFirst }
        if (a + 2) % 5 == b { return .firstControlsSecond }
        return .secondControlsFirst
    }
    var hasEarthCaution: Bool { [first, second].contains { $0 == 2 || $0 == 5 } }
    var isStudy: Bool { Set([first, second]) == Set([1, 4]) || Set([first, second]) == Set([1, 6]) }
    var isFriction: Bool { Set([first, second]) == Set([3, 7]) }
    var isHeat: Bool { Set([first, second]) == Set([7, 9]) || (first == 9 && second == 9) }
}

// Sources carry their actual matches. Only verified, traceable text is quoted;
// transmitted star rules are explicitly labeled as summaries rather than book quotations.
struct TraditionalEvidence: Identifiable {
    enum Kind: Equatable { case classic, rule }
    let id: String
    let kind: Kind
    let titleKey: String
    var quotes: [String] = []
    var matches: [String] = []
    var sourceURL: URL? = nil

    var localizedTitle: String {
        let lang = LocalizationManager.shared
        return lang.t(kind == .classic ? "ref_classic" : "ref_rule") + " · " + lang.t(titleKey)
    }

    var localizedText: String {
        var lines = [localizedTitle]
        if !quotes.isEmpty { lines.append("“" + quotes.joined(separator: "；") + "”") }
        if !matches.isEmpty { lines.append(LocalizationManager.shared.t("ref_matches") + matches.joined(separator: "；")) }
        return lines.joined(separator: "\n")
    }
}

enum TraditionalEvidenceCatalog {
    // Fixed revisions of the public-domain transcriptions audited for these excerpts.
    static let mountainWaterURL = URL(string: "https://zh.wikisource.org/w/index.php?oldid=1557328")!
    static let elementsURL = URL(string: "https://zh.wikisource.org/w/index.php?oldid=7915687")!

    static func merged(_ references: [TraditionalEvidence]) -> [TraditionalEvidence] {
        var result: [TraditionalEvidence] = []
        for reference in references {
            if let index = result.firstIndex(where: { $0.id == reference.id }) {
                for quote in reference.quotes where !result[index].quotes.contains(quote) { result[index].quotes.append(quote) }
                for match in reference.matches where !result[index].matches.contains(match) { result[index].matches.append(match) }
            } else { result.append(reference) }
        }
        return result
    }

    static func text(_ references: [TraditionalEvidence]) -> String {
        merged(references).map(\.localizedText).joined(separator: "\n\n")
    }

    static func pair(_ first: Int, _ second: Int, context: String) -> [TraditionalEvidence] {
        let pair = XuanKongStarPair(first: first, second: second)
        guard let a = pair.firstElementIndex, let b = pair.secondElementIndex else { return [] }
        let match = context + " \(first)/\(second)"
        var references: [TraditionalEvidence] = []
        switch pair.relation {
        case .same:
            references.append(TraditionalEvidence(id: "elements.same", kind: .rule,
                titleKey: "ref_same_element", matches: [match]))
        case .firstGeneratesSecond, .secondGeneratesFirst:
            let index = pair.relation == .firstGeneratesSecond ? a : b
            let excerpt = ["木生火", "火生土", "土生金", "金生水", "水生木"][index]
            references.append(TraditionalEvidence(id: "elements.generating", kind: .classic,
                titleKey: "ref_elements_generating", quotes: [excerpt], matches: [match], sourceURL: elementsURL))
        case .firstControlsSecond, .secondControlsFirst:
            let index = pair.relation == .firstControlsSecond ? a : b
            let excerpt = ["木剋土", "火剋金", "土剋水", "金剋木", "水剋火"][index]
            references.append(TraditionalEvidence(id: "elements.controlling", kind: .classic,
                titleKey: "ref_elements_controlling", quotes: [excerpt], matches: [match], sourceURL: elementsURL))
        }
        func rule(_ id: String, _ key: String) {
            references.append(TraditionalEvidence(id: id, kind: .rule, titleKey: key, matches: [match]))
        }
        if first == 2 || second == 2 { rule("stars.two", "ref_star_two") }
        if first == 5 || second == 5 { rule("stars.five", "ref_star_five") }
        if first == 5 && second == 5 { rule("pair.five_five", "ref_pair_five_five") }
        let stars = Set([first, second])
        if stars == Set([2, 5]) { rule("pair.two_five", "ref_pair_two_five") }
        if stars == Set([1, 4]) { rule("pair.one_four", "ref_pair_one_four") }
        if stars == Set([1, 6]) { rule("pair.one_six", "ref_pair_one_six") }
        if stars == Set([3, 7]) { rule("pair.three_seven", "ref_pair_three_seven") }
        if stars == Set([7, 9]) { rule("pair.seven_nine", "ref_pair_seven_nine") }
        if first == 9 && second == 9 { rule("pair.nine_nine", "ref_pair_nine_nine") }
        return references
    }

    static func purpleWhite(year: Int, month: Int, palace: String) -> [TraditionalEvidence] {
        let lang = LocalizationManager.shared
        let match = palace + " · " + lang.t("xkd_pair_guests") + " \(year)/\(month)"
        var references = pair(year, month, context: palace + " · " + lang.t("xkd_pair_guests"))
        references.append(TraditionalEvidence(id: "purplewhite.timing", kind: .rule,
            titleKey: "ref_guest_timing", matches: [match]))
        // Match the advice's branch precedence; an 8/2 palace is a caution,
        // not a wealth reading with an unrelated Five-Yellow quote attached.
        if year != 2 && year != 5 && month != 2 && month != 5 {
            let key: String
            if year == 9 { key = "ref_year_nine" }
            else if year == 8 { key = "ref_year_eight" }
            else if [1, 4, 6].contains(year) { key = "ref_year_study" }
            else { key = "ref_year_ordinary" }
            references.append(TraditionalEvidence(id: "purplewhite.year.\(year)", kind: .rule,
                titleKey: key, matches: [match]))
        }
        return merged(references)
    }
}
