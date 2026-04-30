import Foundation

enum OOTDPresetTag: String, CaseIterable, Identifiable, Codable {
    case commute
    case casual
    case weekend
    case date
    case formal
    case sport
    case travel
    case party
    case ceremony
    case school

    var id: String { rawValue }

    var title: String {
        switch self {
        case .commute:
            return "通勤"
        case .casual:
            return "休闲"
        case .weekend:
            return "周末"
        case .date:
            return "约会"
        case .formal:
            return "正式"
        case .sport:
            return "运动"
        case .travel:
            return "旅行"
        case .party:
            return "聚会"
        case .ceremony:
            return "仪式"
        case .school:
            return "上学"
        }
    }

    var symbolName: String {
        switch self {
        case .commute:
            return "briefcase"
        case .casual:
            return "figure.walk"
        case .weekend:
            return "cup.and.saucer"
        case .date:
            return "heart"
        case .formal:
            return "checkmark.seal"
        case .sport:
            return "figure.run"
        case .travel:
            return "airplane.departure"
        case .party:
            return "sparkles"
        case .ceremony:
            return "camera"
        case .school:
            return "book"
        }
    }

    static func normalizedTags(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",，、#\n\t")
        var seen: Set<String> = []
        var tags: [String] = []

        for part in text.components(separatedBy: separators) {
            let normalized = normalizedTag(part)
            guard !normalized.isEmpty else { continue }
            let key = normalized.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            tags.append(normalized)
        }

        return tags
    }

    static func normalizedText(from text: String) -> String {
        normalizedTags(from: text).joined(separator: "，")
    }

    static func text(from tags: [String]) -> String {
        var seen: Set<String> = []
        var normalizedTags: [String] = []

        for tag in tags {
            let normalized = normalizedTag(tag)
            guard !normalized.isEmpty else { continue }
            let key = normalized.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            normalizedTags.append(normalized)
        }

        return normalizedTags.joined(separator: "，")
    }

    private static func normalizedTag(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let knownTag = allCases.first(where: {
            $0.title.caseInsensitiveCompare(trimmed) == .orderedSame ||
            $0.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return knownTag.title
        }

        return String(trimmed.prefix(12))
    }
}
