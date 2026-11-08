// StoreManager.swift
// 세 칸(무료 · Plus · Pro) 결제의 파사드.
//
// StoreKit 2 엔진(상품 로드 · 구매 · 복원 · 권한 추적 · 트랜잭션 리스너 · 오프라인 캐시 · 선물 · 팁)은 LeeoKit 의
// LeeoStore 가 맡는다. 이 파일은 그 위에 이 앱의 칸 판정과 무료 한도만 얹는다.
//
//   com.burningparchment.app.pro          Pro 평생  (예전 '프로' — 그때 산 사람은 그대로 Pro 전체다)
//   com.burningparchment.app.pro.yearly   Pro 연 구독
//   com.burningparchment.app.plus         Plus 평생
//   com.burningparchment.app.plus.yearly  Plus 연 구독 (같은 구독 그룹의 낮은 단계)
//
// ⚠️ **평생 구매는 래치다 — 조회가 비었다고 내리지 않는다.** `Transaction.currentEntitlements` 는 App Store 로그아웃 ·
//    기기 초기화 직후 · StoreKit 캐시가 없을 때 조용히 빈 값을 낸다. 그 한 번에 산 사람에게 페이월이 다시 뜨면 신뢰 사고다.
//    그래서 평생 구매는 Keychain 에 적고(앱을 지워도 남는다), **환불을 `Transaction.all` 로 직접 확인했을 때만** 내린다.
// ⚠️ 연 구독은 래치에 적지 않는다. 끝나면 닫혀야 하므로 만료일이 있는 표식(`subscriptionMarks`)으로 둔다.
// ⚠️ 창단 후원자: 이 버전을 처음 연 순간 이미 쓰던 사람은 세어 둔 것을 예전처럼 무제한으로 만든다.
//    경계는 날짜 상수가 아니라 이 버전의 첫 실행이다(`resolveFounder`). 한 번 정하면 다시 정하지 않는다.

import Foundation
import Combine
import Security
import StoreKit
import LeeoKit

@MainActor
final class StoreManager: ObservableObject {

    // MARK: - 상품

    /// 파는 상품. ⚠️ App Store Connect 계약이다 — 값을 바꾸지 않는다.
    enum ProductID: String, CaseIterable {
        case pro = "com.burningparchment.app.pro"
        case proYearly = "com.burningparchment.app.pro.yearly"
        case plus = "com.burningparchment.app.plus"
        case plusYearly = "com.burningparchment.app.plus.yearly"

        var plan: Plan { (self == .plus || self == .plusYearly) ? .plus : .pro }
        var isSubscription: Bool { self == .proYearly || self == .plusYearly }
    }

    /// Pro 전체를 주는 상품. ⚠️ `BurningParchmentSpec.monetization` 의 entitlementIDs 와 같다.
    nonisolated static let fullProductIDs: Set<String> = [ProductID.pro.rawValue, ProductID.proYearly.rawValue]
    /// Plus 를 주는 상품.
    nonisolated static let plusProductIDs: Set<String> = [ProductID.plus.rawValue, ProductID.plusYearly.rawValue]
    /// 평생 상품 — 이것만 래치에 적는다.
    nonisolated static let lifetimeProductIDs: Set<String> = [ProductID.pro.rawValue, ProductID.plus.rawValue]
    /// 연 구독 — 만료일 표식으로 둔다.
    nonisolated static let subscriptionProductIDs: Set<String> = [ProductID.proYearly.rawValue, ProductID.plusYearly.rawValue]

