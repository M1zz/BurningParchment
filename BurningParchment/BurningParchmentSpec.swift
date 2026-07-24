import Foundation
import LeeoKit

enum BurningParchmentSpec: LeeoAppSpec {
    static let appName = "불타는 내인생"
    static let developerEmail = "mizzking75@gmail.com"
    static let feedback = LeeoFeedbackConfig(containerIdentifier: "iCloud.com.Ysoup.FeedbackHub", appIdentifier: "com.burningparchment.app")

    // 인앱 결제(프로 일회성 잠금해제). StoreKit 엔진은 LeeoKit 이 담당하고,
    // 앱은 이 구성과 얇은 StoreManager 파사드(무료 한도 게이트)만 유지한다.
    static let paywall = LeeoPaywallConfig(
        productIDs: ["com.burningparchment.app.pro"],
        termsURL: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"),
        privacyURL: URL(string: "https://github.com/M1zz/BurningParchment/blob/main/PRIVACY.md"),
        cacheSuiteName: "group.com.burningparchment.app"
    )
}
