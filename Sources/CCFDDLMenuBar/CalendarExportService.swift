import AppKit
import Foundation

enum CalendarExportError: Error, Equatable {
    case noConferenceData
    case saveCanceled

    func message(language: AppLanguage) -> String {
        switch self {
        case .noConferenceData:
            return AppLocalized.text(language: language, zh: "没有可导出的会议数据。", en: "No conference data available for export.")
        case .saveCanceled:
            return AppLocalized.text(language: language, zh: "已取消导出。", en: "Export was canceled.")
        }
    }
}

@MainActor
final class CalendarExportService {
    func exportICS(conferences: [Conference], language: AppLanguage) async throws -> URL {
        guard !conferences.isEmpty else {
            throw CalendarExportError.noConferenceData
        }

        let savePanel = NSSavePanel()
        savePanel.title = AppLocalized.text(language: language, zh: "导出会议截止日历", en: "Export Conference Deadlines")
        savePanel.prompt = AppLocalized.text(language: language, zh: "导出", en: "Export")
        savePanel.nameFieldStringValue = "ccfddl-deadlines.ics"
        savePanel.allowedContentTypes = [.calendarEvent]
        savePanel.canCreateDirectories = true

        let response = await begin(savePanel)
        guard response == .OK, let targetURL = savePanel.url else {
            throw CalendarExportError.saveCanceled
        }

        let icsContent = buildICSContent(conferences: conferences, language: language)
        try icsContent.write(to: targetURL, atomically: true, encoding: .utf8)
        return targetURL
    }

    private func begin(_ panel: NSSavePanel) async -> NSApplication.ModalResponse {
        await withCheckedContinuation { continuation in
            panel.begin { response in
                continuation.resume(returning: response)
            }
        }
    }

    private func buildICSContent(conferences: [Conference], language: AppLanguage) -> String {
        var lines: [String] = []
        lines.append("BEGIN:VCALENDAR")
        lines.append("VERSION:2.0")
        lines.append("PRODID:-//CCFDDLMenuBar//EN")
        lines.append("CALSCALE:GREGORIAN")
        lines.append("METHOD:PUBLISH")

        let timestamp = utcDateText(for: Date())
        for conference in conferences {
            let startDate = conference.deadlineDate
            let endDate = conference.deadlineDate.addingTimeInterval(3600)
            lines.append("BEGIN:VEVENT")
            lines.append("UID:\(escapeICS("\(conference.id)-deadline@ccfddl.cn"))")
            lines.append("DTSTAMP:\(timestamp)")
            lines.append("DTSTART:\(utcDateText(for: startDate))")
            lines.append("DTEND:\(utcDateText(for: endDate))")
            lines.append("SUMMARY:\(escapeICS("\(conference.shortName) \(AppLocalized.text(language: language, zh: "截止", en: "Deadline"))"))")

            var descriptionSegments: [String] = []
            descriptionSegments.append("CCF \(conference.ccfRank) · \(ConferenceTypeFormatter.displayName(for: conference.type, language: language))")
            descriptionSegments.append(AppLocalized.text(language: language, zh: "截止时区：\(conference.timezone)", en: "Deadline timezone: \(conference.timezone)"))
            if !conference.conferenceDate.isEmpty {
                descriptionSegments.append(AppLocalized.text(language: language, zh: "会议日期：\(conference.conferenceDate)", en: "Conference date: \(conference.conferenceDate)"))
            }
            if !conference.place.isEmpty {
                descriptionSegments.append(AppLocalized.text(language: language, zh: "地点：\(conference.place)", en: "Location: \(conference.place)"))
            }
            lines.append("DESCRIPTION:\(escapeICS(descriptionSegments.joined(separator: "\\n")))")

            if let linkURL = conference.linkURL {
                lines.append("URL:\(escapeICS(linkURL.absoluteString))")
            }

            lines.append("END:VEVENT")
        }

        lines.append("END:VCALENDAR")
        return lines.joined(separator: "\r\n")
    }

    private func utcDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    private func escapeICS(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
