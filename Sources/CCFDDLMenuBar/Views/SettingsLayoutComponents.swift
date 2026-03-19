import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    private let content: () -> Content

    init(
        title: String,
        subtitle: String?,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

struct SettingsLabeledRow<Content: View>: View {
    let title: String
    let subtitle: String
    private let trailing: () -> Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            trailing()
        }
    }
}

struct SettingsFilterGroup<Content: View>: View {
    let title: String
    let subtitle: String
    let selectedCount: Int
    let totalCount: Int
    let allText: String
    let clearText: String
    let onSelectAll: () -> Void
    let onClear: () -> Void
    private let content: () -> Content

    init(
        title: String,
        subtitle: String,
        selectedCount: Int,
        totalCount: Int,
        allText: String,
        clearText: String,
        onSelectAll: @escaping () -> Void,
        onClear: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.selectedCount = selectedCount
        self.totalCount = totalCount
        self.allText = allText
        self.clearText = clearText
        self.onSelectAll = onSelectAll
        self.onClear = onClear
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text("\(selectedCount)/\(totalCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Button(allText, action: onSelectAll)
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button(clearText, action: onClear)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            content()
        }
    }
}

struct SettingsFilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                Text(title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Color.accentColor.opacity(0.16) : Color.gray.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Color.accentColor.opacity(0.34) : Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
