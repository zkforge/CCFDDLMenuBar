import AppKit
import Foundation

@MainActor
final class DeadlineStore: ObservableObject {
    @Published private(set) var now = Date()
    @Published private(set) var upcomingConferences: [Conference] = []
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var availableTypes = ConferenceTypeFormatter.orderedTypeCodes
    @Published private(set) var isShowingCachedData = false
    @Published private(set) var cacheTimestamp: Date?
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    @Published private(set) var filterKeyword: String
    @Published private(set) var selectedRanks: Set<String>
    @Published private(set) var selectedTypes: Set<String>
    @Published private(set) var onlyFavorites: Bool
    @Published private(set) var favoriteConferenceIDs: Set<String>
    @Published private(set) var notificationsEnabled: Bool
    @Published private(set) var sortOption: ConferenceSortOption
    @Published private(set) var menuBarPinnedConferenceID: String?
    @Published private(set) var language: AppLanguage

    private let service = CCFDDLService()
    private let preferencesStore = PreferencesStore()
    private let cacheStore = ConferenceCacheStore()
    private let notificationManager = DeadlineNotificationManager()
    private let calendarExportService = CalendarExportService()

    private var allUpcomingConferences: [Conference] = []
    private var started = false
    private var refreshLoopTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?

    init() {
        let preferences = preferencesStore.load()
        filterKeyword = preferences.filterKeyword
        selectedRanks = preferences.selectedRanks
        selectedTypes = preferences.selectedTypes
        onlyFavorites = preferences.onlyFavorites
        favoriteConferenceIDs = preferences.favoriteConferenceIDs
        notificationsEnabled = preferences.notificationsEnabled
        sortOption = preferences.sortOption
        menuBarPinnedConferenceID = preferences.menuBarPinnedConferenceID
        language = preferences.language
    }

    deinit {
        refreshLoopTask?.cancel()
        clockTask?.cancel()
    }

    var menuBarTitle: String {
        guard let displayedConference = menuBarDisplayedConference else {
            return "CCF"
        }
        let countdownText = CountdownFormatter.menuBarPrecise(
            from: now,
            to: displayedConference.deadlineDate,
            language: language
        )
        return "\(displayedConference.shortName): \(countdownText)"
    }

    var nearestConferenceByDeadline: Conference? {
        upcomingConferences.min(by: { $0.deadlineDate < $1.deadlineDate })
    }

    var menuBarConferenceCandidates: [Conference] {
        allUpcomingConferences
    }

    var menuBarPinnedConference: Conference? {
        guard let menuBarPinnedConferenceID else { return nil }
        return allUpcomingConferences.first { $0.id == menuBarPinnedConferenceID }
    }

    var menuBarDefaultConference: Conference? {
        nearestConferenceByDeadline
    }

    var menuBarDisplayedConference: Conference? {
        menuBarPinnedConference ?? menuBarDefaultConference
    }

    var lastRefreshText: String {
        guard let lastRefresh else {
            return AppLocalized.text(language: language, zh: "未刷新", en: "Not refreshed")
        }
        return DateTextFormatter.refreshText(for: lastRefresh, language: language)
    }

    var cacheText: String {
        guard let cacheTimestamp else {
            return AppLocalized.text(language: language, zh: "无缓存", en: "No cache")
        }
        return DateTextFormatter.deadlineText(for: cacheTimestamp, language: language)
    }

    var availableRanks: [String] {
        ["A", "B", "C", "N"]
    }

    func start() {
        guard !started else { return }
        started = true

        loadFromCacheOnStartup()
        triggerRefresh()
        startClock()
        startAutoRefreshLoop()
    }

    func triggerRefresh() {
        Task {
            await refresh()
        }
    }

    func openConference(_ conference: Conference) {
        guard let url = conference.linkURL else { return }
        NSWorkspace.shared.open(url)
    }

    func openHomePage() {
        guard let url = URL(string: "https://ccfddl.cn/") else { return }
        NSWorkspace.shared.open(url)
    }

    func isFavorite(_ conference: Conference) -> Bool {
        favoriteConferenceIDs.contains(conference.id)
    }

    func toggleFavorite(_ conference: Conference) {
        if favoriteConferenceIDs.contains(conference.id) {
            favoriteConferenceIDs.remove(conference.id)
        } else {
            favoriteConferenceIDs.insert(conference.id)
        }
        persistPreferences()
        refreshVisibleConferences()
    }

    func setFilterKeyword(_ keyword: String) {
        filterKeyword = keyword
        persistPreferences()
        refreshVisibleConferences()
    }

    func toggleRankFilter(_ rank: String) {
        if selectedRanks.contains(rank) {
            selectedRanks.remove(rank)
        } else {
            selectedRanks.insert(rank)
        }
        persistPreferences()
        refreshVisibleConferences()
    }

