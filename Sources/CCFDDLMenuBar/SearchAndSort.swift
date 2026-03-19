import Foundation

enum ConferenceSortOption: String, Codable, CaseIterable, Identifiable {
    case deadline
    case conferenceDate
    case ccfRank

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .deadline:
            return AppLocalized.text(language: language, zh: "距离截止", en: "Deadline")
        case .conferenceDate:
            return AppLocalized.text(language: language, zh: "会议日期", en: "Conference Date")
        case .ccfRank:
            return AppLocalized.text(language: language, zh: "CCF等级", en: "CCF Rank")
        }
    }
}

enum ConferenceSorter {
    private static let dateDetector: NSDataDetector? = {
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    }()

    static func sorted(
        conferences: [Conference],
        favorites: Set<String>,
        option: ConferenceSortOption
    ) -> [Conference] {
        conferences.sorted { lhs, rhs in
            let lhsFavorite = favorites.contains(lhs.id)
            let rhsFavorite = favorites.contains(rhs.id)
            if lhsFavorite != rhsFavorite {
                return lhsFavorite
            }

            switch option {
            case .deadline:
                if lhs.deadlineDate != rhs.deadlineDate {
                    return lhs.deadlineDate < rhs.deadlineDate
                }
            case .conferenceDate:
                let lhsConferenceStart = detectConferenceStartDate(from: lhs.conferenceDate) ?? lhs.deadlineDate
                let rhsConferenceStart = detectConferenceStartDate(from: rhs.conferenceDate) ?? rhs.deadlineDate
                if lhsConferenceStart != rhsConferenceStart {
                    return lhsConferenceStart < rhsConferenceStart
                }
                if lhs.deadlineDate != rhs.deadlineDate {
                    return lhs.deadlineDate < rhs.deadlineDate
                }
            case .ccfRank:
                let lhsRankWeight = ccfRankWeight(lhs.ccfRank)
                let rhsRankWeight = ccfRankWeight(rhs.ccfRank)
                if lhsRankWeight != rhsRankWeight {
                    return lhsRankWeight < rhsRankWeight
                }
                if lhs.deadlineDate != rhs.deadlineDate {
                    return lhs.deadlineDate < rhs.deadlineDate
                }
            }

            return lhs.shortName.localizedCaseInsensitiveCompare(rhs.shortName) == .orderedAscending
        }
    }

    private static func ccfRankWeight(_ rank: String) -> Int {
        switch rank.uppercased() {
        case "A": return 0
        case "B": return 1
        case "C": return 2
        case "N": return 3
        default: return 4
        }
    }

    private static func detectConferenceStartDate(from text: String) -> Date? {
        guard !text.isEmpty, let dateDetector else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = dateDetector.firstMatch(in: text, options: [], range: range) else {
            return nil
        }
        return match.date
    }
}

enum ConferenceSearchMatcher {
    private static let aliasMap: [String: Set<String>] = {
        let aliasGroups: [[String]] = [
            ["neurips", "nips"],
            ["acmmm", "mm"],
            ["icassp", "international conference on acoustics speech and signal processing"],
            ["ijcai", "international joint conference on artificial intelligence"]
        ]

        var map: [String: Set<String>] = [:]
        for group in aliasGroups {
            let normalizedGroup = group.map { normalize($0) }
            for item in normalizedGroup {
                map[item, default: []].formUnion(normalizedGroup.filter { $0 != item })
            }
        }
        return map
    }()

    static func matches(query: String, conference: Conference) -> Bool {
        let normalizedQuery = normalize(query).trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedQuery.isEmpty {
            return true
        }

        let baseSearchText = [
            conference.shortName,
            conference.place,
            conference.conferenceDate,
            conference.ccfRank,
            conference.type,
            ConferenceTypeFormatter.searchableNames(for: conference.type).joined(separator: " ")
        ]
        .joined(separator: " ")
        let normalizedText = normalize(baseSearchText)
        if normalizedText.contains(normalizedQuery) {
            return true
        }

        let queryTokens = asciiTokens(from: normalizedQuery)
        if queryTokens.isEmpty {
            return false
        }

        var candidateTokens = Set(asciiTokens(from: normalizedText))
        let normalizedShortName = normalize(conference.shortName)
        candidateTokens.formUnion(aliasMap[normalizedShortName] ?? [])
        for displayName in ConferenceTypeFormatter.searchableNames(for: conference.type) {
            candidateTokens.formUnion(asciiTokens(from: displayName))
        }

        for token in queryTokens {
            let expandedQueryTokens = expandedAliases(for: token)
            let matched = expandedQueryTokens.contains { expanded in
                containsMatch(expanded, in: candidateTokens) || fuzzyMatch(expanded, in: candidateTokens)
            }
            if !matched {
                return false
            }
        }

        return true
    }

    private static func containsMatch(_ token: String, in candidates: Set<String>) -> Bool {
        candidates.contains { $0.contains(token) }
    }

    private static func expandedAliases(for token: String) -> Set<String> {
        var expanded = Set([token])
        expanded.formUnion(aliasMap[token] ?? [])
        return expanded
    }

    private static func fuzzyMatch(_ token: String, in candidates: Set<String>) -> Bool {
        let threshold = distanceThreshold(for: token)
        for candidate in candidates {
            if abs(candidate.count - token.count) > threshold {
                continue
            }
            if levenshteinDistance(token, candidate) <= threshold {
                return true
            }
        }
        return false
    }

    private static func distanceThreshold(for token: String) -> Int {
        switch token.count {
        case 0...4: return 1
        case 5...8: return 2
        default: return 3
        }
    }

    private static func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func asciiTokens(from text: String) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        return text
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
    }

    private static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        if lhsChars.isEmpty { return rhsChars.count }
        if rhsChars.isEmpty { return lhsChars.count }

        var previous = Array(0...rhsChars.count)
        var current = Array(repeating: 0, count: rhsChars.count + 1)

        for (i, lhsChar) in lhsChars.enumerated() {
            current[0] = i + 1
            for (j, rhsChar) in rhsChars.enumerated() {
                let substitutionCost = lhsChar == rhsChar ? 0 : 1
                let deletion = previous[j + 1] + 1
                let insertion = current[j] + 1
                let substitution = previous[j] + substitutionCost
                current[j + 1] = min(deletion, insertion, substitution)
            }
            swap(&previous, &current)
        }
        return previous[rhsChars.count]
    }
}
