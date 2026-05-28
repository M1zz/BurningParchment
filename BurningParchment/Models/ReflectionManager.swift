// ReflectionManager.swift
// 항아리(Urn)와 회고(DayReflection)를 함께 관리.
// 한 항아리에 4종 카테고리의 재 입자가 섞여 쌓임.

import Foundation
import SwiftUI

class ReflectionManager: ObservableObject {
    @Published var urns: [Urn] = []
    @Published var reflections: [DayReflection] = []

    private let keyReflections = "shared_reflections"
    private let keyUrns        = "shared_urns"
    private let sharedDefaults = UserDefaults(suiteName: "group.com.burningparchment.app")

    init() {
        load()
        migrateLegacyReflectionsIfNeeded()
    }

    // MARK: - Urn CRUD

    @discardableResult
    func createUrn(name: String, emoji: String = "🏺") -> Urn {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "이름 없는 항아리" : trimmed
        let urn = Urn(name: finalName, emoji: emoji)
        urns.append(urn)
        urns.sort { $0.createdAt < $1.createdAt }
        saveUrns()
        return urn
    }

    func updateUrn(_ urn: Urn) {
        guard let idx = urns.firstIndex(where: { $0.id == urn.id }) else { return }
        urns[idx] = urn
        saveUrns()
    }

    func deleteUrn(id: UUID) {
        urns.removeAll { $0.id == id }
        // 해당 항아리의 회고도 함께 삭제
        reflections.removeAll { $0.urnId == id }
        saveUrns()
        saveReflections()
    }

    // MARK: - Reflection CRUD

    @discardableResult
    func add(text: String,
             urnId: UUID,
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
            urnId: urnId,
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

    // MARK: - Queries

    func reflections(in urn: Urn) -> [DayReflection] {
        reflections.filter { $0.urnId == urn.id }
    }

    func reflections(in urn: Urn, category: ReflectionCategory) -> [DayReflection] {
        reflections.filter { $0.urnId == urn.id && $0.category == category }
    }

    /// 한 항아리의 채움 비율 — 30개에서 가득 차는 느낌.
    /// scattered(흘려보낸 시간)는 가벼운 먼지로 취급해 일반 재의 0.3배 가중치만 부여.
    func fillLevel(for urn: Urn) -> Double {
        let inUrn = reflections(in: urn)
        let settled = inUrn.filter { $0.category != .scattered }.count
        let scattered = inUrn.filter { $0.category == .scattered }.count
        let weighted = Double(settled) + Double(scattered) * 0.3
        return min(weighted / 30.0, 1.0)
    }

    /// 한 항아리에서 각 카테고리의 개수.
    func categoryCounts(for urn: Urn) -> [ReflectionCategory: Int] {
        var result: [ReflectionCategory: Int] = [:]
        for r in reflections(in: urn) {
            result[r.category, default: 0] += 1
        }
        return result
    }

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

    // MARK: - Persistence

    private func saveReflections() {
        guard let data = try? JSONEncoder().encode(reflections) else { return }
        sharedDefaults?.set(data, forKey: keyReflections)
    }

    private func saveUrns() {
        guard let data = try? JSONEncoder().encode(urns) else { return }
        sharedDefaults?.set(data, forKey: keyUrns)
    }

    private func load() {
        if let data = sharedDefaults?.data(forKey: keyReflections),
           let decoded = try? JSONDecoder().decode([DayReflection].self, from: data) {
            reflections = decoded.sorted { $0.createdAt > $1.createdAt }
        }
        if let data = sharedDefaults?.data(forKey: keyUrns),
           let decoded = try? JSONDecoder().decode([Urn].self, from: data) {
            urns = decoded.sorted { $0.createdAt < $1.createdAt }
        }
    }

    // MARK: - Migration
    // 구버전 회고(urnId 없음)들이 있으면 "기본" 항아리를 자동 생성해 일괄 배정.
    // 이 단계는 v1 사용자가 다중 항아리 모델로 자연스럽게 전환되게 해줌.
    // REMOVE AFTER: 충분한 사용자가 새 모델로 넘어간 시점.

    private func migrateLegacyReflectionsIfNeeded() {
        let legacy = reflections.filter { $0.urnId == nil }
        guard !legacy.isEmpty else { return }

        let defaultUrn: Urn
        if let existing = urns.first(where: { $0.name == "기본" }) {
            defaultUrn = existing
        } else {
            defaultUrn = createUrn(name: "기본", emoji: "🏺")
        }

        for i in reflections.indices where reflections[i].urnId == nil {
            reflections[i].urnId = defaultUrn.id
        }
        saveReflections()
    }
}