    /// Pro 선물(소모성). 받은 사람에게 App Store 오퍼 코드로 Pro 평생이 열린다.
    /// ⚠️ 판매 상품 · 권한 상품에 넣지 않는다 — 넣으면 선물을 산 사람이 Pro 가 된다.
    nonisolated static let giftProductID = "com.burningparchment.app.gift.pro"
    /// Plus 선물(소모성). 받은 사람에게 Plus 평생이 열린다.
    nonisolated static let plusGiftProductID = "com.burningparchment.app.gift.plus"
    /// Plus 선물의 오퍼 코드 묶음 열쇠 "<번들>#<여는 상품>". 허브(FeedbackHub `GiftCodePool.tierPools`)가 같은 열쇠로 채운다.
    nonisolated static let plusGiftPoolKey = "com.burningparchment.app#com.burningparchment.app.plus"
    /// 팁(응원) 셋, 작은 것부터(소모성). 아무것도 열지 않는다. ⚠️ 이것도 판매 · 권한 상품에 넣지 않는다.
    nonisolated static let tipProductIDs = ["com.burningparchment.app.tip.small",
                                            "com.burningparchment.app.tip.medium",
                                            "com.burningparchment.app.tip.large"]

    // MARK: - 칸

    /// 세 칸. 칸마다 무엇이 열리는지는 여기 한 곳에 있다.
    enum Plan: Int, Comparable, CaseIterable {
        case free, plus, pro

        static func < (a: Plan, b: Plan) -> Bool { a.rawValue < b.rawValue }

        /// 데드라인 한도 (nil = 무제한)
        var deadlineLimit: Int? { self == .free ? 1 : nil }
        /// 세어 둔 것(인생의 시간, 자유시간 제외) 한도 (nil = 무제한)
        var countLimit: Int? {
            switch self {
            case .free: return 1
            case .plus: return 3
            case .pro:  return nil
            }
        }
    }

    /// 지금 가진 상품들로 칸을 정한다 (순수 함수 — 시험 대상).
    /// - Parameters:
    ///   - owned: StoreKit 이 지금 말하는 권한(받은 선물 포함)
    ///   - latched: Keychain 래치에 적힌 평생 상품
    ///   - marks: 연 구독 표식(상품 → 만료일)
    nonisolated static func resolvePlan(owned: Set<String>, latched: Set<String>,
                                        marks: [String: Date], now: Date = Date()) -> Plan {
        let live = owned.union(latched).union(marks.filter { $0.value > now }.keys)
        if !live.isDisjoint(with: fullProductIDs) { return .pro }
        if !live.isDisjoint(with: plusProductIDs) { return .plus }
        return .free
    }

    /// 래치의 다음 값. 보이는 평생 결제는 올리고, **환불을 확인한 것만** 내린다. 빈 조회로는 아무것도 내리지 않는다.
    nonisolated static func nextLatch(current: Set<String>, owned: Set<String>, revoked: Set<String>) -> Set<String> {
        current.union(owned.intersection(lifetimeProductIDs)).subtracting(revoked)
    }

    /// 창단 후원자인가. 이 버전을 처음 연 순간 이미 쓰던 사람(실행이 처음이 아니거나, 세어 둔 것이 이미 있다).
    nonisolated static func resolveFounder(launchCount: Int, hasSavedCounts: Bool) -> Bool {
        launchCount > 1 || hasSavedCounts
    }

    /// 세어 둔 것을 하나 더 만들 수 있는가 (순수 함수 — 시험 대상).
    nonisolated static func canAddCount(plan: Plan, founder: Bool, currentCount: Int) -> Bool {
        if founder { return true }
        guard let limit = plan.countLimit else { return true }
        return currentCount < limit
    }

    /// 데드라인 무료 한도 — 게이트 선언(`BurningParchmentSpec.monetization`)과 같은 값이다.
    static let freeDeadlineLimit = BurningParchmentSpec.gate.freeLimits[BurningParchmentSpec.GateKey.deadline] ?? 1

    // MARK: - 상태

    private let store: LeeoStore
    private var cancellable: AnyCancellable?
    private let defaults: UserDefaults
    /// 래치에 적힌 평생 상품
    @Published private(set) var latched: Set<String>
    /// 연 구독 표식(상품 → 만료일)
    @Published private(set) var subscriptionMarks: [String: Date]
    /// 창단 후원자 — 세어 둔 것 무제한
    let isFounder: Bool
    private var isRefreshing = false

    nonisolated static let latchKey = "burningparchment.lifetime.owned"
    nonisolated static let marksKey = "burningparchment.subscription.marks"
    nonisolated static let founderKey = "burningparchment.founder"
    nonisolated static let founderDecidedKey = "burningparchment.founder.decided"

