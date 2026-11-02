// BedtimeExcuseManager.swift

import Foundation
import SwiftUI

class BedtimeExcuseManager: ObservableObject {
    @Published var excuses: [BedtimeExcuse] = []

    private let key = "bedtime_excuses"
    private let sd  = UserDefaults(suiteName: "group.com.burningparchment.app")

    init() { load() }

    // MARK: - Queries

    /// 이번 주(오늘 제외)에 기록된 변명 — 최신순
    var thisWeekPastExcuses: [BedtimeExcuse] {
        let cal = Calendar.current
        let now = Date()
        return excuses
            .filter {
                cal.isDate($0.date, equalTo: now, toGranularity: .weekOfYear)
                && !cal.isDateInToday($0.date)
            }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Mutations

    /// date 는 그 밤의 날짜 — 아침에 어젯밤 일을 적어도 어젯밤으로 남는다
    func add(reason: String, nextAction: String, date: Date = Date()) {
        let r = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !r.isEmpty else { return }
        excuses.insert(BedtimeExcuse(date: date, reason: r, nextAction: n), at: 0)
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(excuses) else { return }
        sd?.set(data, forKey: key)
    }

    private func load() {
        guard let data = sd?.data(forKey: key) else { return }
        guard let decoded = try? JSONDecoder().decode([BedtimeExcuse].self, from: data) else {
            // 못 읽은 원본을 옆에 남긴다 — 빈 목록으로 시작해 다음 저장이 덮어써도 되찾을 수 있게
            sd?.set(data, forKey: key + ".unreadable")
            return
        }
        excuses = decoded.sorted { $0.createdAt > $1.createdAt }
    }
}
