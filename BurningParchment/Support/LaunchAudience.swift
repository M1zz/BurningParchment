// LaunchAudience.swift
// 앱을 연 사람이 **처음 온 사람**인지 **쓰던 사람**인지 한 곳에서 가른다.
//
// 처음 온 사람에게는 안내(BurningOnboardingView)를, 업데이트한 사람에게는 새 소식(WhatsNewView)을
// 한 번 보여 준다. 두 판단이 따로 놀면 양쪽을 다 받거나 다 못 받는 사람이 생긴다.
// 순수 함수라 시험(LaunchAudienceTests)이 같은 입력을 만들어 확인한다.

import Foundation

enum LaunchAudience: Equatable {
    /// 처음 받은 사람(또는 안내를 끝내지 못하고 다시 연 사람). 안내가 맞이한다.
    case newcomer
    /// 쓰던 사람인데 이번 새 소식을 아직 못 봤다.
    case returningNeedsWhatsNew
    /// 쓰던 사람이고 새 소식도 봤다.
    case returning

    static let onboardingKey = "hasCompletedOnboarding"
    static let whatsNewKey = "lastSeenWhatsNewVersion"

    /// - Parameters:
    ///   - launchCount: 이번 실행까지 센 실행 횟수 (LeeoEngagement). 1 이면 첫 실행.
    ///   - hasCompletedOnboarding: 안내를 끝까지 보거나 건너뛰었는가
    ///   - lastSeenWhatsNew: 마지막으로 본 새 소식의 버전 (없으면 빈 문자열)
    static func resolve(launchCount: Int,
                        hasCompletedOnboarding: Bool,
                        lastSeenWhatsNew: String,
                        current: String = WhatsNewContent.version) -> LaunchAudience {
        if launchCount <= 1 { return .newcomer }
        // 첫 실행에 새 소식은 "본 것"으로만 적어 둔다. 그 상태로 안내를 못 끝냈으면 아직 처음 온 사람이다.
        if !hasCompletedOnboarding && lastSeenWhatsNew == current { return .newcomer }
        return lastSeenWhatsNew == current ? .returning : .returningNeedsWhatsNew
    }

    var showsOnboarding: Bool { self == .newcomer }
    var showsWhatsNew: Bool { self == .returningNeedsWhatsNew }
}
