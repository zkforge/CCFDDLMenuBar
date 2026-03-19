import AppKit
import SwiftUI

private enum PreferencesTab: String, Hashable {
    case general
    case about
}

struct SettingsView: View {
    @ObservedObject var store: DeadlineStore

    private let rankColumns = [GridItem(.adaptive(minimum: 122), spacing: 8)]
    private let typeColumns = [GridItem(.adaptive(minimum: 180), spacing: 8)]

    @State private var selectedTab: PreferencesTab = .general
    @State private var showingMenuBarConferencePicker = false
    @State private var menuBarConferenceSearchQuery = ""

    var body: some View {
        TabView(selection: self.$selectedTab) {
            generalPane
                .tabItem { Label(t("通用", "General"), systemImage: "gearshape") }
                .tag(PreferencesTab.general)

            aboutPane
                .tabItem { Label(t("关于", "About"), systemImage: "info.circle") }
                .tag(PreferencesTab.about)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(width: SettingsWindowLayout.width, height: SettingsWindowLayout.height)
        .sheet(isPresented: self.$showingMenuBarConferencePicker) {
            MenuBarConferencePickerSheet(
                store: self.store,
                searchQuery: self.$menuBarConferenceSearchQuery,
                language: self.store.language,
                onClose: { self.showingMenuBarConferencePicker = false }
            )
        }
    }

    private var generalPane: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                systemSection
                filterSection
                automationSection
                dangerSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
    }

