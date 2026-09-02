// ReflectionManager.swift
// 회고(DayReflection)와 항아리에 부여된 의미(UrnMeaning)를 관리.
//
// 항아리는 저장하지 않는다.  회고의 날짜에서 파생될 뿐이다 (UrnPeriod).
// 저장되는 건 "언제 무슨 재가 쌓였나"(reflections)와 "그 기간이 나에게 무슨 의미였나"(meanings) 둘뿐.

import Foundation
import SwiftUI

class ReflectionManager: ObservableObject {
    @Published var reflections: [DayReflection] = []
    /// periodId → 의미
    @Published var meanings: [String: UrnMeaning] = [:]

    /// 기록 공백을 마지막으로 정리한 날 (그 날까지는 담았거나 날려버렸다).
    @Published private(set) var ashSweptUntil: Date? = nil

    private let keyReflections = "shared_reflections"
    private let keyMeanings    = "shared_urn_meanings"
    private let keySweptUntil  = "shared_ash_swept_until"
    private let keyLegacyUrns  = "shared_urns"
    private let sharedDefaults = UserDefaults(suiteName: "group.com.burningparchment.app")

    init() {
        load()
        migrateLegacyUrnsIfNeeded()
    }

    // MARK: - Reflection CRUD

    @discardableResult
    func add(text: String,
             category: ReflectionCategory,
             keyword: String? = nil,
             tomorrowIntent: String? = nil,
             classificationPoint: CGPoint? = nil,
             date: Date = Date()) -> DayReflection {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let kw = keyword?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalKeyword = (kw?.isEmpty ?? true) ? nil : kw
        let ti = tomorrowIntent?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalIntent = (ti?.isEmpty ?? true) ? nil : ti

        let new = DayReflection(
            date: DayReflection.normalize(date),
            text: trimmed,
            category: category,
            keyword: finalKeyword,
            tomorrowIntent: finalIntent,
            classificationPoint: classificationPoint
        )
        reflections.insert(new, at: 0)
        reflections.sort { $0.createdAt > $1.createdAt }
        saveReflections()
        return new
    }

    func update(_ reflection: DayReflection) {
        guard let idx = reflections.firstIndex(where: { $0.id == reflection.id }) else { return }
        reflections[idx] = reflection
        reflections.sort { $0.createdAt > $1.createdAt }
        saveReflections()
    }

    func delete(id: UUID) {
        reflections.removeAll { $0.id == id }
        saveReflections()
    }

    // MARK: - 항아리 열람 (기간에서 파생)

    /// 재가 한 톨이라도 담긴 달 항아리 — 최신 달이 먼저.
    var monthPeriods: [UrnPeriod] {
        let set = Set(reflections.map { UrnPeriod.month(of: $0.date) })
        return set.sorted { ($0.year, $0.month) > ($1.year, $1.month) }
    }

    /// 한 달 안의 주 항아리 — 1주차가 먼저.
    /// 재가 없는 주도 그 달이 이미 지나갔다면 빈 항아리로 함께 보여준다 (달의 모양이 유지되도록).
    func weekPeriods(in month: UrnPeriod) -> [UrnPeriod] {
        let all = (1...5)
            .map { UrnPeriod(scope: .week, year: month.year, month: month.month, week: $0) }
            .filter { $0.isValid }
        // 아직 오지 않은 미래의 주는 감춘다.
        return all.filter { period in
            guard let start = period.startDate else { return false }
            return start <= Date() || !reflections(in: period).isEmpty
        }
    }

    /// 지금 이 순간의 주 항아리 — 새 재가 담기는 곳.
    var currentWeekPeriod: UrnPeriod { UrnPeriod.week(of: Date()) }

    func reflections(in period: UrnPeriod) -> [DayReflection] {
        reflections
            .filter { period.contains($0.date) }
            .sorted { $0.date == $1.date ? $0.createdAt > $1.createdAt : $0.date > $1.date }
    }

