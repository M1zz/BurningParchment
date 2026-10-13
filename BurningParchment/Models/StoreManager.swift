// StoreManager.swift
// 부분 유료화(프로 일회성 잠금해제) — 파사드
//
// StoreKit 2 엔진(상품 로드·구매·복원·권한 추적·트랜잭션 리스너·오프라인 캐시)은
// 이제 LeeoKit 의 LeeoStore 가 공용으로 담당한다. 이 파일은 그 위에 앱 고유의
// 무료 한도 게이트(항아리/데드라인)만 얹은 얇은 파사드로, 기존 호출부·PaywallView 는
// 그대로 동작한다.
//
// 지금 무료 한도는 데드라인 개수 하나뿐이다. 항아리(회고)는 기간과 상관없이 모두 무료로 열린다.

import Foundation
import Combine
import StoreKit
import LeeoKit

@MainActor
final class StoreManager: ObservableObject {
    static let proProductID = "com.burningparchment.app.pro"

    /// 무료 사용 한도 — 선언은 BurningParchmentSpec.monetization 의 게이트 정책 한 곳에만 있다.
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
    var isLoadingProduct: Bool { store.isLoadingProducts }
    /// 마지막 구매·복원·상품 로드 오류 (사용자에게 그대로 보여줄 문장). 취소는 오류가 아니라 nil 이다.
    var lastError: String? { store.lastError }

    // MARK: - Gates

    func canAddDeadline(currentCount: Int) -> Bool {
        isPro || currentCount < Self.freeDeadlineLimit
    }

    // MARK: - 구매 / 복원 (LeeoStore 로 위임)

    /// 페이월이 뜰 때 가격을 미리 받아 둔다. 이미 받았으면 아무것도 하지 않는다.
    func loadProduct() async {
        await store.loadProducts()
    }

    /// 프로를 산다. 결제 시트는 `action`(SwiftUI 의 `@Environment(\.purchase)`)이 띄운다 —
    /// StoreKit 이 창을 짐작하게 두면 아이패드에서 결제가 오류로 끝난다 (심사 2.1(b)).
    @discardableResult
    func purchasePro(using action: (Product) async throws -> Product.PurchaseResult) async -> Bool {
        if store.products.isEmpty { await store.loadProducts() }
        guard let product = store.products.first else { return false }
        return await store.purchase(product, using: action)
    }

    /// 구매를 복원하고, 그 결과로 프로가 열렸는지 돌려준다.
    @discardableResult
    func restorePurchases() async -> Bool {
        await store.restore()
        return isPro
    }
}
