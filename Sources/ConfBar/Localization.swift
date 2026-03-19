import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case chinese
    case english

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .chinese:
            return Locale(identifier: "zh_CN")
        case .english:
            return Locale(identifier: "en_US_POSIX")
        }
    }

    var displayName: String {
        switch self {
        case .chinese:
            return "中文"
        case .english:
            return "English"
        }
    }

    static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferred.hasPrefix("zh") ? .chinese : .english
    }
}

enum AppLocalized {
    static func text(language: AppLanguage, zh: String, en: String) -> String {
        language == .chinese ? zh : en
    }
}