    func reflectionCount(in period: UrnPeriod) -> Int {
        reflections.reduce(0) { $0 + (period.contains($1.date) ? 1 : 0) }
    }

    /// 항아리의 채움 비율.  주 항아리는 7톨, 달 항아리는 30톨에서 가득 찬 느낌.
    /// scattered(흘려보낸 시간)는 가벼운 먼지로 취급해 0.3배 가중치만 준다.
    func fillLevel(for period: UrnPeriod) -> Double {
        let inUrn = reflections(in: period)
        let settled = inUrn.filter { $0.category != .scattered }.count
        let scattered = inUrn.count - settled
        let weighted = Double(settled) + Double(scattered) * 0.3
        let capacity = period.scope == .week ? 7.0 : 30.0
        return min(weighted / capacity, 1.0)
    }

    func categoryCounts(for period: UrnPeriod) -> [ReflectionCategory: Int] {
        var result: [ReflectionCategory: Int] = [:]
        for r in reflections(in: period) {
            result[r.category, default: 0] += 1
        }
        return result
    }

    // MARK: - 의미

    func meaning(for period: UrnPeriod) -> UrnMeaning? {
        guard let m = meanings[period.id], !m.isBlank else { return nil }
        return m
    }

    /// 의미가 붙기 전까지 항아리 안의 것들은 그냥 재다.
    func hasMeaning(_ period: UrnPeriod) -> Bool {
        meaning(for: period) != nil
    }

    func setMeaning(name: String, text: String, for period: UrnPeriod) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !(trimmedName.isEmpty && trimmedText.isEmpty) else {
            removeMeaning(for: period)
            return
        }

