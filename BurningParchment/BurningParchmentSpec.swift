import Foundation
import LeeoKit

enum BurningParchmentSpec: LeeoAppSpec {
    static let appName = "불타는 내인생"
    static let developerEmail = "leeo@kakao.com"
    /// 위젯과 나눠 쓰는 기록 — 백업 금고가 함께 떠 둔다.
    static let appGroups = ["group.com.burningparchment.app"]
    static let feedback = LeeoFeedbackConfig(containerIdentifier: "iCloud.com.Ysoup.FeedbackHub", appIdentifier: "com.burningparchment.app")

    /// 무료 한도를 거는 기능 키. StoreManager 의 한도 판정과 아래 게이트 선언이 같은 값을 보게 한다.
    enum GateKey {
        static let deadline = "deadline"
        /// 인생의 시간 — 세어 둔 것(자유시간 제외)
        static let count = "count"
    }

    // 개인정보 처리방침·지원 페이지는 GitHub Pages(docs/)로 서비스한다.
    // 이용약관은 별도 문서를 두지 않고 Apple 표준 EULA 를 쓴다.
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: "https://m1zz.github.io/BurningParchment/privacy.html")!,
        supportURL: URL(string: "https://m1zz.github.io/BurningParchment/")!,
        termsURL: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    )

    // 세 칸(무료 · Plus · Pro), 유료 칸마다 연 구독과 평생 (2026-11 개편).
    // 칸마다 무엇이 열리는지와 한도는 `StoreManager.Plan` 이 정한다. 게이트는 무료 한도의 선언이다.
    // ⚠️ `entitlementIDs` 는 **Pro 전체**를 주는 상품만이다(pro 평생 · pro 연 구독). Plus 를 넣으면
    //    LeeoStore 의 `hasPro` 가 Plus 구매자를 Pro 로 본다. Plus 는 StoreManager 가 따로 센다.
    // ⚠️ 선물 · 팁 상품은 productIDs · entitlementIDs 어디에도 넣지 않는다. 넣으면 산 사람 자신이 열린다.
    // ⚠️ 상품 ID 는 App Store Connect 계약이다 — 바꾸지 않는다. 기존 프로(pro)를 산 사람은 그대로 Pro 전체다.
    static let monetization = LeeoMonetization.freemiumSubscription(
        LeeoSubscriptionConfig(
            productIDs: StoreManager.ProductID.allCases.map(\.rawValue),
            termsURL: legal.termsURL!,
            entitlementIDs: StoreManager.fullProductIDs,
            gate: LeeoGatePolicy(freeLimits: [GateKey.deadline: StoreManager.Plan.free.deadlineLimit ?? 1,
                                              GateKey.count: StoreManager.Plan.free.countLimit ?? 1]),
            cacheSuiteName: "group.com.burningparchment.app",
            // 선물: 산 사람에게는 아무것도 열리지 않고, 허브의 묶음에서 App Store 오퍼 코드 한 장을 꺼내 링크로 보낸다.
            // 받는 사람은 App Store 에서 "사용" 한 번 — 여는 것은 App Store 다(지침 3.1.1). 앱이 만든 코드로 열지 않는다.
            gift: LeeoGiftConfig(
                productID: StoreManager.giftProductID,
                grantsProductID: StoreManager.ProductID.pro.rawValue,
                containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
                sellsGifts: true
            ),
            // Plus 선물. 묶음은 Pro 와 따로다 — 열쇠는 허브(FeedbackHub `GiftCodePool.tierPools`)와 같다.
            moreGifts: [LeeoGiftConfig(
                productID: StoreManager.plusGiftProductID,
                grantsProductID: StoreManager.ProductID.plus.rawValue,
                containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
                sellsGifts: true,
                tierName: "Plus",
                poolKey: StoreManager.plusGiftPoolKey
            )],
            // 팁(응원). 아무것도 열지 않는다.
            tipJar: LeeoTipJarConfig(productIDs: StoreManager.tipProductIDs)
        )
    )

    /// App Store 숫자 ID — "리뷰 남기기" 딥링크에 쓰인다.
    static let appStoreID: String? = "6758995390"

    /// 익명 사용 통계. 피드백과 같은 CloudKit 컨테이너로 설치별 스냅샷과 이벤트를 보낸다.
    /// 수집 항목(익명 설치 UUID·앱 버전·OS·로케일·실행 횟수·이벤트 이름)은 개인정보 처리방침에
    /// 그대로 적혀 있어야 한다 — 바꾸려면 PRIVACY.md 와 docs/privacy.html 도 같이 고칠 것.
    static let analytics: any LeeoAnalytics = LeeoUsageAnalytics(spec: BurningParchmentSpec.self)

    // 완성도 선언. 적지 않은 항목은 `.unknown` = "아직 안 했거나 판단하지 않았다"로 정직하게 남는다.
    // LeeoKit 이 계약에서 자동으로 채우는 항목(피드백 채널·리뷰요청·결제 안정성·정책 링크·
    // 계정 삭제·App Store 등록·지원/쇼케이스 페이지)은 여기 적지 않는다.
    static let capabilities = LeeoCapabilities(
        implemented: [
            .crashReporting,    // MetricKit 크래시·행 진단을 피드백 허브로 전송 (LeeoKit.bootstrap)
            .schemaMigration,   // 구버전 UserDefaults.standard → App Group 데이터 이관 (BedtimeManager.runMigrations)
            .emptyStates,       // 데드라인 목록·회고 책 뷰의 빈 상태 화면
            .minimalPermissions,// 알림 + 불 끌 때의 마이크뿐 — 카메라·위치·연락처 등 없음
            .accessibility,     // 주요 화면 VoiceOver 라벨/값/힌트
            .localization,      // 한국어·영어 (String Catalog)
            .darkMode,          // 라이트·다크 테마 + 시스템 설정 따르기 (설정 ▸ 화면 테마)
            .microInteractions, // 햅틱 피드백 (회고 저장·드래그 앤 드랍 등)
            .pushNotifications, // 취침·저녁 회고 넛지 (로컬 알림 기반 재참여)
            .widgets,           // 홈 위젯 + 잠금 화면 위젯 + Live Activity
            .published,         // App Store 출시 완료
        ],
        notApplicable: [
            .encryption: "모든 데이터가 기기 로컬(App Group)에만 저장되고 자체 서버로 전송되지 않는다",
            .networkRetry: "앱 자체 네트워크 통신이 없다 — 결제·피드백 통신은 LeeoKit 이 담당한다",
        ]
    )
}
