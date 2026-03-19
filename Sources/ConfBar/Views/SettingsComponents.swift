import SwiftUI

@MainActor
struct PreferenceToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var binding: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5.4) {
            Toggle(isOn: self.$binding) {
                Text(self.title)
                    .font(.body)
            }
            .toggleStyle(.switch)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct MenuBarConferencePickerSheet: View {
    private enum SortOption: String, CaseIterable, Identifiable {
        case deadline
        case name

        var id: String { rawValue }
    }

    @ObservedObject var store: DeadlineStore
    @Binding var searchQuery: String
    let language: AppLanguage
    let onClose: () -> Void
    @State private var sortOption: SortOption = .deadline

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t("选择菜单栏会议", "Select Menu Bar Conference"))
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(t("关闭", "Close")) {
                    onClose()
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                TextField(
                    t("搜索会议（简称/别名/模糊匹配）", "Search (abbr/alias/fuzzy)"),
                    text: $searchQuery
                )
                .textFieldStyle(.roundedBorder)

                Picker("", selection: $sortOption) {
                    Text(t("最近截止", "Nearest deadline")).tag(SortOption.deadline)
                    Text(t("名称 A-Z", "Name A-Z")).tag(SortOption.name)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 140)
            }

            Text(t("匹配 \(filteredConferences.count) 项", "\(filteredConferences.count) matches"))
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                defaultRow

                if !favoriteFilteredConferences.isEmpty {
                    Section(t("收藏会议", "Favorites")) {
                        ForEach(favoriteFilteredConferences) { conference in
                            conferenceRow(conference)
                        }
                    }
                }

                if !normalFilteredConferences.isEmpty {
                    Section(t("全部会议", "All Conferences")) {
                        ForEach(normalFilteredConferences) { conference in
                            conferenceRow(conference)
                        }
                    }
                }
            }
            .frame(minHeight: 360)
        }
        .padding(16)
        .frame(width: 560, height: 520)
    }

    private var filteredConferences: [Conference] {
        let filtered = store.menuBarConferenceCandidates.filter { conference in
            ConferenceSearchMatcher.matches(query: searchQuery, conference: conference)
        }
        return sort(filtered)
    }

    private var favoriteFilteredConferences: [Conference] {
        filteredConferences.filter { store.isFavorite($0) }
    }

    private var normalFilteredConferences: [Conference] {
        filteredConferences.filter { !store.isFavorite($0) }
    }

    private func sort(_ conferences: [Conference]) -> [Conference] {
        conferences.sorted { lhs, rhs in
            switch sortOption {
            case .deadline:
                if lhs.deadlineDate != rhs.deadlineDate {
                    return lhs.deadlineDate < rhs.deadlineDate
                }
                return lhs.shortName.localizedCaseInsensitiveCompare(rhs.shortName) == .orderedAscending
            case .name:
                let nameOrder = lhs.shortName.localizedCaseInsensitiveCompare(rhs.shortName)
                if nameOrder != .orderedSame {
                    return nameOrder == .orderedAscending
                }
                return lhs.deadlineDate < rhs.deadlineDate
            }
        }
    }

    private var defaultRow: some View {
        Button {
            store.setMenuBarPinnedConferenceID(nil)
            onClose()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("默认（最近截止）", "Default (nearest deadline)"))
                    .font(.body)
                if let defaultConference = store.menuBarDefaultConference {
                    Text("\(defaultConference.shortName) · \(DateTextFormatter.deadlineText(for: defaultConference.deadlineDate, language: language))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if store.menuBarPinnedConferenceID == nil {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .buttonStyle(.plain)
    }

    private func conferenceRow(_ conference: Conference) -> some View {
        Button {
            store.setMenuBarPinnedConferenceID(conference.id)
            onClose()
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(conference.shortName)
                        .font(.body.weight(.medium))
                    Text(DateTextFormatter.deadlineText(for: conference.deadlineDate, language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.menuBarPinnedConferenceID == conference.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func t(_ zh: String, _ en: String) -> String {
        AppLocalized.text(language: language, zh: zh, en: en)
    }
}
