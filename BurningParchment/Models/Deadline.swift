// Deadline.swift

import Foundation

struct Deadline: Codable, Identifiable {
    let id: UUID
    var title: String
    var emoji: String
    var targetDate: Date
    var startDate: Date       // 진행률 기준 시작 시각 (기본: 생성 시각)
    let createdDate: Date

    enum CodingKeys: String, CodingKey {
        case id, title, emoji, targetDate, startDate, createdDate
    }

    init(id: UUID = UUID(), title: String, emoji: String = "🎯",
         targetDate: Date, startDate: Date = Date(), createdDate: Date = Date()) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.targetDate = targetDate
        self.startDate = startDate
        self.createdDate = createdDate
    }

    // 기존 저장 데이터에 startDate가 없으면 createdDate로 대체
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self,   forKey: .id)
        title       = try c.decode(String.self, forKey: .title)
        emoji       = try c.decode(String.self, forKey: .emoji)
        targetDate  = try c.decode(Date.self,   forKey: .targetDate)
        createdDate = try c.decode(Date.self,   forKey: .createdDate)
        startDate   = try c.decodeIfPresent(Date.self, forKey: .startDate) ?? createdDate
    }

    func progress(at date: Date = Date()) -> Double {
        let total = max(targetDate.timeIntervalSince(startDate), 1)
        return min(max(date.timeIntervalSince(startDate) / total, 0), 1)
    }

    func remaining(at date: Date = Date()) -> TimeInterval {
        max(targetDate.timeIntervalSince(date), 0)
    }

    func isExpired(at date: Date = Date()) -> Bool { targetDate <= date }

    func remainingString(at date: Date = Date()) -> String {
        let total = Int(remaining(at: date))
        let days  = total / 86400
        let hours = (total % 86400) / 3600
        let mins  = (total % 3600) / 60
        let secs  = total % 60
        if days > 0  { return "\(days)일 \(hours)시간" }
        if hours > 0 { return "\(hours)시간 \(mins)분" }
        if mins > 0  { return "\(mins)분 \(secs)초" }
        return "\(secs)초"
    }

    var targetDateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy.MM.dd (E) HH:mm"
        return f.string(from: targetDate)
    }

    var startDateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy.MM.dd (E) HH:mm"
        return f.string(from: startDate)
    }
}
