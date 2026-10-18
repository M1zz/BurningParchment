// AppLaunch.swift
// 앱이 켜질 때 한 번 정하는 것들 — 원격 스위치와 크래시 루프 가드.
//
// ⚠️ `LeeoKit.bootstrap(_:flags:)` 를 쓰지 않는다. 그 안에서 만든 `LeeoRemoteFlags` 는 바로 버려지는데,
//    `refreshInBackground` 가 약한 참조로 조회하므로 조회가 시작되기 전에 사라진다.
//    그래서 인스턴스를 여기 붙잡아 두고 직접 갱신한다.

import Foundation
import LeeoKit

/// 심사 없이 원격으로 끌 수 있는 기능. rawValue 가 CloudKit `RemoteFlags` 레코드의 필드명이다
/// (recordName `flags_com.burningparchment.app`, Int64 1=켬 0=끔, 필드가 없으면 켬).
enum BurningFlag: String, LeeoRemoteFlag, CaseIterable {
    /// 잠금화면·다이나믹 아일랜드의 실시간 현황
    case liveActivity
    /// 아침에 건강 앱 수면 기록으로 잠든 시각을 읽기 (끄면 아침에 직접 묻는다)
    case sleepHealth
    /// 취침 1시간 전 알림
    case bedtimeReminder

    var isEnabled: Bool { LeeoRemoteFlags.isEnabled(self) }
}

enum AppLaunch {
    static let appGroup = "group.com.burningparchment.app"

    /// 붙잡아 둔 원격 스위치. 버리면 조회가 끝나기 전에 사라진다.
    private static let remoteFlags = LeeoRemoteFlags(spec: BurningParchmentSpec.self,
                                                     appGroupSuiteName: appGroup)

    /// 연속으로 끝나지 못한 실행을 센다. App Group 에 두면 위젯과 같은 자리를 본다.
    static let crashGuard = LeeoCrashLoopGuard(name: "app", defaults: UserDefaults(suiteName: appGroup) ?? .standard)

    /// 이번 실행이 세이프 모드인가. 켜져 있으면 무거운 시작 작업(실시간 현황 다시 잇기·
    /// 건강 앱 조회·예시 데이터)을 건너뛴다. 이번 프로세스 동안은 바뀌지 않는다.
    private(set) static var isSafeMode = false

    /// App.init 에서 한 번. 매니저들이 만들어지기 **전에** 불러야 세이프 모드가 시작 작업에 닿는다.
    static func begin() {
        isSafeMode = crashGuard.beginLaunch()
        if isSafeMode {
            AppLog.lifecycle.error("연속으로 끝나지 못한 실행이 있어 세이프 모드로 엽니다")
        }
        remoteFlags.refreshInBackground(BurningFlag.self)
    }

    /// 첫 화면이 뜬 뒤. 몇 초 살아 있으면 이번 실행을 성공으로 기록한다.
    static func firstScreenAppeared() {
        crashGuard.markLaunchSucceededAfterSurvivalDelay()
        // 지난번에 끝나지 못한 실행이 있었다면 허브에 알린다 (launch_incomplete:app)
        Task.detached(priority: .utility) {
            let sent = await crashGuard.reportIncompleteLaunches(to: LeeoUsageReporter(spec: BurningParchmentSpec.self))
            if sent > 0 { AppLog.lifecycle.notice("끝나지 못한 실행 \(sent)건을 알렸습니다") }
        }
    }
}
