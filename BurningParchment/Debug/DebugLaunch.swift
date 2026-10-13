// DebugLaunch.swift
// DEBUG 빌드에서만 쓰는 실행 인자 — 시뮬레이터에서 프로 화면을 확인하고 스크린샷을 찍기 위한 것.
//
//   -forcePro YES|NO       프로 권한을 강제로 켜거나 끈다 (지정 안 하면 실제 구매를 따른다)
//   -seedDemo YES          기록이 하나도 없을 때만 지난 1년치 예시 회고와 조각을 채운다
//   -debugScreen <이름>     실행하자마자 그 화면을 띄운다
//                          paywall · settings · fragments · poster · card · book · bookExport · insights
//   -parchmentStyle <값>    classic · moonlit · celadon · dusk (@AppStorage 를 그대로 덮는다)
//   -skipNotifications YES  알림 예약을 건너뛴다 (새 시뮬레이터에서 알림 서비스가 답하지 않아 실행이 멈출 때)
//
// 예) xcrun simctl launch booted com.burningparchment.app -forcePro YES -seedDemo YES -debugScreen insights

import SwiftUI

#if DEBUG
enum DebugLaunch {
    static var forcePro: Bool? {
        UserDefaults.standard.object(forKey: "forcePro") == nil ? nil : UserDefaults.standard.bool(forKey: "forcePro")
    }
    static var seedDemo: Bool { UserDefaults.standard.bool(forKey: "seedDemo") }
    static var skipNotifications: Bool { UserDefaults.standard.bool(forKey: "skipNotifications") }
    static var screen: String? { UserDefaults.standard.string(forKey: "debugScreen") }

    @MainActor
    static func seedIfNeeded(reflections: ReflectionManager, fragments: FragmentManager) {
        guard seedDemo, reflections.reflections.isEmpty, fragments.fragments.isEmpty else { return }
        var rng = SeededRNG(seed: 20261013)
        let cal = Calendar.current
        let texts = ["아침에 30분 걸었다", "보고서 초안을 끝냈다", "유튜브를 두 시간 봤다", "책 한 장도 못 읽었다",
                     "친구와 오래 통화했다", "운동을 또 미뤘다", "저녁을 직접 해 먹었다", "괜히 쇼핑앱을 뒤적였다",
                     "일찍 퇴근해서 산책했다", "새 프로젝트 기획을 정리했다"]
        let cats: [ReflectionCategory] = [.forged, .forged, .forged, .missed, .missed, .accept, .stop, .scattered]
        for _ in 0..<160 {
            let daysAgo = Int.random(in: 0..<360, using: &rng)
            guard let date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) else { continue }
            reflections.add(text: texts.randomElement(using: &rng)!,
                            category: cats.randomElement(using: &rng)!,
                            date: date)
        }
        let phrases = ["오늘은 여기까지", "내일은 조금 더 일찍", "충분히 애썼다", "", "따뜻한 저녁이었다",
                       "", "다음엔 책을 펴자", "고요한 밤", "잘 버텼다"]
        for (i, phrase) in phrases.enumerated() {
            guard let bed = cal.date(byAdding: .day, value: -(i * 3 + 1), to: Date()) else { continue }
            fragments.add(ParchmentFragment(bedtimeDate: bed, extinguishedAt: bed.addingTimeInterval(-1200),
                                            burnProgress: Double.random(in: 0.955...0.98, using: &rng),
                                            remainingSeconds: Double.random(in: 300...1700, using: &rng),
                                            edgePhase: Double.random(in: 0...100, using: &rng),
                                            phrase: phrase))
        }
    }
}

/// 실행 인자에 따라 예시 데이터를 채우고 화면을 띄운다. 환경 객체 주입보다 **안쪽**에 걸어야 한다.
struct DebugLaunchModifier: ViewModifier {
    @EnvironmentObject var reflectionManager: ReflectionManager
    @EnvironmentObject var fragmentManager: FragmentManager
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var bedtimeManager: BedtimeManager
    @State private var screen: String?

    func body(content: Content) -> some View {
        content
            .onAppear {
                DebugLaunch.seedIfNeeded(reflections: reflectionManager, fragments: fragmentManager)
                screen = DebugLaunch.screen
            }
            .sheet(isPresented: Binding(get: { screen != nil }, set: { if !$0 { screen = nil } })) {
                destination
                    .environmentObject(reflectionManager)
                    .environmentObject(fragmentManager)
                    .environmentObject(storeManager)
                    .environmentObject(bedtimeManager)
            }
    }

    @ViewBuilder
    private var destination: some View {
        switch screen {
        case "paywall":    PaywallView()
        case "settings":   SettingsView()
        case "fragments":  FragmentCollectionView()
        case "poster":     FragmentShareSheet(content: .poster(fragmentManager.fragments))
        case "card":
            if let f = fragmentManager.fragments.first(where: \.isBackWritten) {
                FragmentShareSheet(content: .card(f))
            }
        case "book":       NavigationStack { ReflectionBookView() }
        case "bookExport": BookExportSheet()
        case "insights":   NavigationStack { AshInsightsView() }
        default:           EmptyView()
        }
    }
}
#endif

extension View {
    /// DEBUG 에서만 실행 인자를 읽는다. 릴리스에서는 아무것도 하지 않는다.
    @ViewBuilder
    func debugLaunch() -> some View {
        #if DEBUG
        modifier(DebugLaunchModifier())
        #else
        self
        #endif
    }
}