    init() {
        #if DEBUG
        // 시뮬레이터에서 칸 화면을 보려고 `-forcePro YES|NO` 로 실행할 수 있다 (DebugLaunch.swift)
        store = LeeoStore(config: BurningParchmentSpec.paywall!, unlockOverride: { DebugLaunch.forcePro })
        #else
        store = LeeoStore(config: BurningParchmentSpec.paywall!)
        #endif
        let defaults = UserDefaults(suiteName: "group.com.burningparchment.app") ?? .standard
        self.defaults = defaults
        latched = Self.loadLatch(defaults: defaults)
        subscriptionMarks = (defaults.dictionary(forKey: Self.marksKey) as? [String: Double] ?? [:])
            .mapValues { Date(timeIntervalSince1970: $0) }
        isFounder = Self.decideFounderOnce(defaults: .standard)

        cancellable = store.objectWillChange.sink { [weak self] in
            // 값이 바뀐 다음에 읽도록 다음 틱으로 미룬다
            Task { @MainActor in
                self?.absorbStore()
                self?.objectWillChange.send()
            }
        }
        absorbStore()
        Task { await refresh() }
    }

    // MARK: - 공개 상태

    /// 지금 칸
    var plan: Plan {
        #if DEBUG
        if let forced = DebugLaunch.forcePro { return forced ? .pro : .free }
        #endif
        return Self.resolvePlan(owned: store.purchasedProductIDs, latched: latched, marks: subscriptionMarks)
    }
    /// Pro 전체
    var isPro: Bool { plan == .pro }
    /// Plus 이상 — 테마 · 조각 카드 · 회고 책 PDF · 한 해의 재 · 데드라인 무제한
    var hasPlus: Bool { plan >= .plus }

    var products: [Product] { store.products }
    func product(_ id: ProductID) -> Product? { store.products.first { $0.id == id.rawValue } }
    var purchaseInProgress: Bool { store.purchasingProductID != nil || store.isRestoring }
    var purchasingProductID: String? { store.purchasingProductID }
    var isLoadingProduct: Bool { store.isLoadingProducts }
    /// 마지막 구매 · 복원 · 상품 로드 오류(그대로 보여 줄 문장). 취소는 오류가 아니라 nil 이다.
    var lastError: String? { store.lastError }
    /// 파는 선물 전부(Pro, Plus). 화면은 각각을 따로 관찰한다.
    var gifts: [LeeoGiftStore] { store.gifts }
    /// 팁 엔진. 화면이 따로 관찰한다.
    var tipJar: LeeoTipJar? { store.tipJar }

    // MARK: - 한도

    func canAddDeadline(currentCount: Int) -> Bool {
        guard let limit = plan.deadlineLimit else { return true }
        return currentCount < limit
    }

    func canAddCount(currentCount: Int) -> Bool {
        Self.canAddCount(plan: plan, founder: isFounder, currentCount: currentCount)
    }

    // MARK: - 구매 · 복원

    func loadProduct() async {
        await store.loadProducts()
    }

    /// 산다. 결제 시트는 `action`(SwiftUI `@Environment(\.purchase)`)이 띄운다 —
    /// StoreKit 이 창을 짐작하게 두면 아이패드에서 결제가 오류로 끝난다 (심사 2.1(b)).
    @discardableResult
    func purchase(_ id: ProductID, using action: (Product) async throws -> Product.PurchaseResult) async -> Bool {
        if product(id) == nil { await store.loadProducts() }
        guard let product = product(id) else { return false }
        let ok = await store.purchase(product, using: action)
        await refresh()
        return ok
    }

    /// 구매를 복원하고, 그 결과 유료 칸이 열렸는지 돌려준다.
    @discardableResult
    func restorePurchases() async -> Bool {
        await store.restore()
        await refresh()
        return hasPlus
    }

