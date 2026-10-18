// BurningFunnel.swift
// 설치한 사람이 앱의 핵심에 닿기까지 어디서 멈추는지 본다.
//
//   설치(첫 실행) → 첫 회고 → 첫 불 끄기 → 페이월을 봄 → 프로 구매
//
// 단계마다 이벤트는 **설치당 한 번만**(처음 닿았을 때) 나간다. 그래서 허브에서 이벤트 수가
// 곧 그 단계에 닿은 설치 수다. 보내는 것은 이벤트 이름뿐 — 회고 본문 같은 내용은 싣지 않는다.
// 이벤트는 Spec.analytics(LeeoUsageAnalytics) 로 나가며 개인정보 처리방침의 "이벤트 이름" 항목에 해당한다.

import Foundation
import LeeoKit

enum BurningFunnel: String, CaseIterable {
    case installed      = "funnel_installed"
    case firstReflection = "funnel_first_reflection"
    case firstBlowOut   = "funnel_first_blowout"
    case paywallSeen    = "funnel_paywall_seen"
    case purchased      = "funnel_purchased"

    private static let defaults = UserDefaults.standard
    private var storageKey: String { "funnel.reached.\(rawValue)" }

    /// 이미 닿은 단계인가
    var isReached: Bool { Self.defaults.bool(forKey: storageKey) }

    /// 이 단계에 닿았다. 처음일 때만 이벤트를 보내고 true 를 돌려준다.
    @discardableResult
    func reach(analytics: any LeeoAnalytics = BurningParchmentSpec.analytics) -> Bool {
        guard !isReached else { return false }
        Self.defaults.set(true, forKey: storageKey)
        analytics.track(rawValue)
        AppLog.lifecycle.info("퍼널 단계 도달: \(rawValue, privacy: .public)")
        return true
    }

    /// 테스트용 — 기록을 지운다.
    static func resetForTesting() {
        for stage in allCases { defaults.removeObject(forKey: stage.storageKey) }
    }
}