    private var systemSection: some View {
        SettingsCard(
            title: t("通用", "General"),
            subtitle: t("全局行为与显示设置。", "Global behavior and display preferences.")
        ) {
            SettingsLabeledRow(
                title: t("界面语言", "Language"),
                subtitle: t("立即切换软件显示语言。", "Switch app display language immediately.")
            ) {
                Picker("", selection: Binding(
                    get: { self.store.language },
                    set: { self.store.setLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            Divider()

            PreferenceToggleRow(
                title: t("会前提醒", "Session quota notifications"),
                subtitle: t("截止前 24h / 6h / 1h 提醒。", "Notify at 24h / 6h / 1h before deadline."),
                binding: Binding(
                    get: { self.store.notificationsEnabled },
                    set: { self.store.setNotificationsEnabled($0) }
                )
            )

            Divider()

            SettingsLabeledRow(
                title: t("菜单栏会议", "Menu bar conference"),
                subtitle: t("默认显示 CCF，也可固定显示某个会议倒计时。", "Display CCF by default, or pin a specific conference countdown.")
            ) {
                HStack(spacing: 8) {
                    Text(self.menuBarPinnedConferenceLabel)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 230, alignment: .leading)

                    Button(t("选择", "Choose")) {
                        self.menuBarConferenceSearchQuery = ""
                        self.showingMenuBarConferencePicker = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button(t("默认", "Default")) {
                        self.store.setMenuBarPinnedConferenceID(nil)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var filterSection: some View {
        SettingsCard(
            title: t("筛选", "Filters"),
            subtitle: t("控制设置窗口和菜单栏中会议的可见范围。", "Control which conferences are visible in settings and menu bar.")
        ) {
            PreferenceToggleRow(
                title: t("仅收藏", "Only favorites"),
                subtitle: t("仅显示已收藏会议。", "Show only favorited conferences."),
                binding: Binding(
                    get: { self.store.onlyFavorites },
                    set: { self.store.setOnlyFavorites($0) }
                )
            )

            Divider()

            SettingsFilterGroup(
                title: t("CCF 等级", "CCF rank"),
                subtitle: t("可多选；未选择时表示不过滤。", "Multi-select; empty means no rank filtering."),
                selectedCount: store.selectedRanks.count,
                totalCount: store.availableRanks.count,
                allText: t("全选", "All"),
                clearText: t("清空", "Clear"),
                onSelectAll: { store.selectAllRanks() },
                onClear: { store.clearRankFilters() }
            ) {
                LazyVGrid(columns: self.rankColumns, alignment: .leading, spacing: 8) {
                    ForEach(self.store.availableRanks, id: \.self) { rank in
                        SettingsFilterChip(
                            title: "CCF \(rank)",
                            selected: self.store.selectedRanks.contains(rank)
                        ) {
                            self.store.toggleRankFilter(rank)
                        }
                    }
                }
            }

            Divider()

            SettingsFilterGroup(
                title: t("研究方向", "Research category"),
                subtitle: t("可多选；未选择时表示不过滤。", "Multi-select; empty means no category filtering."),
                selectedCount: store.selectedTypes.count,
                totalCount: store.availableTypes.count,
                allText: t("全选", "All"),
                clearText: t("清空", "Clear"),
                onSelectAll: { store.selectAllTypes() },
                onClear: { store.clearTypeFilters() }
            ) {
                LazyVGrid(columns: self.typeColumns, alignment: .leading, spacing: 8) {
                    ForEach(self.store.availableTypes, id: \.self) { type in
                        SettingsFilterChip(
                            title: ConferenceTypeFormatter.displayName(for: type, language: store.language),
                            selected: self.store.selectedTypes.contains(type)
                        ) {
                            self.store.toggleTypeFilter(type)
                        }
                    }
                }
            }
        }
    }

    private var automationSection: some View {
        SettingsCard(
            title: t("自动化", "Automation"),
            subtitle: t("刷新、排序与导出。", "Refresh, sorting, and export actions.")
        ) {
            SettingsLabeledRow(
                title: t("列表排序", "Conference sort"),
                subtitle: t("控制会议列表排序方式。", "Control sorting behavior for conference list.")
            ) {
                Picker(
                    "",
                    selection: Binding(
                        get: { self.store.sortOption },
                        set: { self.store.setSortOption($0) }
                    )
                ) {
                    ForEach(ConferenceSortOption.allCases) { option in
                        Text(option.title(language: store.language)).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 180)
            }

            Divider()

            SettingsLabeledRow(
                title: t("日历导出", "Calendar export"),
                subtitle: t("导出 .ics 文件。", "Export .ics files.")
            ) {
                Button(t("导出 .ics", "Export .ics")) {
                    self.store.exportVisibleConferencesAsICS()
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            SettingsLabeledRow(
                title: t("立即刷新", "Refresh now"),
                subtitle: t("立即拉取最新会议数据。", "Fetch latest conference data now." )
            ) {
                Button(t("刷新", "Refresh")) {
                    self.store.triggerRefresh()
                }
                .buttonStyle(.bordered)
            }

            if let statusMessage = self.store.statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let errorMessage = self.store.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var dangerSection: some View {
        SettingsCard(
            title: t("应用", "Application"),
            subtitle: t("退出当前菜单栏应用进程。", "Terminate the current menu bar app process.")
        ) {
            HStack {
                Spacer()
                Button(t("退出 ConfBar", "Quit ConfBar")) {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var aboutPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard(
                title: "ConfBar",
                subtitle: t("会议截止日期菜单栏工具。数据来源于 ccfddl.cn。", "A menu bar tool for conference deadlines. Data source: ccfddl.cn.")
            ) {
                Button(t("打开 ccfddl.cn", "Open ccfddl.cn")) {
                    self.store.openHomePage()
                }
                .buttonStyle(.bordered)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var menuBarPinnedConferenceLabel: String {
        if let pinnedConference = store.menuBarPinnedConference {
            return "\(pinnedConference.shortName) · \(DateTextFormatter.deadlineText(for: pinnedConference.deadlineDate, language: store.language))"
        }
        if let defaultConference = store.menuBarDefaultConference {
            let dateText = DateTextFormatter.deadlineText(for: defaultConference.deadlineDate, language: store.language)
            return t("默认（最近截止）：", "Default (nearest): ") + "\(defaultConference.shortName) · \(dateText)"
        }
        return t("默认（最近截止）", "Default (nearest)")
    }

    private func t(_ zh: String, _ en: String) -> String {
        AppLocalized.text(language: store.language, zh: zh, en: en)
    }
}
