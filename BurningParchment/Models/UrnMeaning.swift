// UrnMeaning.swift
// 항아리에 부여한 의미.
//
// 재는 저절로 쌓인다.  하지만 쌓인 재가 무슨 뜻인지는 앱이 정해주지 않는다 —
// 사용자가 직접 적기 전까지 항아리 안의 것들은 그냥 재다.
// 의미가 적히는 순간 항아리에 이름이 새겨지고, 잿빛이던 재에 색이 돌아온다.

import Foundation

struct UrnMeaning: Codable, Hashable, Identifiable {
    /// UrnPeriod.id — 이 의미가 붙는 항아리.
    let periodId: String
    /// 항아리에 새겨질 짧은 이름.  비워둘 수 있다.
    var name: String
    /// 이 기간이 나에게 어떤 의미였는지.
    var text: String
    var createdAt: Date
    var updatedAt: Date

    var id: String { periodId }

    init(periodId: String,
         name: String = "",
         text: String = "",
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.periodId = periodId
        self.name = name
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// 이름도 본문도 없으면 의미가 부여되지 않은 것으로 본다.
    var isBlank: Bool { trimmedName.isEmpty && trimmedText.isEmpty }

    /// 항아리에 표시할 이름.  이름을 안 적었으면 본문 첫 줄을 줄여서 쓴다.
    var displayName: String {
        if !trimmedName.isEmpty { return trimmedName }
        let firstLine = trimmedText.split(separator: "\n").first.map(String.init) ?? ""
        return firstLine.count > 18 ? String(firstLine.prefix(18)) + "…" : firstLine
    }
}
