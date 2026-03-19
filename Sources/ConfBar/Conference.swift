import Foundation

struct Conference: Identifiable, Hashable, Codable {
    let id: String
    let shortName: String
    let type: String
    let ccfRank: String
    let deadlineDate: Date
    let sourceDeadlineText: String
    let timezone: String
    let conferenceDate: String
    let place: String
    let linkURL: URL?
}

enum ConferenceTypeFormatter {
    private struct LocalizedTypeName {
        let zh: String
        let en: String
    }

    private static let typeMap: [String: LocalizedTypeName] = [
        "DS": LocalizedTypeName(zh: "计算机体系结构", en: "Computer Architecture"),
        "NW": LocalizedTypeName(zh: "计算机网络", en: "Computer Network"),
        "SC": LocalizedTypeName(zh: "网络与信息安全", en: "Security"),
        "SE": LocalizedTypeName(zh: "软件工程/系统软件", en: "Software Engineering"),
        "DB": LocalizedTypeName(zh: "数据库/数据挖掘", en: "Database & Mining"),
        "CT": LocalizedTypeName(zh: "计算机科学理论", en: "CS Theory"),
        "CG": LocalizedTypeName(zh: "计算机图形学与多媒体", en: "Graphics & Multimedia"),
        "AI": LocalizedTypeName(zh: "人工智能", en: "Artificial Intelligence"),
        "HI": LocalizedTypeName(zh: "人机交互与普适计算", en: "HCI & Ubiquitous"),
        "MX": LocalizedTypeName(zh: "交叉/综合/新兴", en: "Interdisciplinary")
    ]

    static var orderedTypeCodes: [String] {
        ["AI", "DS", "NW", "SC", "SE", "DB", "CT", "CG", "HI", "MX"]
    }

    static func displayName(for code: String, language: AppLanguage) -> String {
        guard let item = typeMap[code] else {
            return code
        }
        return language == .chinese ? item.zh : item.en
    }

    static func displayName(for code: String) -> String {
        displayName(for: code, language: .systemDefault)
    }

    static func searchableNames(for code: String) -> [String] {
        guard let item = typeMap[code] else {
            return [code]
        }
        return [code, item.zh, item.en]
    }
}

enum CountdownFormatter {
    static func compact(from now: Date, to deadline: Date, language: AppLanguage) -> String {
        let seconds = Int(deadline.timeIntervalSince(now))
        if seconds <= 0 {
            return AppLocalized.text(language: language, zh: "已截止", en: "Due")
        }

        let days = seconds / 86_400
        if days > 0 {
            return "D-\(days)"
        }

        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        return String(format: "%02dh%02dm", hours, minutes)
    }

    static func detailed(from now: Date, to deadline: Date, language: AppLanguage) -> String {
        let seconds = Int(deadline.timeIntervalSince(now))
        if seconds <= 0 {
            return AppLocalized.text(language: language, zh: "已截止", en: "Due")
        }

        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60

        if days > 0 {
            return AppLocalized.text(
                language: language,
                zh: "\(days)天 \(hours)小时",
                en: "\(days)d \(hours)h"
            )
        }
        return AppLocalized.text(
            language: language,
            zh: "\(hours)小时 \(minutes)分钟",
            en: "\(hours)h \(minutes)m"
        )
    }

    static func menuBarPrecise(from now: Date, to deadline: Date, language: AppLanguage) -> String {
        let totalSeconds = max(0, Int(deadline.timeIntervalSince(now)))
        if totalSeconds == 0 {
            return AppLocalized.text(language: language, zh: "0分", en: "0m")
        }

        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60

        var parts: [String] = []
        if days > 0 {
            parts.append(AppLocalized.text(language: language, zh: "\(days)天", en: "\(days)d"))
        }
        if days > 0 || hours > 0 {
            parts.append(AppLocalized.text(language: language, zh: "\(hours)时", en: "\(hours)h"))
        }
        if days > 0 || hours > 0 || minutes > 0 {
            parts.append(AppLocalized.text(language: language, zh: "\(minutes)分", en: "\(minutes)m"))
        }
        return parts.joined(separator: " ")
    }
}

enum DateTextFormatter {
    private static func formatter(language: AppLanguage) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        if language == .chinese {
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
        } else {
            formatter.dateFormat = "MMM d, yyyy HH:mm"
        }
        formatter.timeZone = .current
        return formatter
    }

    private static func refreshFormatter(language: AppLanguage) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = .current
        return formatter
    }

    static func deadlineText(for date: Date, language: AppLanguage) -> String {
        formatter(language: language).string(from: date)
    }

    static func refreshText(for date: Date, language: AppLanguage) -> String {
        refreshFormatter(language: language).string(from: date)
    }
}
