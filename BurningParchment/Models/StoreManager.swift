// StoreManager.swift
// 부분 유료화(프로 일회성 잠금해제) — 파사드
//
// StoreKit 2 엔진(상품 로드·구매·복원·권한 추적·트랜잭션 리스너·오프라인 캐시)은
// 이제 LeeoKit 의 LeeoStore 가 공용으로 담당한다. 이 파일은 그 위에 앱 고유의
// 무료 한도 게이트(항아리/데드라인)만 얹은 얇은 파사드로, 기존 호출부·PaywallView 는
// 그대로 동작한다.
//
// 항아리는 이제 사용자가 만드는 게 아니라 기간에서 파생되므로(UrnPeriod) "개수" 한도가 아니라
// "얼마나 거슬러 올라가 열어볼 수 있나"로 게이트한다. 무료: 최근 1년치 항아리. 프로: 전부.
// 재는 무료에서도 계속 쌓이므로 결제하면 지난 항아리가 그대로 열린다 — 잃는 데이터는 없다.

import Foundation
import Combine
import StoreKit
import LeeoKit

@MainActor
final class StoreManager: ObservableObject {
    static let proProductID = "com.burningparchment.app.pro"

    /// 무료 사용 한도 — 선언은 BurningParchmentSpec.monetization 의 게이트 정책 한 곳에만 있다.
    /// 항아리 한도는 "무료로 열람 가능한 달 수"로 읽는다 (12 = 최근 1년).
    static let freeUrnHistoryMonths = BurningParchmentSpec.gate.freeLimits[BurningParchmentSpec.GateKey.urn] ?? 12
    static let freeDeadlineLimit = BurningParchmentSpec.gate.freeLimits[BurningParchmentSpec.GateKey.deadline] ?? 1

    private let store: LeeoStore
    private var cancellable: AnyCancellable?

    init() {
        store = LeeoStore(config: BurningParchmentSpec.paywall!)
        // 공용 스토어의 상태 변화를 그대로 뷰에 전파한다.
        cancellable = store.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
    }

    // MARK: - 공개 상태 (기존 API 유지)

    var isPro: Bool { store.hasPro }
    var proProduct: Product? { store.products.first }
    var purchaseInProgress: Bool { store.purchasingProductID != nil || store.isRestoring }

    // MARK: - Gates

    /// 이 항아리를 열어볼 수 있는가.  무료는 최근 freeUrnHistoryMonths 개월치(1년)만 열린다.
    func canOpenUrn(_ period: UrnPeriod) -> Bool {
        guard !isPro else { return true }
        return Self.monthsAgo(period) < Self.freeUrnHistoryMonths
    }

    /// 지금으로부터 몇 달 전의 항아리인가.  이번 달이면 0, 지난달이면 1. 미래는 음수.
    static func monthsAgo(_ period: UrnPeriod, now: Date = Date()) -> Int {
        let c = Calendar.current.dateComponents([.year, .month], from: now)
        let nowIndex = (c.year ?? 1) * 12 + (c.month ?? 1)
        return nowIndex - (period.year * 12 + period.month)
    }

    func canAddDeadline(currentCount: Int) -> Bool {
        isPro || currentCount < Self.freeDeadlineLimit
    }

    // MARK: - 구매 / 복원 (LeeoStore 로 위임)

    @discardableResult
    func purchasePro() async -> Bool {
        await store.purchasePrimary()
    }

    func restorePurchases() async {
        await store.restore()
    }
}
