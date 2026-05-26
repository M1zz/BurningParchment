// DayReflection.swift
// 항아리(Urn)에 담기는 한 줌의 재. 각 회고는 어느 항아리에 속하는지 + 어떤 색의 재인지를 가짐.

import Foundation

/// 재의 색을 결정하는 분류.  의지 × 시간 2축에서 파생.
/// 의지 ❌ + 시간 ⭕️ 분면은 사용자 판단으로 stop / accept로 갈라짐.
/// 의지 ❌ + 시간 ❌ 분면은 항아리에 담기지 않음 (그냥 흘러간 시간).
enum ReflectionCategory: String, Codable, CaseIterable, Identifiable {
    case forged  // 의지 ⭕️ + 시간 ⭕️ — 잘 하고 있는 것
    case missed  // 의지 ⭕️ + 시간 ❌ — 못 하고 있는 것
    case stop    // 의지 ❌ + 시간 ⭕️ — 그만둘 것
    case accept  // 의지 ❌ + 시간 ⭕️ — 받아들일 것
    case uncategorized  // 구버전 마이그레이션 잔여물

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forged:        return "잘 하고 있는 것"
        case .missed:        return "못 하고 있는 것"
        case .stop:          return "그만둘 것"
        case .accept:        return "받아들일 것"
        case .uncategorized: return "분류 안 됨"
        }
    }

    var shortLabel: String {
        switch self {
        case .forged: return "잘함"
        case .missed: return "부족"
        case .stop:   return "멈춰"
        case .accept: return "받아"
        case .uncategorized: return "?"
        }
    }

    /// 재 입자의 색.
    var particleColor: (Double, Double, Double) {
        switch self {
        case .forged: return (0.92, 0.55, 0.25)   // 따뜻한 주황 — 단단한 잔열
        case .missed: return (0.72, 0.62, 0.42)   // 옅은 갈색 — 미련
        case .stop:   return (0.55, 0.60, 0.66)   // 식은 회청색 — 낭비
        case .accept: return (0.95, 0.78, 0.42)   // 황금빛 — 우연한 몰입
        case .uncategorized: return (0.55, 0.50, 0.45)
        }
    }

    static func from(intent: Bool, spentTime: Bool, drift: DriftFeeling?) -> ReflectionCategory? {
        switch (intent, spentTime) {
        case (true, true):   return .forged
        case (true, false):  return .missed
        case (false, true):
            guard let drift else { return nil }
            return drift == .stop ? .stop : .accept
        case (false, false): return nil
        }
    }
}

enum DriftFeeling: String, Codable {
    case stop, accept
}

// MARK: - Urn

/// 사용자가 직접 이름 짓는 컨테이너.  여러 항아리를 만들 수 있고, 각 항아리에 4색 재가 섞여 쌓임.
struct Urn: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var emoji: String
    let createdAt: Date

    init(id: UUID = UUID(),
         name: String,
         emoji: String = "🏺",
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.createdAt = createdAt
    }
}

// MARK: - Reflection

struct DayReflection: Codable, Identifiable, Hashable {
    let id: UUID
    /// 속한 항아리.  마이그레이션 호환을 위해 옵셔널 — 비어있으면 기본 항아리로 자동 배정.
    var urnId: UUID?
    var date: Date
    var text: String
    var category: ReflectionCategory
    var keyword: String?
    let createdAt: Date

    init(id: UUID = UUID(),
         urnId: UUID? = nil,
         date: Date,
         text: String,
         category: ReflectionCategory = .uncategorized,
         keyword: String? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.urnId = urnId
        self.date = date
        self.text = text
        self.category = category
        self.keyword = keyword
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, urnId, date, text, category, keyword, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self,   forKey: .id)
        urnId     = try c.decodeIfPresent(UUID.self, forKey: .urnId)
        date      = try c.decode(Date.self,   forKey: .date)
        text      = try c.decode(String.self, forKey: .text)
        keyword   = try c.decodeIfPresent(String.self, forKey: .keyword)
        createdAt = try c.decode(Date.self,   forKey: .createdAt)
        let raw = try c.decodeIfPresent(String.self, forKey: .category)
            ?? ReflectionCategory.uncategorized.rawValue
        category = ReflectionCategory(rawValue: raw) ?? .uncategorized
    }

    static func normalize(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy.MM.dd (E)"
        return f.string(from: date)
    }
}
