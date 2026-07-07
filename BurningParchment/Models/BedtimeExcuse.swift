// BedtimeExcuse.swift
// 취침 시간을 지키지 못했을 때 사용자가 기록하는 변명/이유

import Foundation

struct BedtimeExcuse: Codable, Identifiable {
    let id: UUID
    let date: Date        // startOfDay로 정규화
    var reason: String    // 오늘 마치지 못한 이유
    var nextAction: String // 다음엔 어떻게?
    let createdAt: Date

    init(id: UUID = UUID(),
         date: Date = Date(),
         reason: String,
         nextAction: String,
         createdAt: Date = Date()) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.reason = reason
        self.nextAction = nextAction
        self.createdAt = createdAt
    }

    var dateString: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("MdE")
        return f.string(from: date)
    }
}
