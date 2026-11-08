// BurningParchmentTests.swift
// 앱의 핵심 판단(데드라인 진행·회고 분류·처음 온 사람 가르기·퍼널)과 계약(LeeoPreflight)을 지킨다.

import XCTest
import LeeoKit
@testable import BurningParchment

final class SpecTests: XCTestCase {
    /// 출시하면 안 되는 계약 문제(페이월 경로 없음·https 아닌 정책 URL 등)가 없어야 한다.
    func testSpecIsReleasable() {
        let issues = LeeoPreflight.audit(BurningParchmentSpec.self)
        XCTAssertTrue(issues.isReleasable, issues.errors.map { "[\($0.code)] \($0.message)" }.joined(separator: "\n"))
    }

    @MainActor
    func testFreeDeadlineLimitComesFromGatePolicy() {
        XCTAssertEqual(StoreManager.freeDeadlineLimit, 1)
    }
}

final class DeadlineTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testProgressIsClampedBetweenZeroAndOne() {
        let d = Deadline(title: "t", targetDate: start.addingTimeInterval(100), startDate: start)
        XCTAssertEqual(d.progress(at: start.addingTimeInterval(-50)), 0)
        XCTAssertEqual(d.progress(at: start.addingTimeInterval(50)), 0.5, accuracy: 0.0001)
        XCTAssertEqual(d.progress(at: start.addingTimeInterval(500)), 1)
    }

    func testRemainingAndExpiry() {
        let d = Deadline(title: "t", targetDate: start.addingTimeInterval(100), startDate: start)
        XCTAssertEqual(d.remaining(at: start), 100)
        XCTAssertEqual(d.remaining(at: start.addingTimeInterval(200)), 0)
        XCTAssertFalse(d.isExpired(at: start))
        XCTAssertTrue(d.isExpired(at: start.addingTimeInterval(100)))
    }

    /// 예전 저장 데이터에는 startDate 가 없다 — createdDate 로 채워야 진행률이 그대로다.
    func testDecodingLegacyDataFallsBackToCreatedDate() throws {
        let legacy = """
        {"id":"\(UUID().uuidString)","title":"old","emoji":"🎯","targetDate":200,"createdDate":100}
        """.data(using: .utf8)!
        let d = try JSONDecoder().decode(Deadline.self, from: legacy)
        XCTAssertEqual(d.startDate, d.createdDate)
    }
}

final class ReflectionCategoryTests: XCTestCase {
    func testQuadrants() {
        XCTAssertEqual(ReflectionCategory.from(intent: true, spentTime: true, drift: nil), .forged)
        XCTAssertEqual(ReflectionCategory.from(intent: true, spentTime: false, drift: nil), .missed)
        XCTAssertEqual(ReflectionCategory.from(intent: false, spentTime: false, drift: nil), .scattered)
    }

    /// 의지 없이 시간을 쓴 일은 "그만둘 것"인지 "받아들일 것"인지 골라야 정해진다.
    func testDriftDecidesUnintendedTime() {
        XCTAssertNil(ReflectionCategory.from(intent: false, spentTime: true, drift: nil))
        XCTAssertEqual(ReflectionCategory.from(intent: false, spentTime: true, drift: .stop), .stop)
        XCTAssertEqual(ReflectionCategory.from(intent: false, spentTime: true, drift: .accept), .accept)
    }
}

final class LaunchAudienceTests: XCTestCase {
    private let current = WhatsNewContent.version

    func testFirstLaunchIsNewcomer() {
        let a = LaunchAudience.resolve(launchCount: 1, hasCompletedOnboarding: false, lastSeenWhatsNew: "", current: current)
        XCTAssertEqual(a, .newcomer)
        XCTAssertTrue(a.showsOnboarding)
        XCTAssertFalse(a.showsWhatsNew)
    }

    /// 안내를 끝내지 못하고 다시 연 사람은 여전히 안내를 본다 (새 소식이 아니라).
    func testUnfinishedOnboardingStaysNewcomer() {
        XCTAssertEqual(LaunchAudience.resolve(launchCount: 2, hasCompletedOnboarding: false,
                                              lastSeenWhatsNew: current, current: current), .newcomer)
    }

    /// 예전 버전을 쓰다 업데이트한 사람 — 안내 기록은 없지만 새 소식만 본다.
    func testUpdatedUserSeesWhatsNewOnce() {
        XCTAssertEqual(LaunchAudience.resolve(launchCount: 40, hasCompletedOnboarding: false,
                                              lastSeenWhatsNew: "", current: current), .returningNeedsWhatsNew)
        XCTAssertEqual(LaunchAudience.resolve(launchCount: 41, hasCompletedOnboarding: true,
                                              lastSeenWhatsNew: current, current: current), .returning)
    }
}

