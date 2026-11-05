// BurnDay.swift
// 기상 · 취침 시각만으로 "지금 어디쯤인가" 를 정한다. 워치 앱과 컴플리케이션이 같이 쓴다.
// 폰의 BedtimeManager.recalculate 와 같은 규칙이다(자정을 넘겨 자는 사람 포함).

import Foundation

struct BurnDay {
    let day: WristMessage.Day
    var calendar = Calendar.current

    /// 불을 끌 수 있는 때 — 취침 30분 전부터 (폰의 BedtimeManager.blowOutWindowSeconds 와 같다)
    static let blowOutWindow: TimeInterval = 1800

    enum Phase: Equatable {
        /// 깨어 있는 낮 — 양피지가 탄다
        case burning(wake: Date, bed: Date)
        /// 취침 ~ 기상
        case sleeping(bed: Date, wake: Date)
    }

    func phase(at now: Date) -> Phase {
        let todayWake = at(now, day.wakeHour, day.wakeMinute)
        if now >= todayWake {
            var bed = at(now, day.bedHour, day.bedMinute)
            if bed <= todayWake { bed = add(1, bed) }
            if now < bed { return .burning(wake: todayWake, bed: bed) }
            return .sleeping(bed: bed, wake: add(1, todayWake))
        }
        let yesterdayWake = add(-1, todayWake)
        var bed = at(yesterdayWake, day.bedHour, day.bedMinute)
        if bed <= yesterdayWake { bed = add(1, bed) }
        if now < bed { return .burning(wake: yesterdayWake, bed: bed) }
        return .sleeping(bed: bed, wake: todayWake)
    }

    /// 낮 동안 탄 비율 (0~1). 밤에는 1.
    func burnProgress(at now: Date) -> Double {
        guard case let .burning(wake, bed) = phase(at: now) else { return 1 }
        let total = max(bed.timeIntervalSince(wake), 1)
        return min(max(now.timeIntervalSince(wake) / total, 0), 1)
    }

    /// 지금 이 밤에 이미 불을 껐다면 그 기록
    func blownOut(at now: Date) -> WristMessage.BlownOut? {
        guard case let .burning(_, bed) = phase(at: now) else { return nil }
        return day.blownOut.first { abs($0.bedtime.timeIntervalSince(bed)) < 1 }
    }

    /// 손목에서 불을 끌 수 있는가 — 취침 30분 전부터, 아직 끄지 않았을 때
    func canBlowOut(at now: Date) -> Bool {
        guard case let .burning(_, bed) = phase(at: now) else { return false }
        return bed.timeIntervalSince(now) <= Self.blowOutWindow && blownOut(at: now) == nil
    }

    /// 상태가 바뀌는 다음 순간들 — 컴플리케이션 타임라인이 이 순간에 꼭 항목을 둔다.
    func transitions(after now: Date, within span: TimeInterval) -> [Date] {
        var out: [Date] = []
        var cursor = now
        let end = now.addingTimeInterval(span)
        while cursor < end {
            let next: Date
            switch phase(at: cursor) {
            case let .burning(_, bed):
                let window = bed.addingTimeInterval(-Self.blowOutWindow)
                next = window > cursor ? window : bed
            case let .sleeping(_, wake):
                next = wake
            }
            guard next > cursor, next < end else { break }
            out.append(next)
            cursor = next.addingTimeInterval(1)
        }
        return out
    }

    private func at(_ date: Date, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    private func add(_ days: Int, _ date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }
}
