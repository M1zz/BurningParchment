// BedtimeExcuseManager.swift

import Foundation
import SwiftUI

class BedtimeExcuseManager: ObservableObject {
    @Published var excuses: [BedtimeExcuse] = []

    private let key = "bedtime_excuses"
    private let sd  = UserDefaults(suiteName: "group.com.burningparchment.app")

    init() { load() }

    // MARK: - Queries

    var hasExcuseToday: Bool {
        excuses.contains { Calendar.current.isDateInToday($0.date) }
    }

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

    func add(reason: String, nextAction: String) {
        let r = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !r.isEmpty else { return }
        excuses.insert(BedtimeExcuse(reason: r, nextAction: n), at: 0)
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(excuses) else { return }
        sd?.set(data, forKey: key)
    }

    private func load() {
        guard let data = sd?.data(forKey: key),
              let decoded = try? JSONDecoder().decode([BedtimeExcuse].self, from: data)
        else { return }
        excuses = decoded.sorted { $0.createdAt > $1.createdAt }
    }
}
