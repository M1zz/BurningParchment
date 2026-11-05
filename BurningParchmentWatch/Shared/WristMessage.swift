// WristMessage.swift
// 아이폰 ↔ 워치가 주고받는 것. 아이폰 앱(WatchBridge)과 워치 앱(WatchLink)이 같은 파일을 쓴다.
//
// 아이폰 → 워치 (applicationContext, 마지막 것만 남는다): 기상 · 취침 시각과 이미 불을 끈 밤들.
// 워치 → 아이폰 (transferUserInfo, 폰이 멀리 있어도 줄을 서서 간다): 손목에서 불을 끈 밤.
// 워치는 받은 값을 자기 App Group 에 두고 폰 없이 계산한다.

import Foundation

enum WristMessage {
    /// 하루의 틀 — 이것만 있으면 워치 혼자 오늘 남은 시간을 셀 수 있다.
    struct Day: Codable, Equatable {
        var wakeHour = 7
        var wakeMinute = 0
        var bedHour = 23
        var bedMinute = 0
        /// 이미 불을 끈 밤들(최근 몇 개). 폰에서 껐든 손목에서 껐든.
        var blownOut: [BlownOut] = []
    }

    /// 불을 끈 밤 하나. 그 밤의 취침 시각이 키다(폰의 ParchmentFragment.bedtimeDate 와 같은 값).
    struct BlownOut: Codable, Equatable {
        let bedtime: Date
        let at: Date
        /// 불을 끈 순간까지 탄 비율 (0~1)
        let burnProgress: Double
        /// 불을 끈 순간 취침까지 남아 있던 시간
        let remainingSeconds: TimeInterval
    }

    static let dayKey = "day"
    static let blownOutKey = "blownOut"
    /// 들고 다닐 밤의 수 — 오늘 밤 하나면 되지만 시계가 어긋난 날을 위해 조금 더.
    static let keep = 7

    static func encode<T: Encodable>(_ value: T) -> Data? { try? JSONEncoder().encode(value) }
    static func decode<T: Decodable>(_ type: T.Type, _ data: Any?) -> T? {
        guard let data = data as? Data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