        var m = meanings[period.id] ?? UrnMeaning(periodId: period.id)
        m.name = trimmedName
        m.text = trimmedText
        m.updatedAt = Date()
        meanings[period.id] = m
        saveMeanings()
    }

    func removeMeaning(for period: UrnPeriod) {
        guard meanings[period.id] != nil else { return }
        meanings.removeValue(forKey: period.id)
        saveMeanings()
    }

    /// 재는 쌓였는데 아직 의미가 없는 항아리들 — "무엇이었는지 적어달라"고 물을 대상.
    /// 아직 진행 중인 항아리는 재촉하지 않는다.
    var unnamedSealedWeeks: [UrnPeriod] {
        let weeks = Set(reflections.map { UrnPeriod.week(of: $0.date) })
        return weeks
            .filter { $0.isSealed && !hasMeaning($0) }
            .sorted { ($0.year, $0.month, $0.week) > ($1.year, $1.month, $1.week) }
    }

    // MARK: - Queries

    var totalReflectionCount: Int { reflections.count }

    var hasReflectionToday: Bool {
        let cal = Calendar.current
        return reflections.contains { cal.isDateInToday($0.date) }
    }

    /// 어제 적은 회고들 중 "내일 어떻게?" 의도가 적힌 항목들.
    /// 오늘 양피지 상단 띠에 노출하기 위한 쿼리.  카테고리와 무관하게 의도만 있으면 노출.
    var yesterdayPendingIntents: [(text: String, intent: String)] {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        guard let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart) else { return [] }
        return reflections.compactMap { r in
            guard let intent = r.tomorrowIntent, !intent.isEmpty,
                  r.date >= yesterdayStart, r.date < todayStart else { return nil }
            return (r.text, intent)
        }
    }

    // MARK: - 기록 공백 회수
    // 며칠 앱을 안 열면 그 사이의 시간은 어느 항아리에도 담기지 않고 흩어진다.
    // 돌아왔을 때 그 구간을 통째로 "날려버릴지 / 의미를 적어 담을지" 한 번 묻고 넘어간다.

    /// 이 일수 이상 비어 있어야 회수를 묻는다. 하루 이틀 건너뛴 것까지 붙잡지는 않는다.
    static let minimumGapDays = 3

    /// 지금 물어볼 만한 공백 구간. 없으면 nil.
    var unrecordedAshGap: (start: Date, end: Date, days: Int)? {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: -1, to: todayStart) else { return nil }

        // 기준점: 마지막으로 재가 담긴 날과 마지막으로 정리한 날 중 나중.
        var anchors: [Date] = []
        if let last = reflections.map({ cal.startOfDay(for: $0.date) }).max() { anchors.append(last) }
        if let swept = ashSweptUntil { anchors.append(cal.startOfDay(for: swept)) }
        // 아직 한 톨도 담지 않았다면 물을 것이 없다 — 빈 화면이 먼저 안내한다.
        guard let anchor = anchors.max() else { return nil }

        guard let start = cal.date(byAdding: .day, value: 1, to: anchor), start <= end else { return nil }
        let days = (cal.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        guard days >= Self.minimumGapDays else { return nil }
        return (start, end, days)
    }

    /// 공백을 정리했다고 표시. 담았든 날려버렸든 다시 묻지 않는다.
    func sweepAsh(through date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        // 되돌아가지 않게 — 항상 앞으로만 움직인다.
        if let current = ashSweptUntil, current >= day { return }
        ashSweptUntil = day
        sharedDefaults?.set(day.timeIntervalSince1970, forKey: keySweptUntil)
    }

    // MARK: - Persistence

    private func saveReflections() {
        guard let data = try? JSONEncoder().encode(reflections) else { return }
        sharedDefaults?.set(data, forKey: keyReflections)
    }

    private func saveMeanings() {
        guard let data = try? JSONEncoder().encode(meanings) else { return }
        sharedDefaults?.set(data, forKey: keyMeanings)
    }

    private func load() {
        if let data = sharedDefaults?.data(forKey: keyReflections),
           let decoded = try? JSONDecoder().decode([DayReflection].self, from: data) {
            reflections = decoded.sorted { $0.createdAt > $1.createdAt }
        }
        if let data = sharedDefaults?.data(forKey: keyMeanings),
           let decoded = try? JSONDecoder().decode([String: UrnMeaning].self, from: data) {
            meanings = decoded
        }
        if let ts = sharedDefaults?.object(forKey: keySweptUntil) as? Double {
            ashSweptUntil = Date(timeIntervalSince1970: ts)
        }
    }

    // MARK: - Migration
    // v1 은 사용자가 항아리를 직접 만들고 이름을 붙였다.  기간 항아리로 넘어오면서 그 이름들이
    // 갈 곳이 없어지므로, 회고의 키워드가 비어 있으면 항아리 이름을 키워드로 옮겨 보존한다.
    // 회고 자체(본문·분류·날짜)는 그대로 남고, 날짜에 따라 알아서 주/달 항아리에 담긴다.
    // REMOVE AFTER: 충분한 사용자가 기간 항아리로 넘어온 시점.

    private func migrateLegacyUrnsIfNeeded() {
        guard let data = sharedDefaults?.data(forKey: keyLegacyUrns),
              let legacyUrns = try? JSONDecoder().decode([LegacyUrn].self, from: data) else { return }

        let placeholderNames: Set<String> = ["기본", "이름 없는 항아리", "Default", "Untitled Urn"]
        let nameById = Dictionary(uniqueKeysWithValues: legacyUrns.map { ($0.id, $0.name) })

        var changed = false
        for i in reflections.indices {
            guard let urnId = reflections[i].urnId,
                  let name = nameById[urnId],
                  !placeholderNames.contains(name) else { continue }
            let existing = reflections[i].keyword?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard existing.isEmpty else { continue }
            reflections[i].keyword = name
            changed = true
        }
        if changed { saveReflections() }

        // 항아리 목록 자체는 더 이상 쓰지 않는다.
        sharedDefaults?.removeObject(forKey: keyLegacyUrns)
    }
}
