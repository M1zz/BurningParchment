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

    // 테마는 화면 전체에 걸리는 설정이라 최상위에서 읽어 Scene 에 그대로 건다.
    @AppStorage(AppTheme.storageKey) private var appThemeRaw = AppTheme.system.rawValue
    private var appTheme: AppTheme { AppTheme(rawValue: appThemeRaw) ?? .system }
    // 양피지·불꽃 테마도 여기서 프로 여부를 반영해 한 번만 정하고 아래로 흘려보낸다.
    @AppStorage(ParchmentStyle.storageKey) private var parchmentStyleRaw = ParchmentStyle.classic.rawValue

    init() {
        // 계약(BurningParchmentSpec)에 선언한 것을 전부 켠다 —
        // 사용량 기록·분석 싱크·MetricKit 크래시 진단·사용현황 스냅샷, DEBUG 에선 프리플라이트 감사까지.
        LeeoKit.bootstrap(BurningParchmentSpec.self)
        #if DEBUG
        DebugLaunch.applyOverrides()
        #endif
    }

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
                .environment(\.parchmentStyle,
                             ParchmentStyle.effective(raw: parchmentStyleRaw, isPro: storeManager.isPro))
                .preferredColorScheme(appTheme.colorScheme)
                .leeoSatisfactionCheck(BurningParchmentSpec.self)
        }
    }
}
