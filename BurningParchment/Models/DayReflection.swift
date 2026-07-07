// DayReflection.swift
// 항아리(Urn)에 담기는 한 줌의 재. 각 회고는 어느 항아리에 속하는지 + 어떤 색의 재인지를 가짐.

import Foundation
import CoreGraphics

/// 재의 색을 결정하는 분류.  의지 × 시간 2축에서 파생.
/// 의지 ❌ + 시간 ⭕️ 분면은 사용자 판단으로 stop / accept로 갈라짐.
/// 의지 ❌ + 시간 ❌ 분면은 항아리에 담기지 않음 (그냥 흘러간 시간).
enum ReflectionCategory: String, Codable, CaseIterable, Identifiable {
    case forged     // 의지 ⭕️ + 시간 ⭕️ — 마음먹은 대로 한 일
    case missed     // 의지 ⭕️ + 시간 ❌ — 하려 했지만 못 한 일
    case stop       // 의지 ❌ + 시간 ⭕️ — 그만둘 것
    case accept     // 의지 ❌ + 시간 ⭕️ — 어쩌다 하게 된 일
    case scattered  // 의지 ❌ + 시간 ❌ — 그냥 흘러간 시간 (가벼운 먼지)
    case uncategorized  // 구버전 마이그레이션 잔여물

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forged:        return "마음먹은 대로 한 일"
        case .missed:        return "하려 했지만 못 한 일"
        case .stop:          return "그만둘 것"
        case .accept:        return "어쩌다 하게 된 일"
        case .scattered:     return "그냥 흘러간 시간"
        case .uncategorized: return "분류 안 됨"
        }
    }

    var shortLabel: String {
        switch self {
        case .forged:    return "해냄"
        case .missed:    return "못함"
        case .stop:      return "멈춰"
        case .accept:    return "어쩌다"
        case .scattered: return "흘러감"
        case .uncategorized: return "?"
        }
    }

    /// 재 입자의 색.
    var particleColor: (Double, Double, Double) {
        switch self {
        case .forged:    return (0.92, 0.55, 0.25)   // 따뜻한 주황 — 단단한 잔열
        case .missed:    return (0.72, 0.62, 0.42)   // 옅은 갈색 — 미련
        case .stop:      return (0.55, 0.60, 0.66)   // 식은 회청색 — 낭비
        case .accept:    return (0.95, 0.78, 0.42)   // 황금빛 — 우연한 몰입
        case .scattered: return (0.68, 0.66, 0.62)   // 옅은 회색 — 가벼운 먼지
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
        case (false, false): return .scattered
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
    /// "내일 어떻게?" 한 줄.  다음날 양피지 상단 띠에 노출.
    var tomorrowIntent: String?
    /// 2D 분류 그래프에서 사용자가 찍은 정확한 좌표 (0~1 정규화).  사분면만이 아니라 강도까지 기억.
    var classificationPoint: CGPoint?
    let createdAt: Date

    init(id: UUID = UUID(),
         urnId: UUID? = nil,
         date: Date,
         text: String,
         category: ReflectionCategory = .uncategorized,
         keyword: String? = nil,
         tomorrowIntent: String? = nil,
         classificationPoint: CGPoint? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.urnId = urnId
        self.date = date
        self.text = text
        self.category = category
        self.keyword = keyword
        self.tomorrowIntent = tomorrowIntent
        self.classificationPoint = classificationPoint
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, urnId, date, text, category, keyword, tomorrowIntent, classificationPoint, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self,   forKey: .id)
        urnId     = try c.decodeIfPresent(UUID.self, forKey: .urnId)
        date      = try c.decode(Date.self,   forKey: .date)
        text      = try c.decode(String.self, forKey: .text)
        keyword   = try c.decodeIfPresent(String.self, forKey: .keyword)
        tomorrowIntent = try c.decodeIfPresent(String.self, forKey: .tomorrowIntent)
        classificationPoint = try c.decodeIfPresent(CGPoint.self, forKey: .classificationPoint)
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
