// UrnPeriod.swift
// 기간 항아리 — 사용자가 만드는 게 아니라 날짜에서 파생된다.
// 회고를 적으면 그 날짜가 속한 주 항아리에 자동으로 담기고, 주 항아리는 달 항아리에 속한다.
//
// 주차는 달력 주(월~일)가 아니라 **날짜 기준**으로 끊는다 — 1~7일이 1주차, 8~14일이 2주차, …
// 한 주가 두 달에 걸치지 않으므로 모든 재는 정확히 하나의 주 항아리에만 담긴다.

import Foundation

enum UrnScope: String, Codable, Hashable {
    case month, week
}

struct UrnPeriod: Hashable, Identifiable, Codable {
    let scope: UrnScope
    let year: Int
    /// 1...12
    let month: Int
    /// scope == .week 일 때 1...5.  달 항아리는 0.
    let week: Int

    // MARK: - 생성

    static func month(of date: Date, calendar: Calendar = .current) -> UrnPeriod {
        let c = calendar.dateComponents([.year, .month], from: date)
        return UrnPeriod(scope: .month, year: c.year ?? 1, month: c.month ?? 1, week: 0)
    }

    static func week(of date: Date, calendar: Calendar = .current) -> UrnPeriod {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let day = c.day ?? 1
        return UrnPeriod(scope: .week,
                         year: c.year ?? 1,
                         month: c.month ?? 1,
                         week: Self.weekIndex(ofDay: day))
    }

    /// 1~7일 → 1, 8~14일 → 2, … 29~31일 → 5
    static func weekIndex(ofDay day: Int) -> Int {
        max(1, (day - 1) / 7 + 1)
    }

    var parentMonth: UrnPeriod {
        UrnPeriod(scope: .month, year: year, month: month, week: 0)
    }

    // MARK: - 식별

    var id: String {
        scope == .month
            ? String(format: "%04d-%02d", year, month)
            : String(format: "%04d-%02d-w%d", year, month, week)
    }

    // MARK: - 소속 판정
    // 날짜 연산이 아니라 달력 성분 비교로 판정한다 — 타임존·서머타임에 흔들리지 않는다.

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        guard c.year == year, c.month == month else { return false }
        guard scope == .week else { return true }
        return Self.weekIndex(ofDay: c.day ?? 1) == week
    }

    var isCurrent: Bool { contains(Date()) }

    /// 아직 재가 더 쌓일 수 있는 항아리인지 (= 지금이 이 기간 안이거나 미래).
    var isSealed: Bool {
        guard let start = startDate else { return true }
        return !isCurrent && start < Date()
    }

    // MARK: - 날짜 범위

    var startDate: Date? {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = scope == .month ? 1 : (week - 1) * 7 + 1
        return Calendar.current.date(from: c)
    }

    /// 이 기간의 마지막 날 (포함).  달의 끝을 넘지 않는다.
    var endDate: Date? {
        let cal = Calendar.current
        guard let start = startDate,
              let monthStart = parentMonth.startDate,
              let dayRange = cal.range(of: .day, in: .month, for: monthStart) else { return nil }
        let lastDayOfMonth = dayRange.count
        let lastDay = scope == .month ? lastDayOfMonth : min(week * 7, lastDayOfMonth)
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = lastDay
        return cal.date(from: c) ?? start
    }

    /// 이 기간이 실제로 존재하는지.  5주차는 달 길이에 따라 없을 수도 있다.
    var isValid: Bool {
        guard scope == .week else { return true }
        guard let monthStart = parentMonth.startDate,
              let dayRange = Calendar.current.range(of: .day, in: .month, for: monthStart) else { return false }
        return (week - 1) * 7 + 1 <= dayRange.count
    }

    // MARK: - 표시

    /// "3월" / "March"
    var monthName: String {
        guard let start = parentMonth.startDate else { return "\(month)" }
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("MMMM")
        return f.string(from: start)
    }

    /// 달: "2026년 3월"  /  주: "3월 2주차"
    var title: String {
        switch scope {
        case .month:
            guard let start = startDate else { return "\(year). \(month)" }
            let f = DateFormatter()
            f.locale = Locale.current
            f.setLocalizedDateFormatFromTemplate("yMMMM")
            return f.string(from: start)
        case .week:
            return String(localized: "\(monthName) \(week)주차")
        }
    }

    /// 달 안에서만 쓰는 짧은 이름 — "2주차"
    var shortTitle: String {
        scope == .month ? monthName : String(localized: "\(week)주차")
    }

    /// "3월 8일 – 14일" 처럼 이 항아리가 담는 날들의 범위.
    var rangeLabel: String {
        guard let start = startDate, let end = endDate else { return "" }
        let f = DateIntervalFormatter()
        f.locale = Locale.current
        f.dateTemplate = "MMMd"
        return f.string(from: start, to: end)
    }

    var accessibilityLabel: String {
        String(localized: "\(title) 항아리")
    }
}
