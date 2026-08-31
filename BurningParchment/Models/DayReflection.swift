// DayReflection.swift
// 항아리에 담기는 한 줌의 재. 어느 항아리에 담기는지는 date 가 정한다 (UrnPeriod 참고).

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
        case .forged:        return String(localized: "마음먹은 대로 한 일")
        case .missed:        return String(localized: "하려 했지만 못 한 일")
        case .stop:          return String(localized: "그만둘 것")
        case .accept:        return String(localized: "어쩌다 하게 된 일")
        case .scattered:     return String(localized: "그냥 흘러간 시간")
        case .uncategorized: return String(localized: "분류 안 됨")
        }
    }

    var shortLabel: String {
        switch self {
        case .forged:    return String(localized: "해냄")
        case .missed:    return String(localized: "못함")
        case .stop:      return String(localized: "멈춰")
        case .accept:    return String(localized: "어쩌다")
        case .scattered: return String(localized: "흘러감")
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

// MARK: - Legacy Urn
// v1 의 사용자 생성 항아리.  지금은 항아리가 날짜에서 파생되므로(UrnPeriod) 더 만들지 않는다.
// 이 타입은 예전에 저장된 항아리 이름을 읽어 회고 키워드로 옮기기 위해서만 남아 있다.
// REMOVE AFTER: 기간 항아리 마이그레이션이 충분히 퍼진 시점.

struct LegacyUrn: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var emoji: String
    let createdAt: Date
}

// MARK: - Reflection

struct DayReflection: Codable, Identifiable, Hashable {
    let id: UUID
    /// v1 의 사용자 생성 항아리 id.  기간 항아리로 넘어오면서 더 이상 쓰지 않는다 —
    /// 예전 데이터를 한 번 읽어 키워드로 옮기기 위해서만 남겨둔다.
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

    /// 이 재가 담기는 주 항아리.  날짜에서 바로 나온다.
    var weekPeriod: UrnPeriod { UrnPeriod.week(of: date) }

    /// 이 재가 담기는 달 항아리.
    var monthPeriod: UrnPeriod { UrnPeriod.month(of: date) }

    var dateString: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("yMdE")
        return f.string(from: date)
    }
}
