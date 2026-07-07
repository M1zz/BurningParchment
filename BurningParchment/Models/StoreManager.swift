// StoreManager.swift
// 부분 유료화(프로 일회성 잠금해제) — StoreKit 2
// 무료: 항아리 1개, 데드라인 1개.  프로: 무제한.

import Foundation
import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    static let proProductID = "com.burningparchment.app.pro"

    /// 무료 사용 한도
    static let freeUrnLimit = 1
    static let freeDeadlineLimit = 1

    @Published var isPro: Bool
    @Published var proProduct: Product?
    @Published var purchaseInProgress = false

    private let sd = UserDefaults(suiteName: "group.com.burningparchment.app")
    private let cachedKey = "cached_isPro"

    init() {
        // 네트워크 확인 전까지는 마지막으로 알던 상태로 시작 (기능 깜빡임 방지)
        isPro = sd?.bool(forKey: cachedKey) ?? false

        Task { await listenForTransactions() }
        Task {
            await loadProduct()
            await refreshEntitlements()
        }
    }

    // MARK: - Gates

    func canAddUrn(currentCount: Int) -> Bool {
        isPro || currentCount < Self.freeUrnLimit
    }

    func canAddDeadline(currentCount: Int) -> Bool {
        isPro || currentCount < Self.freeDeadlineLimit
    }

    // MARK: - StoreKit

    func loadProduct() async {
        guard proProduct == nil else { return }
        proProduct = try? await Product.products(for: [Self.proProductID]).first
    }

    /// 현재 소유 중인 영수증 기준으로 프로 여부 갱신
    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result,
               t.productID == Self.proProductID,
               t.revocationDate == nil {
                owned = true
            }
        }
        setPro(owned)
    }

    /// 앱 외부(가족 공유, 환불 등)에서 발생하는 트랜잭션 반영
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let t) = result else { continue }
            if t.productID == Self.proProductID {
                setPro(t.revocationDate == nil)
            }
            await t.finish()
        }
    }

    @discardableResult
    func purchasePro() async -> Bool {
        await loadProduct()
        guard let product = proProduct else { return false }

        purchaseInProgress = true
        defer { purchaseInProgress = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let t) = verification else { return false }
                setPro(true)
                await t.finish()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    func restorePurchases() async {
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func setPro(_ value: Bool) {
        isPro = value
        sd?.set(value, forKey: cachedKey)
    }
}
