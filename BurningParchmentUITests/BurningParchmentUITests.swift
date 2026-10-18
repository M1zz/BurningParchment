// BurningParchmentUITests.swift
// 실행 → 처음 안내 → 메인 → 데드라인 하나 더하기 → 설정을 한 바퀴 돈다. 그리고 접근성 감사.
//
// 언어는 한국어로 고정한다(-AppleLanguages). 알림 권한 창·팁은 실행 인자로 끈다 (DebugLaunch.swift).

import XCTest

final class BurningParchmentUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(skipOnboarding: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR",
                               "-skipNotifications", "YES", "-hideTips", "YES"]
        if skipOnboarding { app.launchArguments += ["-skipOnboarding", "YES"] }
        app.launch()
        return app
    }

    /// 안내를 세 장 넘겨 "시작하기"를 누르면 메인 화면이 나온다.
    func testOnboardingLeadsToMainScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR",
                               "-skipNotifications", "YES", "-hideTips", "YES",
                               "-skipOnboarding", "YES", "-showOnboarding", "YES"]
        app.launch()
        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        next.tap()
        XCTAssertTrue(app.buttons["시작하기"].waitForExistence(timeout: 3))
        next.tap()
        XCTAssertFalse(next.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["시간 설정"].waitForExistence(timeout: 5))
    }

    /// 핵심 흐름 한 바퀴: 데드라인을 하나 더하고, 설정을 열었다 닫는다.
    func testAddDeadlineAndOpenSettings() {
        let app = launch()

        let deadlines = app.buttons["데드라인"]
        XCTAssertTrue(deadlines.waitForExistence(timeout: 10))
        deadlines.tap()

        // 비어 있으면 빈 화면의 단추로, 이미 있으면 + 로 연다 (무료는 1개까지)
        let emptyAdd = app.buttons["deadline.emptyAdd"]
        if emptyAdd.waitForExistence(timeout: 3) {
            emptyAdd.tap()
            let title = app.textFields["deadline.title"]
            XCTAssertTrue(title.waitForExistence(timeout: 5))
            title.tap()
            title.typeText("시험 제출")
            app.navigationBars.buttons["추가"].tap()
            XCTAssertTrue(app.staticTexts["시험 제출"].waitForExistence(timeout: 5))
        }
        app.buttons["닫기"].firstMatch.tap()

        let settings = app.buttons["시간 설정"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 5))
        app.buttons["완료"].tap()
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
    }

    /// 메인 화면의 접근성 감사. 고칠 수 없는 오탐만 근거와 함께 걸러낸다.
    func testMainScreenAccessibilityAudit() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["시간 설정"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit { issue in
            // 실패하면 어느 요소인지 로그에 남긴다
            print("AUDIT", issue.auditType, issue.compactDescription, issue.element?.label ?? "-", issue.element?.frame ?? .zero)
            // 오탐: 기간의 시작·끝 시각(예: "오전 7:00")은 caption2 로 글자 크기를 따르고, 가장 큰 접근성 크기에서는
            // 한 줄 → 두 줄(ViewThatFits)로 바뀌어 끝까지 커진다(AX5 에서 화면으로 확인). 감사는 이 전환을
            // "일부만 커진다"로 읽는다. 다른 요소의 글자 크기 문제는 그대로 실패로 둔다.
            if issue.auditType == .dynamicType, issue.element?.identifier == "period.rangeLabel" {
                return true
            }
            return false
        }
    }
}