    /// 권한을 다시 읽는다 — 앞으로 돌아올 때 · 코드를 쓴 뒤 · 페이월이 열릴 때.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await store.refreshEntitlements()
        absorbStore()
        await updateSubscriptionMarks()
        await dropRevoked()
    }

    // MARK: - 래치 · 표식

    /// 보이는 평생 결제를 래치에 올린다(내리지는 않는다).
    private func absorbStore() {
        let next = Self.nextLatch(current: latched, owned: store.purchasedProductIDs, revoked: [])
        if next != latched { saveLatch(next) }
    }

    /// 살아 있는 연 구독의 만료일을 적는다.
    private func updateSubscriptionMarks() async {
        var marks = subscriptionMarks.filter { $0.value > Date() }
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result, Self.subscriptionProductIDs.contains(tx.productID),
                  tx.revocationDate == nil, let expires = tx.expirationDate else { continue }
            marks[tx.productID] = max(expires, marks[tx.productID] ?? .distantPast)
        }
        if marks != subscriptionMarks { saveMarks(marks) }
    }

    /// 래치 · 표식에는 있는데 지금 권한에 없는 상품 — 환불(회수)을 `Transaction.all` 로 직접 확인했을 때만 내린다.
    private func dropRevoked() async {
        let suspects = latched.union(subscriptionMarks.keys).subtracting(store.purchasedProductIDs)
        guard !suspects.isEmpty else { return }
        var revoked: Set<String> = []
        var valid: Set<String> = []
        for await result in Transaction.all {
            guard case .verified(let tx) = result, suspects.contains(tx.productID) else { continue }
            if tx.revocationDate != nil { revoked.insert(tx.productID) } else { valid.insert(tx.productID) }
        }
        // 같은 상품을 다시 산 기록이 있으면 환불된 것으로 보지 않는다
        let confirmed = revoked.subtracting(valid)
        guard !confirmed.isEmpty else { return }
        saveLatch(Self.nextLatch(current: latched, owned: [], revoked: confirmed))
        saveMarks(subscriptionMarks.filter { !confirmed.contains($0.key) })
    }

    private func saveLatch(_ ids: Set<String>) {
        latched = ids
        let list = Array(ids).sorted()
        defaults.set(list, forKey: Self.latchKey)
        Keychain.save(list.joined(separator: ","), key: Self.latchKey)
    }

    private func saveMarks(_ marks: [String: Date]) {
        subscriptionMarks = marks
        defaults.set(marks.mapValues(\.timeIntervalSince1970), forKey: Self.marksKey)
    }

    /// UserDefaults 와 Keychain 을 합친다 — 앱을 지웠다 깔면 UserDefaults 는 비지만 Keychain 은 남는다.
    nonisolated private static func loadLatch(defaults: UserDefaults) -> Set<String> {
        let fromDefaults = Set(defaults.stringArray(forKey: latchKey) ?? [])
        let fromKeychain = Set((Keychain.load(key: latchKey) ?? "").split(separator: ",").map(String.init))
        return fromDefaults.union(fromKeychain).intersection(lifetimeProductIDs)
    }

    /// 창단 후원자를 **한 번만** 정한다. Keychain 에 남은 기록이 있으면(다시 깐 사람) 그대로 후원자다.
    private static func decideFounderOnce(defaults: UserDefaults) -> Bool {
        if Keychain.load(key: founderKey) == "1" || defaults.bool(forKey: founderKey) { return true }
        guard !defaults.bool(forKey: founderDecidedKey) else { return false }
        defaults.set(true, forKey: founderDecidedKey)
        let saved = RemainingItemStore.decode(defaults.data(forKey: RemainingItemStore.key) ?? Data())
        let founder = resolveFounder(launchCount: LeeoEngagement.shared.launchCount,
                                     hasSavedCounts: saved.contains { !$0.isFreeTime })
        if founder {
            defaults.set(true, forKey: founderKey)
            Keychain.save("1", key: founderKey)
        }
        return founder
    }
}

// MARK: - Keychain

/// 앱을 지워도 남아야 하는 작은 기록(평생 구매 래치 · 창단 후원자).
enum Keychain {
    private static let service = "com.burningparchment.app.purchases"

    static func save(_ value: String, key: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service,
                                   kSecAttrAccount as String: key]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: key,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
