// FragmentManager.swift
// 불을 끄고 모아둔 양피지 조각들

import Foundation
import SwiftUI

class FragmentManager: ObservableObject {
    @Published private(set) var fragments: [ParchmentFragment] = []

    private let key = "parchment_fragments"
    private let sd  = UserDefaults(suiteName: "group.com.burningparchment.app")

    init() { load() }

    // MARK: - Queries

    /// 그 밤에 이미 불을 껐다면 그때 남긴 조각
    func fragment(forBedtime bedDate: Date) -> ParchmentFragment? {
        fragments.first { abs($0.bedtimeDate.timeIntervalSince(bedDate)) < 1 }
    }

    // MARK: - Mutations

    func add(_ fragment: ParchmentFragment) {
        // 하룻밤에 조각은 하나 — 같은 밤을 다시 끄면 새 조각으로 바꾼다
        fragments.removeAll { abs($0.bedtimeDate.timeIntervalSince(fragment.bedtimeDate)) < 1 }
        fragments.insert(fragment, at: 0)
        save()
    }

    func delete(_ fragment: ParchmentFragment) {
        fragments.removeAll { $0.id == fragment.id }
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(fragments) else { return }
        sd?.set(data, forKey: key)
    }

    private func load() {
        guard let data = sd?.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ParchmentFragment].self, from: data)
        else { return }
        fragments = decoded.sorted { $0.bedtimeDate > $1.bedtimeDate }
    }
}
