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

    init() {
        // 계약(BurningParchmentSpec)에 선언한 것을 전부 켠다 —
        // 사용량 기록·분석 싱크·MetricKit 크래시 진단·사용현황 스냅샷, DEBUG 에선 프리플라이트 감사까지.
        LeeoKit.bootstrap(BurningParchmentSpec.self)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bedtimeManager)
                .environmentObject(deadlineManager)
                .environmentObject(reflectionManager)
                .environmentObject(excuseManager)
                .environmentObject(storeManager)
                .preferredColorScheme(.dark)
                .leeoSatisfactionCheck(BurningParchmentSpec.self)
        }
    }
}
