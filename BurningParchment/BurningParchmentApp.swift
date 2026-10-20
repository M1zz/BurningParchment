// BurningParchmentApp.swift
// 취침시간 카운트다운 앱 - 불타는 양피지
// 밤 9시 이후 취침시간까지 남은 시간을 양피지가 타들어가는 효과로 보여줍니다.

import SwiftUI
import LeeoKit

@main
struct BurningParchmentApp: App {
    @StateObject private var bedtimeManager    = BedtimeManager()
    @StateObject private var deadlineManager   = DeadlineManager()
    @StateObject private var reflectionManager = ReflectionManager()
    @StateObject private var excuseManager     = BedtimeExcuseManager()
    @StateObject private var storeManager      = StoreManager()
    @StateObject private var fragmentManager   = FragmentManager()
    @StateObject private var nightManager      = NightManager()
    @StateObject private var freeTimeManager   = FreeTimeManager()

    // 테마는 화면 전체에 걸리는 설정이라 최상위에서 읽어 Scene 에 그대로 건다.
    @AppStorage(AppTheme.storageKey) private var appThemeRaw = AppTheme.system.rawValue
    private var appTheme: AppTheme { AppTheme(rawValue: appThemeRaw) ?? .system }
    // 양피지·불꽃 테마도 여기서 프로 여부를 반영해 한 번만 정하고 아래로 흘려보낸다.
    @AppStorage(ParchmentStyle.storageKey) private var parchmentStyleRaw = ParchmentStyle.classic.rawValue
    @AppStorage(FlameKind.storageKey) private var flameKindRaw = FlameKind.classic.rawValue

    init() {
        // 계약(BurningParchmentSpec)에 선언한 것을 전부 켠다 —
        // 사용량 기록·분석 싱크·MetricKit 크래시 진단·사용현황 스냅샷, DEBUG 에선 프리플라이트 감사까지.
        LeeoKit.bootstrap(BurningParchmentSpec.self)
        // 크래시 루프 가드와 원격 스위치. 매니저들(@StateObject)은 body 가 처음 그려질 때 만들어지므로
        // 여기서 정한 세이프 모드가 그 시작 작업에 닿는다.
        AppLaunch.begin()
        BurningFunnel.installed.reach()
        BurningTips.configure()
        #if DEBUG
        Self.assertSpecIsReleasable()
        DebugLaunch.applyOverrides()
        #endif
    }

    #if DEBUG
    /// 부트스트랩의 감사는 콘솔에 찍기만 해서 지나치기 쉽다. 출시하면 안 되는 문제(error)가 있으면
    /// 개발 중 실행을 바로 멈춰 세운다. (같은 검사를 BurningParchmentTests 도 지킨다)
    private static func assertSpecIsReleasable() {
        let issues = LeeoPreflight.audit(BurningParchmentSpec.self)
        for issue in issues.errors {
            AppLog.lifecycle.fault("프리플라이트 오류 [\(issue.code, privacy: .public)] \(issue.message, privacy: .public)")
        }
        assert(issues.isReleasable, "LeeoPreflight 오류가 있습니다 — 콘솔의 [LeeoPreflight] 를 보세요")
    }
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .debugLaunch()
                .environmentObject(bedtimeManager)
                .environmentObject(deadlineManager)
                .environmentObject(reflectionManager)
                .environmentObject(excuseManager)
                .environmentObject(storeManager)
                .environmentObject(fragmentManager)
                .environmentObject(nightManager)
                .environmentObject(freeTimeManager)
                .environment(\.parchmentStyle,
                             ParchmentStyle.effective(raw: parchmentStyleRaw, isPro: storeManager.isPro))
                .environment(\.flameKind,
                             FlameKind.effective(raw: flameKindRaw, isPro: storeManager.isPro))
                .preferredColorScheme(appTheme.colorScheme)
                // 만족도 질문은 앱을 켤 때가 아니라 해낸 직후에 묻는다 (ContentView)
        }
    }
}
