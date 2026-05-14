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
        UserDefaults.standard.set(data, forKey: key)
        sharedDefaults?.set(data, forKey: "shared_deadlines")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Deadline].self, from: data)
        else { return }
        deadlines = decoded
    }
}
