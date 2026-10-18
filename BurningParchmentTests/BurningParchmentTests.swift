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