final class FunnelTests: XCTestCase {
    private final class Recorder: LeeoAnalytics, @unchecked Sendable {
        var names: [String] = []
        func track(_ event: LeeoEvent) {
            if case .custom(let name, _) = event { names.append(name) }
        }
    }

    override func setUp() { BurningFunnel.resetForTesting() }
    override func tearDown() { BurningFunnel.resetForTesting() }

    /// 단계마다 이벤트는 처음 닿았을 때 한 번만 나간다 — 그래야 이벤트 수가 설치 수다.
    func testEachStageIsSentOnce() {
        let recorder = Recorder()
        XCTAssertTrue(BurningFunnel.firstReflection.reach(analytics: recorder))
        XCTAssertFalse(BurningFunnel.firstReflection.reach(analytics: recorder))
        XCTAssertTrue(BurningFunnel.firstBlowOut.reach(analytics: recorder))
        XCTAssertEqual(recorder.names, ["funnel_first_reflection", "funnel_first_blowout"])
    }
}

/// 인생의 시간 템플릿 — 묻는 말로 만든 구간이 보통의 세어 둔 것과 같은 셈을 하는지
final class LifeTemplateTests: XCTestCase {
    private func template(_ id: String) -> LifeTemplate {
        LifeTemplate.all(myAge: 35, expectancy: 83).first { $0.id == id }!
    }

    /// 35살, 부모님 65살, 1년에 10일 → 남은 해는 18년이지만 남은 날은 180일, 이미 대부분을 보냈다
    func testParentsAreFrontLoaded() {
        let (item, shape) = template("parents").item(["me": 35, "parent": 65, "perYear": 10])
        XCTAssertEqual(shape.pastYears, 35)
        XCTAssertEqual(shape.remainingYears, 18)
        XCTAssertEqual(item.remaining, 180)
        XCTAssertEqual(item.past, 20 * 330 + 15 * 10)
        XCTAssertGreaterThan(Double(item.past) / Double(item.past + item.remaining), 0.9)
    }

    /// 기대 수명을 넘은 나이를 넣어도 음수가 되지 않는다
    func testNoNegativeRemaining() {
        let (item, shape) = template("parents").item(["me": 60, "parent": 95, "perYear": 10])
        XCTAssertEqual(shape.remainingYears, 0)
        XCTAssertEqual(item.remaining, 0)
    }

    /// 여행은 일흔다섯이 넘으면 0 — 남은 해가 많아도 남은 여행은 그 앞에서 끝난다
    func testTravelStopsAtSeventyFive() {
        let (item, _) = template("travel").item(["me": 35, "perYear": 2])
        XCTAssertEqual(item.remaining, 30 * 2 + 10 * 1)
    }

    /// 템플릿마다 마지막 구간은 끝이 열려 있고, 저장 형식은 보통의 세어 둔 것과 같다
    func testTemplatesNormalizeAndRoundTrip() throws {
        for t in LifeTemplate.all(myAge: 35, expectancy: 83) {
            let (item, _) = t.item([:])
            XCTAssertNil(item.phases.last?.untilYear, t.id)
            let data = RemainingItemStore.encode([item])
            XCTAssertEqual(RemainingItemStore.decode(data).first?.remaining, item.remaining, t.id)
        }
    }
}

/// 세 칸 결제 — 권한 래치, 선물 · 팁이 판매 상품과 겹치지 않음, 기존 구매자 유지, 칸별 한도, 창단 후원자.
final class MonetizationTests: XCTestCase {
    private typealias SM = StoreManager
    private let pro = SM.ProductID.pro.rawValue
    private let plus = SM.ProductID.plus.rawValue
    private let proYearly = SM.ProductID.proYearly.rawValue
    private let plusYearly = SM.ProductID.plusYearly.rawValue

    // MARK: 래치

    /// 조회가 비어도(로그아웃 · 초기화 직후) 평생 구매는 내려가지 않는다
    func testLatchSurvivesEmptyLookup() {
        XCTAssertEqual(SM.nextLatch(current: [pro], owned: [], revoked: []), [pro])
        XCTAssertEqual(SM.resolvePlan(owned: [], latched: [pro], marks: [:]), .pro)
    }

    /// 환불을 확인한 것만 내린다
    func testLatchDropsOnlyConfirmedRefund() {
        XCTAssertEqual(SM.nextLatch(current: [pro, plus], owned: [], revoked: [plus]), [pro])
    }

    /// 연 구독은 래치에 적지 않는다 — 끝나면 닫혀야 한다
    func testSubscriptionsAreNotLatched() {
        XCTAssertEqual(SM.nextLatch(current: [], owned: [proYearly, plusYearly, plus], revoked: []), [plus])
    }

