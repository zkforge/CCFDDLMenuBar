import Foundation

struct ConferenceCacheSnapshot: Codable {
    let savedAt: Date
    let conferences: [Conference]
}

struct UserPreferences: Codable {
    var filterKeyword: String
    var selectedRanks: Set<String>
    var selectedTypes: Set<String>
    var onlyFavorites: Bool
    var favoriteConferenceIDs: Set<String>
    var notificationsEnabled: Bool
    var sortOption: ConferenceSortOption
    var menuBarPinnedConferenceID: String?
    var language: AppLanguage

    enum CodingKeys: String, CodingKey {
        case filterKeyword
        case selectedRanks
        case selectedTypes
        case onlyFavorites
        case favoriteConferenceIDs
        case notificationsEnabled
        case sortOption
        case menuBarPinnedConferenceID
        case language
    }

    static let `default` = UserPreferences(
        filterKeyword: "",
        selectedRanks: [],
        selectedTypes: [],
        onlyFavorites: false,
        favoriteConferenceIDs: [],
        notificationsEnabled: true,
        sortOption: .deadline,
        menuBarPinnedConferenceID: nil,
        language: .systemDefault
    )

    init(
        filterKeyword: String,
        selectedRanks: Set<String>,
        selectedTypes: Set<String>,
        onlyFavorites: Bool,
        favoriteConferenceIDs: Set<String>,
        notificationsEnabled: Bool,
        sortOption: ConferenceSortOption,
        menuBarPinnedConferenceID: String?,
        language: AppLanguage
    ) {
        self.filterKeyword = filterKeyword
        self.selectedRanks = selectedRanks
        self.selectedTypes = selectedTypes
        self.onlyFavorites = onlyFavorites
        self.favoriteConferenceIDs = favoriteConferenceIDs
        self.notificationsEnabled = notificationsEnabled
        self.sortOption = sortOption
        self.menuBarPinnedConferenceID = menuBarPinnedConferenceID
        self.language = language
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        filterKeyword = try container.decodeIfPresent(String.self, forKey: .filterKeyword) ?? ""
        selectedRanks = try container.decodeIfPresent(Set<String>.self, forKey: .selectedRanks) ?? []
        selectedTypes = try container.decodeIfPresent(Set<String>.self, forKey: .selectedTypes) ?? []
        onlyFavorites = try container.decodeIfPresent(Bool.self, forKey: .onlyFavorites) ?? false
        favoriteConferenceIDs = try container.decodeIfPresent(Set<String>.self, forKey: .favoriteConferenceIDs) ?? []
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        sortOption = try container.decodeIfPresent(ConferenceSortOption.self, forKey: .sortOption) ?? .deadline
        menuBarPinnedConferenceID = try container.decodeIfPresent(String.self, forKey: .menuBarPinnedConferenceID)
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .systemDefault
    }
}

struct PreferencesStore {
    private let defaults: UserDefaults
    private let key = "ccfddl.preferences.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> UserPreferences {
        guard let data = defaults.data(forKey: key) else {
            return .default
        }
        do {
            return try JSONDecoder().decode(UserPreferences.self, from: data)
        } catch {
            return .default
        }
    }

    func save(_ preferences: UserPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}

struct ConferenceCacheStore {
    private let fileManager: FileManager
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directoryURL = baseURL.appendingPathComponent("CCFDDLMenuBar", isDirectory: true)
        self.fileURL = directoryURL.appendingPathComponent("conference_cache.json")
    }

    func save(conferences: [Conference], at date: Date) {
        do {
            try ensureDirectory()
            let snapshot = ConferenceCacheSnapshot(savedAt: date, conferences: conferences)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Ignore cache write failures.
        }
    }

    func load() -> ConferenceCacheSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return try? JSONDecoder().decode(ConferenceCacheSnapshot.self, from: data)
    }

    private func ensureDirectory() throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }
}
