import AppKit
import SwiftUI

struct MenuContentView: View {
    private enum ConferenceActionKind {
        case favorite(active: Bool)
        case open
    }

    private struct ConferenceActionStyle {
        let systemName: String
        let foreground: Color
        let background: Color
        let border: Color
    }

    @ObservedObject var store: DeadlineStore
    @Environment(\.openWindow) private var openWindow
    private static let panelWidth: CGFloat = 300
    private static let panelAspectRatio: CGFloat = 695.0 / 430.0
    private static let panelHeight: CGFloat = panelWidth * panelAspectRatio

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerBar

            if let errorMessage = store.errorMessage {
                statusBanner(text: errorMessage, color: .red, icon: "exclamationmark.triangle.fill")
            }

            if store.isShowingCachedData {
                statusBanner(
                    text: t("当前显示缓存数据（\(store.cacheText)）", "Showing cached data (\(store.cacheText))"),
                    color: .secondary,
                    icon: "externaldrive"
                )
            }

            if let nearest = store.nearestConferenceByDeadline {
                nearestConferenceCard(nearest)
            }

            conferenceList
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            bottomBar
        }
        .padding(14)
        .frame(width: Self.panelWidth, height: Self.panelHeight)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.04), Color.teal.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            store.start()
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center) {
            Text(t("会议截止", "Conference Deadlines"))
                .font(.headline)

            Spacer()

            Text("\(store.upcomingConferences.count) DDL")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
                .padding(.vertical, 4)
                .padding(.horizontal, 9)
                .background(Capsule().fill(Color.orange.opacity(0.14)))
        }
    }

    private var conferenceList: some View {
        Group {
            if store.upcomingConferences.isEmpty {
                Text(t("暂无匹配会议（筛选在设置窗口）", "No matching conferences (adjust filters in Settings)."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(store.upcomingConferences.prefix(30)) { conference in
                            conferenceRow(conference)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func openSettingsWindow() {
        openWindow(id: AppWindowID.settings)
        NSApp.activate(ignoringOtherApps: true)
    }

    @ViewBuilder
    private func statusBanner(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(color)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
        )
    }

    @ViewBuilder
    private func nearestConferenceCard(_ conference: Conference) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t("最近截止", "Nearest Deadline"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(CountdownFormatter.menuBarPrecise(from: store.now, to: conference.deadlineDate, language: store.language))
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conference.shortName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text(DateTextFormatter.deadlineText(for: conference.deadlineDate, language: store.language))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                HStack(spacing: 8) {
                    conferenceActionIconButton(
                        kind: .favorite(active: store.isFavorite(conference)),
                        onDarkBackground: true
                    ) {
                        store.toggleFavorite(conference)
                    }
                    conferenceActionIconButton(kind: .open, onDarkBackground: true) {
                        store.openConference(conference)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.91, green: 0.40, blue: 0.22),
                            Color(red: 0.89, green: 0.56, blue: 0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    @ViewBuilder
    private func conferenceRow(_ conference: Conference) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(conference.shortName)
                    .font(.body.weight(.semibold))

                Spacer()

                HStack(spacing: 8) {
                    conferenceActionIconButton(
                        kind: .favorite(active: store.isFavorite(conference)),
                        onDarkBackground: false
                    ) {
                        store.toggleFavorite(conference)
                    }
                    .help(t("收藏", "Favorite"))

                    conferenceActionIconButton(kind: .open, onDarkBackground: false) {
                        store.openConference(conference)
                    }
                    .help(t("打开", "Open"))
                }
            }

            Text(CountdownFormatter.detailed(from: store.now, to: conference.deadlineDate, language: store.language))
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                badge("CCF \(conference.ccfRank)", tint: .blue)
                badge(ConferenceTypeFormatter.displayName(for: conference.type, language: store.language), tint: .teal)
            }

            Text(DateTextFormatter.deadlineText(for: conference.deadlineDate, language: store.language))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 3)
            .padding(.horizontal, 7)
            .background(Capsule().fill(tint.opacity(0.88)))
    }

    @ViewBuilder
    private func conferenceActionIconButton(
        kind: ConferenceActionKind,
        onDarkBackground: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let style = conferenceActionStyle(for: kind, onDarkBackground: onDarkBackground)
        Button(action: action) {
            Image(systemName: style.systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(style.foreground)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(style.background)
                )
                .overlay(
                    Circle().stroke(
                        style.border,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private func conferenceActionStyle(
        for kind: ConferenceActionKind,
        onDarkBackground: Bool
    ) -> ConferenceActionStyle {
        switch kind {
        case .favorite(let active):
            if active {
                return ConferenceActionStyle(
                    systemName: "star.fill",
                    foreground: Color.yellow,
                    background: onDarkBackground ? Color.yellow.opacity(0.22) : Color.yellow.opacity(0.18),
                    border: onDarkBackground ? Color.orange.opacity(0.75) : Color.orange.opacity(0.45)
                )
            }
            return ConferenceActionStyle(
                systemName: "star",
                foreground: onDarkBackground ? Color.white.opacity(0.92) : Color.secondary,
                background: onDarkBackground ? Color.white.opacity(0.20) : Color.gray.opacity(0.14),
                border: onDarkBackground ? Color.white.opacity(0.28) : Color.black.opacity(0.09)
            )
        case .open:
            return ConferenceActionStyle(
                systemName: "arrow.up.right.square",
                foreground: onDarkBackground ? Color.white : Color(red: 0.18, green: 0.46, blue: 0.98),
                background: onDarkBackground ? Color.white.opacity(0.20) : Color(red: 0.18, green: 0.46, blue: 0.98).opacity(0.14),
                border: onDarkBackground ? Color.white.opacity(0.28) : Color(red: 0.18, green: 0.46, blue: 0.98).opacity(0.35)
            )
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 6) {
            Divider()
            menuActionRow(title: t("设置…", "Settings…"), systemName: "gearshape") {
                openSettingsWindow()
            }
            menuActionRow(title: t("退出 CCFDDL", "Quit CCFDDL"), systemName: "power") {
                NSApp.terminate(nil)
            }
        }
    }

    @ViewBuilder
    private func menuActionRow(title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.body)
                    .frame(width: 18)
                Text(title)
                    .font(.body)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    private func t(_ zh: String, _ en: String) -> String {
        AppLocalized.text(language: store.language, zh: zh, en: en)
    }
}
