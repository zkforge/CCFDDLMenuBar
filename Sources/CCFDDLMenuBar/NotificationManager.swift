import Foundation
import UserNotifications

actor DeadlineNotificationManager {
    private let identifierPrefix = "ccfddl.deadline."
    private let leadTimes: [(suffix: String, seconds: TimeInterval)] = [
        ("24h", 24 * 3600),
        ("6h", 6 * 3600),
        ("1h", 1 * 3600)
    ]

    func schedule(conferences: [Conference], enabled: Bool, language: AppLanguage) async {
        guard let center = notificationCenterIfAvailable() else {
            return
        }

        if !enabled {
            await removeAllManagedRequests(center: center)
            return
        }

        guard await ensureAuthorization(center: center) else {
            return
        }

        await removeAllManagedRequests(center: center)

        let now = Date()
        let calendar = Calendar.current
        let maxConferenceCount = 20

        for conference in conferences.prefix(maxConferenceCount) {
            for lead in leadTimes {
                let triggerDate = conference.deadlineDate.addingTimeInterval(-lead.seconds)
                if triggerDate <= now {
                    continue
                }

                let content = UNMutableNotificationContent()
                let leadLabel = Self.leadLabel(suffix: lead.suffix, language: language)
                content.title = AppLocalized.text(
                    language: language,
                    zh: "\(conference.shortName) 即将截止",
                    en: "\(conference.shortName) deadline is approaching"
                )
                content.body = AppLocalized.text(
                    language: language,
                    zh: "距离截止还有\(leadLabel)（\(conference.timezone)）",
                    en: "\(leadLabel) left (\(conference.timezone))"
                )
                content.sound = .default

                let dateComponents = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: triggerDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                let identifier = "\(identifierPrefix)\(conference.id).\(lead.suffix)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                try? await add(request, center: center)
            }
        }
    }

    private func notificationCenterIfAvailable() -> UNUserNotificationCenter? {
        let isAppBundle = Bundle.main.bundleURL.pathExtension == "app"
        guard isAppBundle, Bundle.main.bundleIdentifier != nil else {
            return nil
        }
        return UNUserNotificationCenter.current()
    }

    private func ensureAuthorization(center: UNUserNotificationCenter) async -> Bool {
        let status = await authorizationStatus(center: center)
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        default:
            return false
        }
    }

    private func removeAllManagedRequests(center: UNUserNotificationCenter) async {
        let managedIDs = await pendingManagedIdentifiers(center: center)

        if !managedIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: managedIDs)
            center.removeDeliveredNotifications(withIdentifiers: managedIDs)
        }
    }

    private func authorizationStatus(center: UNUserNotificationCenter) async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private func pendingManagedIdentifiers(center: UNUserNotificationCenter) async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                let managedIDs = requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix(self.identifierPrefix) }
                continuation.resume(returning: managedIDs)
            }
        }
    }

    private func add(_ request: UNNotificationRequest, center: UNUserNotificationCenter) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private static func leadLabel(suffix: String, language: AppLanguage) -> String {
        switch suffix {
        case "24h":
            return AppLocalized.text(language: language, zh: "24小时", en: "24 hours")
        case "6h":
            return AppLocalized.text(language: language, zh: "6小时", en: "6 hours")
        case "1h":
            return AppLocalized.text(language: language, zh: "1小时", en: "1 hour")
        default:
            return suffix
        }
    }
}