    /// 구독 표식은 만료일까지만 연다
    func testSubscriptionMarkExpires() {
        let now = Date()
        XCTAssertEqual(SM.resolvePlan(owned: [], latched: [], marks: [plusYearly: now.addingTimeInterval(60)], now: now), .plus)
        XCTAssertEqual(SM.resolvePlan(owned: [], latched: [], marks: [proYearly: now.addingTimeInterval(-60)], now: now), .free)
    }

    // MARK: 기존 사용자

    /// 예전 '프로' 평생(pro)을 산 사람은 Pro 전체다 — Plus 로 떨어지지 않는다
    func testExistingProBuyerKeepsFullPro() {
        XCTAssertEqual(SM.resolvePlan(owned: [pro], latched: [], marks: [:]), .pro)
        XCTAssertTrue(BurningParchmentSpec.paywall!.entitlementIDs.contains(pro))
    }

    /// Plus 는 Pro 를 열지 않는다
    func testPlusIsNotPro() {
        XCTAssertEqual(SM.resolvePlan(owned: [plus], latched: [], marks: [:]), .plus)
        XCTAssertEqual(SM.resolvePlan(owned: [plusYearly], latched: [], marks: [:]), .plus)
        XCTAssertFalse(BurningParchmentSpec.paywall!.entitlementIDs.contains(plus))
        XCTAssertFalse(BurningParchmentSpec.paywall!.entitlementIDs.contains(plusYearly))
    }

    // MARK: 선물 · 팁

    /// 선물 · 팁 상품은 판매 상품 · 권한 상품 어디에도 없다 — 있으면 산 사람 자신이 열린다
    func testGiftsAndTipsAreNotSoldOrEntitling() {
        let config = BurningParchmentSpec.paywall!
        let sold = Set(config.productIDs).union(config.entitlementIDs)
        let gifts = Set(config.gifts.map(\.productID))
        XCTAssertEqual(gifts, [SM.giftProductID, SM.plusGiftProductID])
        XCTAssertTrue(sold.isDisjoint(with: gifts))
        XCTAssertTrue(sold.isDisjoint(with: SM.tipProductIDs))
    }

    /// 선물은 판매 중인 평생 상품을 연다. Plus 묶음 열쇠는 "<번들>#<여는 상품>" 이다
    func testGiftsGrantSoldLifetimeProducts() {
        let config = BurningParchmentSpec.paywall!
        for gift in config.gifts {
            XCTAssertTrue(SM.lifetimeProductIDs.contains(gift.grantsProductID), gift.productID)
            XCTAssertTrue(gift.sellsGifts)
        }
        XCTAssertEqual(SM.plusGiftPoolKey, "com.burningparchment.app#\(plus)")
        XCTAssertEqual(config.gifts.last?.poolKey, SM.plusGiftPoolKey)
    }

    // MARK: 한도

    func testCountLimitsPerPlan() {
        XCTAssertTrue(SM.canAddCount(plan: .free, founder: false, currentCount: 0))
        XCTAssertFalse(SM.canAddCount(plan: .free, founder: false, currentCount: 1))
        XCTAssertTrue(SM.canAddCount(plan: .plus, founder: false, currentCount: 2))
        XCTAssertFalse(SM.canAddCount(plan: .plus, founder: false, currentCount: 3))
        XCTAssertTrue(SM.canAddCount(plan: .pro, founder: false, currentCount: 500))
    }

    func testDeadlineLimitIsFreeOnly() {
        XCTAssertEqual(SM.Plan.free.deadlineLimit, 1)
        XCTAssertNil(SM.Plan.plus.deadlineLimit)
        XCTAssertNil(SM.Plan.pro.deadlineLimit)
    }

    /// 창단 후원자는 무료여도 세어 둔 것을 예전처럼 무제한으로 만든다
    func testFounderCountsAreUnlimited() {
        XCTAssertTrue(SM.canAddCount(plan: .free, founder: true, currentCount: 40))
        XCTAssertTrue(SM.resolveFounder(launchCount: 7, hasSavedCounts: false))
        XCTAssertTrue(SM.resolveFounder(launchCount: 1, hasSavedCounts: true))
        XCTAssertFalse(SM.resolveFounder(launchCount: 1, hasSavedCounts: false))
    }

    /// 한도는 새로 만들 때만 — 이미 있는 것을 고치거나 자유시간은 세지 않는다
    func testLimitAppliesOnlyToNewCounts() {
        let a = RemainingItem.template(pastYears: 30, remainingYears: 40)
        let free = RemainingItem.freeTimeTemplate(pastYears: 30, remainingYears: 40, weeklyMinutes: 0)
        let data = RemainingItemStore.encode([a, free])
        XCTAssertNil(RemainingItemStore.countBeforeAdding(a, in: data))
        XCTAssertNil(RemainingItemStore.countBeforeAdding(free, in: data))
        XCTAssertEqual(RemainingItemStore.countBeforeAdding(.template(pastYears: 1, remainingYears: 1), in: data), 1)
    }
}
