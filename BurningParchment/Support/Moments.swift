// Moments.swift
// 사용자가 이 앱에서 무언가를 "해낸" 순간을 한 곳에서 처리한다.
//
// 한 순간에 세 가지가 함께 일어난다.
//  1. 리뷰 요청의 근거 — LeeoEngagement 에 의미 있는 행동으로 센다 (`.leeoSatisfactionCheck` 가 읽는다)
//  2. 퍼널 — 그 단계에 처음 닿았으면 기록한다 (BurningFunnel)
//  3. VoiceOver 안내 — 화면 밖에서 일어난 변화(자동 저장 등)를 말로 알린다

import SwiftUI
import LeeoKit

@MainActor
enum Moments {
    /// 새 회고가 재 항아리에 담겼다 (자동 저장의 첫 저장)
    static func reflectionSaved() {
        LeeoEngagement.shared.registerSignificantEvent()
        BurningFunnel.firstReflection.reach()
        announce(String(localized: "회고를 재 항아리에 담았어요", comment: "VoiceOver announcement after a new reflection is auto-saved"))
    }

    /// 후 불어 오늘(또는 내일)의 불을 껐다
    /// - Parameter keptFragment: 오늘의 양피지를 꺼서 조각을 모았는가 (취침 이후 내일의 양피지는 조각을 남기지 않는다)
    static func fireBlownOut(keptFragment: Bool) {
        LeeoEngagement.shared.registerSignificantEvent()
        BurningFunnel.firstBlowOut.reach()
        announce(keptFragment
                 ? String(localized: "불을 껐어요. 남은 조각을 모아 두었어요", comment: "VoiceOver announcement after blowing out today's parchment")
                 : String(localized: "불을 껐어요. 좋은 꿈 꾸세요", comment: "VoiceOver announcement after blowing out tomorrow's parchment after bedtime"))
    }

    /// 새 데드라인을 더했다
    static func deadlineAdded(_ title: String) {
        LeeoEngagement.shared.registerSignificantEvent()
        announce(String(localized: "데드라인 \(title)을 더했어요", comment: "VoiceOver announcement after adding a deadline. Argument is the deadline title"))
    }

    /// 데드라인을 지웠다
    static func deadlineDeleted(_ title: String) {
        announce(String(localized: "데드라인 \(title)을 지웠어요", comment: "VoiceOver announcement after deleting a deadline. Argument is the deadline title"))
    }

    /// VoiceOver 가 켜져 있을 때만 들린다.
    static func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}

// MARK: - 팁을 부탁할 순간

/// 이 앱이 그 사람에게 도움이 됐다는 것이 숫자로 보이는 순간 — 재 항아리에 담은 회고 수.
/// 부탁 카드(`LeeoTipAskSlot`)는 재 항아리 화면에서 **이미 프로인 사람**에게만 선다. 묻는 횟수는 LeeoKit 이 정한다.
enum BurningParchmentTipMoments {
    /// 담은 회고 수. 큰 것부터.
    static let reflections = [100, 30, 10]

    /// 넘어선 순간, **인상적인 것부터**.
    static func reached(reflections count: Int) -> [LeeoTipMoment] {
        reflections.filter { count >= $0 }.map { threshold in
            LeeoTipMoment(id: "reflections.\(threshold)",
                          message: String(localized: "지금까지 회고 \(count)개를 재 항아리에 담았어요",
                                          comment: "Tip ask card: how many reflections the person has saved so far"))
        }
    }
}
