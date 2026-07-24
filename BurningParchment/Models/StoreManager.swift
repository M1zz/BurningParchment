// StoreManager.swift
// 부분 유료화(프로 일회성 잠금해제) — 파사드
//
// StoreKit 2 엔진(상품 로드·구매·복원·권한 추적·트랜잭션 리스너·오프라인 캐시)은
// 이제 LeeoKit 의 LeeoStore 가 공용으로 담당한다. 이 파일은 그 위에 앱 고유의
// 무료 한도 게이트(항아리/데드라인)만 얹은 얇은 파사드로, 기존 호출부·PaywallView 는
// 그대로 동작한다. (무료: 항아리 1개, 데드라인 1개. 프로: 무제한.)

import Foundation
import Combine
import StoreKit
import LeeoKit

@MainActor
final class StoreManager: ObservableObject {
    static let proProductID = "com.burningparchment.app.pro"

    /// 무료 사용 한도
    static let freeUrnLimit = 1
    static let freeDeadlineLimit = 1

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

    func canAddUrn(currentCount: Int) -> Bool {
        isPro || currentCount < Self.freeUrnLimit
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
