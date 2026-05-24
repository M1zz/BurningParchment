// DeadlineManager.swift

import Foundation
import SwiftUI
import WidgetKit

class DeadlineManager: ObservableObject {
    @Published var deadlines: [Deadline] = []

    private let key = "deadlines_v1"
    private let sharedDefaults = UserDefaults(suiteName: "group.com.burningparchment.app")

    init() { load() }

    func add(_ deadline: Deadline) {
        deadlines.append(deadline)
        deadlines.sort { $0.targetDate < $1.targetDate }
        save()
    }

    func delete(id: UUID) {
        deadlines.removeAll { $0.id == id }
        save()
    }

    func update(_ deadline: Deadline) {
        guard let idx = deadlines.firstIndex(where: { $0.id == deadline.id }) else { return }
        deadlines[idx] = deadline
        deadlines.sort { $0.targetDate < $1.targetDate }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(deadlines) else { return }
        sharedDefaults?.set(data, forKey: "shared_deadlines")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func load() {
        // App Group 우선 읽기.
        // BedtimeManager.runMigrations()가 먼저 실행되면 App Group에 데이터가 있음.
        // 초기화 순서에 따라 마이그레이션 전에 호출될 수 있으므로 standard 폴백 유지.
        // REMOVE standard fallback AFTER: 앱 v2.0.0 (v2 마이그레이션 완료 시점)
        let data = sharedDefaults?.data(forKey: "shared_deadlines")
            ?? UserDefaults.standard.data(forKey: key)
        guard let data,
              let decoded = try? JSONDecoder().decode([Deadline].self, from: data)
        else { return }
        deadlines = decoded
    }
}
