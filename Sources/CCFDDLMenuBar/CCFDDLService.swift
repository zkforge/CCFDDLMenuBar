import Foundation
import JavaScriptCore

enum CCFDDLServiceError: Error {
    case badResponse
    case htmlDecodeFailed
    case noRowsFound
    case javascriptParseFailed
    case jsonDecodeFailed

    func message(language: AppLanguage) -> String {
        switch self {
        case .badResponse:
            return AppLocalized.text(language: language, zh: "网络请求失败，请检查连接。", en: "Network request failed. Check your connection.")
        case .htmlDecodeFailed:
            return AppLocalized.text(language: language, zh: "页面解析失败（编码异常）。", en: "Failed to parse page content (encoding issue).")
        case .noRowsFound:
            return AppLocalized.text(language: language, zh: "页面中没有找到会议数据。", en: "No conference rows were found on the source page.")
        case .javascriptParseFailed:
            return AppLocalized.text(language: language, zh: "JavaScript 解析会议数据失败。", en: "Failed to parse conference data from JavaScript.")
        case .jsonDecodeFailed:
            return AppLocalized.text(language: language, zh: "会议数据解码失败。", en: "Failed to decode conference data.")
        }
    }
}

struct CCFDDLService {
    private let sourceURL = URL(string: "https://ccfddl.cn/")!

    func fetchConferences() async throws -> [Conference] {
        let (data, response) = try await URLSession.shared.data(from: sourceURL)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CCFDDLServiceError.badResponse
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw CCFDDLServiceError.htmlDecodeFailed
        }

        let rows = try parseRows(from: html)
        return rows.compactMap { raw in
            guard let deadlineDate = parseDeadline(raw.deadline, timezone: raw.timezone) else {
                return nil
            }

            let fallbackID = "\(raw.shortName)-\(raw.year ?? "unknown")-\(raw.deadline)"
            let stableID = raw.id.map { String($0) } ?? fallbackID

            return Conference(
                id: stableID,
                shortName: raw.shortName,
                type: raw.type,
                ccfRank: raw.ccfRank,
                deadlineDate: deadlineDate,
                sourceDeadlineText: raw.deadline,
                timezone: raw.timezone,
                conferenceDate: raw.date ?? "",
                place: raw.place ?? "",
                linkURL: URL(string: raw.link ?? "")
            )
        }
        .sorted { $0.deadlineDate < $1.deadlineDate }
    }

    private func parseRows(from html: String) throws -> [RawConference] {
        let pattern = #"rows\.push\(\{[\s\S]*?\}\)"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, range: range)
        guard !matches.isEmpty else {
            throw CCFDDLServiceError.noRowsFound
        }

        var script = "var rows = [];\n"
        for match in matches {
            guard let matchRange = Range(match.range, in: html) else {
                continue
            }
            script.append(contentsOf: html[matchRange])
            script.append(";\n")
        }
        script.append("JSON.stringify(rows);")

        let context = JSContext()
        guard let jsonString = context?.evaluateScript(script)?.toString() else {
            throw CCFDDLServiceError.javascriptParseFailed
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw CCFDDLServiceError.javascriptParseFailed
        }

        do {
            return try JSONDecoder().decode([RawConference].self, from: jsonData)
        } catch {
            throw CCFDDLServiceError.jsonDecodeFailed
        }
    }

    private func parseDeadline(_ deadline: String, timezone: String) -> Date? {
        let dateParts = deadline.split(separator: " ")
        guard dateParts.count == 2 else {
            return nil
        }

        let ymd = dateParts[0].split(separator: "-")
        let hms = dateParts[1].split(separator: ":")
        guard ymd.count == 3, hms.count == 3,
              let year = Int(ymd[0]),
              let month = Int(ymd[1]),
              let day = Int(ymd[2]),
              let hour = Int(hms[0]),
              let minute = Int(hms[1]),
              let second = Int(hms[2]),
              let timezoneOffsetSeconds = timezoneOffsetSeconds(from: timezone) else {
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = TimeZone(secondsFromGMT: timezoneOffsetSeconds)
        return Calendar(identifier: .gregorian).date(from: components)
    }

    private func timezoneOffsetSeconds(from timezone: String) -> Int? {
        if timezone == "AoE" {
            return -12 * 3600
        }
        if timezone == "UTC" {
            return 0
        }

        if timezone.hasPrefix("UTC+") {
            let numberText = String(timezone.dropFirst(4))
            guard let hourOffset = Int(numberText) else { return nil }
            return hourOffset * 3600
        }

        if timezone.hasPrefix("UTC-") {
            let numberText = String(timezone.dropFirst(4))
            guard let hourOffset = Int(numberText) else { return nil }
            return -hourOffset * 3600
        }

        return nil
    }
}

private struct RawConference: Decodable {
    let type: String
    let shortName: String
    let ccfRank: String
    let deadline: String
    let timezone: String
    let id: Int?
    let date: String?
    let link: String?
    let place: String?
    let year: String?
}