    func toggleTypeFilter(_ type: String) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
        persistPreferences()
        refreshVisibleConferences()
    }

    func setOnlyFavorites(_ enabled: Bool) {
        onlyFavorites = enabled
        persistPreferences()
        refreshVisibleConferences()
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled
        persistPreferences()
        Task {
            await notificationManager.schedule(conferences: allUpcomingConferences, enabled: enabled, language: language)
        }
    }

    func setSortOption(_ option: ConferenceSortOption) {
        sortOption = option
        persistPreferences()
        refreshVisibleConferences()
    }

    func setMenuBarPinnedConferenceID(_ conferenceID: String?) {
        menuBarPinnedConferenceID = conferenceID
        persistPreferences()
    }

    func setLanguage(_ value: AppLanguage) {
        guard language != value else { return }
        language = value
        persistPreferences()
        Task {
            await notificationManager.schedule(conferences: allUpcomingConferences, enabled: notificationsEnabled, language: language)
        }
    }

    func selectAllRanks() {
        selectedRanks = Set(availableRanks)
        persistPreferences()
        refreshVisibleConferences()
    }

    func clearRankFilters() {
        selectedRanks = []
        persistPreferences()
        refreshVisibleConferences()
    }

    func selectAllTypes() {
        selectedTypes = Set(availableTypes)
        persistPreferences()
        refreshVisibleConferences()
    }

    func clearTypeFilters() {
        selectedTypes = []
        persistPreferences()
        refreshVisibleConferences()
    }

    func exportVisibleConferencesAsICS() {
        let exportTargets = conferencesForExport()
        guard !exportTargets.isEmpty else {
            errorMessage = CalendarExportError.noConferenceData.message(language: language)
            return
        }

        Task {
            do {
                let exportURL = try await calendarExportService.exportICS(conferences: exportTargets, language: language)
                errorMessage = nil
                statusMessage = AppLocalized.text(
                    language: language,
                    zh: "已导出 \(exportTargets.count) 条到 \(exportURL.lastPathComponent)",
                    en: "Exported \(exportTargets.count) items to \(exportURL.lastPathComponent)"
                )
            } catch let exportError as CalendarExportError where exportError == .saveCanceled {
                statusMessage = exportError.message(language: language)
            } catch {
                errorMessage = localizedErrorMessage(error)
            }
        }
    }

    private func conferencesForExport() -> [Conference] {
        Array(upcomingConferences.prefix(200))
    }

    private func refresh() async {
        do {
            let conferences = try await service.fetchConferences()
            let current = Date()
            now = current

            allUpcomingConferences = conferences.filter { $0.deadlineDate >= current }
            updateAvailableTypes()
            refreshVisibleConferences()

            lastRefresh = current
            isShowingCachedData = false
            errorMessage = nil

            cacheStore.save(conferences: allUpcomingConferences, at: current)
            cacheTimestamp = current

            await notificationManager.schedule(conferences: allUpcomingConferences, enabled: notificationsEnabled, language: language)
        } catch {
            if let snapshot = cacheStore.load() {
                let current = Date()
                now = current
                allUpcomingConferences = snapshot.conferences.filter { $0.deadlineDate >= current }
                updateAvailableTypes()
                refreshVisibleConferences()

                isShowingCachedData = true
                cacheTimestamp = snapshot.savedAt
                errorMessage = AppLocalized.text(
                    language: language,
                    zh: "网络请求失败，已回退到缓存数据。",
                    en: "Network request failed. Fallback to cached data."
                )

                await notificationManager.schedule(conferences: allUpcomingConferences, enabled: notificationsEnabled, language: language)
            } else {
                errorMessage = localizedErrorMessage(error)
            }
        }
    }

    private func refreshVisibleConferences() {
        let filtered = allUpcomingConferences.filter { conference in
            if !selectedRanks.isEmpty && !selectedRanks.contains(conference.ccfRank) {
                return false
            }
            if !selectedTypes.isEmpty && !selectedTypes.contains(conference.type) {
                return false
            }
            if onlyFavorites && !favoriteConferenceIDs.contains(conference.id) {
                return false
            }
            return true
        }

        upcomingConferences = ConferenceSorter.sorted(
            conferences: filtered,
            favorites: favoriteConferenceIDs,
            option: sortOption
        )
    }

    private func updateAvailableTypes() {
        let dynamicTypes = Set(allUpcomingConferences.map(\.type))
        let predefined = ConferenceTypeFormatter.orderedTypeCodes
        let extras = dynamicTypes.subtracting(predefined).sorted()
        availableTypes = predefined + extras
    }

    private func persistPreferences() {
        let preferences = UserPreferences(
            filterKeyword: filterKeyword,
            selectedRanks: selectedRanks,
            selectedTypes: selectedTypes,
            onlyFavorites: onlyFavorites,
            favoriteConferenceIDs: favoriteConferenceIDs,
            notificationsEnabled: notificationsEnabled,
            sortOption: sortOption,
            menuBarPinnedConferenceID: menuBarPinnedConferenceID,
            language: language
        )
        preferencesStore.save(preferences)
    }

    private func loadFromCacheOnStartup() {
        guard let snapshot = cacheStore.load() else {
            return
        }
        let current = Date()
        now = current
        allUpcomingConferences = snapshot.conferences.filter { $0.deadlineDate >= current }
        updateAvailableTypes()
        refreshVisibleConferences()
        cacheTimestamp = snapshot.savedAt
        isShowingCachedData = !allUpcomingConferences.isEmpty

        Task {
            await notificationManager.schedule(conferences: allUpcomingConferences, enabled: notificationsEnabled, language: language)
        }
    }

    private func startClock() {
        clockTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                now = Date()

                let previousCount = allUpcomingConferences.count
                allUpcomingConferences.removeAll { $0.deadlineDate < now }
                if allUpcomingConferences.count != previousCount {
                    refreshVisibleConferences()
                }
            }
        }
    }

    private func startAutoRefreshLoop() {
        refreshLoopTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1800))
                await refresh()
            }
        }
    }

    private func localizedErrorMessage(_ error: Error) -> String {
        if let serviceError = error as? CCFDDLServiceError {
            return serviceError.message(language: language)
        }
        if let exportError = error as? CalendarExportError {
            return exportError.message(language: language)
        }
        return error.localizedDescription
    }
}
