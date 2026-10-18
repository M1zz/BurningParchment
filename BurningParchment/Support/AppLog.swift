// AppLog.swift
// 앱 기록(통합 로그)과 성능 구간(signpost)을 한 곳에 둔다.
//
// - 기록은 Console.app 에서 subsystem `com.burningparchment.app` 으로 걸러 본다.
//   사용자가 쓴 글(회고 본문 등)은 남기지 않는다 — 개수·결과·오류만 남긴다.
// - 성능 구간은 Instruments ▸ Points of Interest 에 보인다. 데이터를 읽어 들이거나
//   회고 책 PDF 를 만드는 것처럼 사용자가 기다리는 일에만 건다.

import Foundation
import OSLog

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.burningparchment.app"

    /// 실행·세이프 모드·원격 스위치처럼 앱 전체의 흐름
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    /// 회고·조각·데드라인 저장과 읽기
    static let storage = Logger(subsystem: subsystem, category: "storage")
    /// 잠금화면 실시간 현황(Live Activity)
    static let liveActivity = Logger(subsystem: subsystem, category: "liveActivity")
    /// 마이크(입김)·건강 앱 수면 기록
    static let sensors = Logger(subsystem: subsystem, category: "sensors")
    /// 회고 책 PDF·조각 카드 내보내기
    static let export = Logger(subsystem: subsystem, category: "export")

    /// 사용자가 기다리는 작업의 시간을 잰다.
    static let signposter = OSSignposter(subsystem: subsystem, category: .pointsOfInterest)

    /// `name` 구간으로 `work` 를 감싼다. 결과는 그대로 돌려준다.
    static func measure<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
        let state = signposter.beginInterval(name, id: signposter.makeSignpostID())
        defer { signposter.endInterval(name, state) }
        return try work()
    }
}
