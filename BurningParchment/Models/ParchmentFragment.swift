// ParchmentFragment.swift
// 취침 30분 전에 불을 끄고 남긴 양피지 한 조각. 조각의 모양은 burnProgress·edgePhase 로 다시 그린다.

import Foundation

struct ParchmentFragment: Codable, Identifiable, Hashable {
    let id: UUID
    /// 이 조각이 속한 밤의 취침 시각. 하룻밤에 조각은 하나 — 이 값으로 "오늘 밤 이미 껐나"를 가린다.
    let bedtimeDate: Date
    let extinguishedAt: Date
    /// 불을 끈 순간까지 탄 비율 (0~1). 남은 조각 = 1 - burnProgress.
    let burnProgress: Double
    /// 불을 끈 순간 취침까지 남아 있던 시간
    let remainingSeconds: TimeInterval
    /// 타다 만 가장자리의 모양. 불꽃이 흔들리던 그 순간의 위상을 그대로 얼려 둔다.
    let edgePhase: Double
    var phrase: String
    let createdAt: Date

    init(id: UUID = UUID(),
         bedtimeDate: Date,
         extinguishedAt: Date = Date(),
         burnProgress: Double,
         remainingSeconds: TimeInterval,
         edgePhase: Double,
         phrase: String,
         createdAt: Date = Date()) {
        self.id = id
        self.bedtimeDate = bedtimeDate
        self.extinguishedAt = extinguishedAt
        self.burnProgress = burnProgress
        self.remainingSeconds = remainingSeconds
        self.edgePhase = edgePhase
        self.phrase = phrase
        self.createdAt = createdAt
    }

    /// 29분 30초를 남겼으면 "30분" — 사용자가 본 타이머 숫자와 맞춘다
    var remainingMinutes: Int { Self.minutes(from: remainingSeconds) }

    static func minutes(from seconds: TimeInterval) -> Int {
        max(1, Int((seconds / 60).rounded(.up)))
    }

    /// 새벽 1시 취침이면 달력으로는 다음 날이지만 "그날 밤"은 전날이다.
    /// 취침 시각에서 12시간을 빼면 어느 취침 설정이든 그날 밤의 날짜가 나온다.
    var nightDate: Date {
        Calendar.current.startOfDay(for: bedtimeDate.addingTimeInterval(-12 * 3600))
    }

    var dateString: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("yMdE")
        return f.string(from: nightDate)
    }
}

// MARK: - 글귀
// 조각에 직접 쓸 말이 떠오르지 않을 때 대신 적어 주는 한 줄.

enum FragmentPhrase {
    static var all: [String] {
        [
            String(localized: "다 타지 않은 하루도 온전한 하루였다"),
            String(localized: "남은 불씨는 내일의 나에게 맡긴다"),
            String(localized: "오늘은 여기까지, 충분히 탔다"),
            String(localized: "모든 걸 태우지 않아도 괜찮아"),
            String(localized: "오늘의 끝은 내가 정했다"),
            String(localized: "남겨둔 조각만큼 내일이 기다린다"),
            String(localized: "잘 타오른 하루, 이제 식힐 시간"),
            String(localized: "불을 끄는 것도 용기다"),
            String(localized: "조금 남긴 하루가 더 오래 남는다"),
            String(localized: "꺼진 불 곁에서 편히 쉬어도 된다"),
        ]
    }

    static func random(excluding current: String? = nil) -> String {
        let pool = all.filter { $0 != current }
        return pool.randomElement() ?? all[0]
    }
}
