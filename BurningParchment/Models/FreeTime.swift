// FreeTime.swift
// 불타는 자유시간 (프로).
//
// 일주일 가운데 잠·일·해야 할 일을 빼고 정말 나만을 위한 시간을 요일·시각으로 적어 두면,
// 이번 주 양피지는 그 시간이 지나가는 동안에만 탄다. 자유시간 밖에서는 불이 꺼진 채 기다린다.
// 주는 월요일 0시에 시작한다(1주 탭과 같다).

import Foundation
import Combine

/// 한 요일의 자유시간 한 토막. 끝이 시작보다 이르거나 같으면 자정을 넘어 다음 날에 끝난다.
struct FreeTimeBlock: Codable, Identifiable, Hashable {
    var id = UUID()
    /// 1 = 월요일 … 7 = 일요일
    var weekday: Int
    /// 자정부터 센 분 (0..<1440)
    var startMinute: Int
    var endMinute: Int

    var durationMinutes: Int {
        endMinute > startMinute ? endMinute - startMinute : endMinute + 1440 - startMinute
    }

    /// 짧은 요일 이름 (월 / Mon)
    static func weekdaySymbol(_ weekday: Int) -> String {
        Calendar.current.shortWeekdaySymbols[weekday % 7]
    }

    static func timeString(_ minute: Int) -> String {
        TimeFormat.short(hour: (minute / 60) % 24, minute: minute % 60)
    }

    var rangeString: String {
        "\(Self.timeString(startMinute)) – \(Self.timeString(endMinute))"
    }

    /// 깨어 있는 시간(기상~취침) 안에 다 들어가는지. 잠과 겹치면 false.
    func fitsAwake(wakeMinute: Int, bedMinute: Int) -> Bool {
        let bed = bedMinute > wakeMinute ? bedMinute : bedMinute + 1440
        let start = startMinute >= wakeMinute ? startMinute : startMinute + 1440
        return start + durationMinutes <= bed
    }
}

/// 이번 주 자유시간이 얼마나 탔는지
struct FreeTimeWeek {
    let weekStart: Date
    let weekEnd: Date
    /// 이번 주 자유시간 전체 (초)
    let total: TimeInterval
    /// 지금까지 지나간 자유시간 (초)
    let elapsed: TimeInterval
    /// 지금 지나고 있는 자유시간. 밖이면 nil.
    let current: DateInterval?
    /// 이번 주에 다음으로 올 자유시간
    let next: DateInterval?

    var remaining: TimeInterval { max(total - elapsed, 0) }
    var progress: Double { total > 0 ? min(elapsed / total, 1) : 0 }
    var isBurning: Bool { current != nil }
}

final class FreeTimeManager: ObservableObject {
    @Published private(set) var blocks: [FreeTimeBlock] = []

    static let storageKey = "freeTimeBlocks_v1"
    private let defaults = UserDefaults(suiteName: "group.com.burningparchment.app") ?? .standard

    init() {
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([FreeTimeBlock].self, from: data) {
            blocks = saved
        }
    }

    var isConfigured: Bool { !blocks.isEmpty }

    // MARK: Editing

    /// 고른 요일마다 같은 시각의 토막을 더한다.
    func add(weekdays: Set<Int>, startMinute: Int, endMinute: Int) {
        guard startMinute != endMinute else { return }
        for day in weekdays.sorted() {
            blocks.append(FreeTimeBlock(weekday: day, startMinute: startMinute, endMinute: endMinute))
        }
        sortAndSave()
    }

    func remove(_ block: FreeTimeBlock) {
        blocks.removeAll { $0.id == block.id }
        sortAndSave()
    }

    func replaceAll(_ newBlocks: [FreeTimeBlock]) {
        blocks = newBlocks
        sortAndSave()
    }

    private func sortAndSave() {
        blocks.sort { ($0.weekday, $0.startMinute) < ($1.weekday, $1.startMinute) }
        if let data = try? JSONEncoder().encode(blocks) {
            defaults.set(data, forKey: Self.storageKey)
        }
        objectWillChange.send()
    }

    // MARK: Week math

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    func weekInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 7 * 86400)
    }

    /// 그 주에 들어 있는 자유시간 구간들. 겹치는 토막은 합치고, 주 경계 밖은 잘라 낸다.
    func intervals(inWeekOf date: Date) -> [DateInterval] {
        let week = weekInterval(containing: date)
        let cal = calendar
        var raw: [DateInterval] = []
        // 지난주 일요일 밤에 시작해 이번 주로 넘어온 토막도 센다
        for offset in -1..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: week.start) else { continue }
            let weekday = (offset + 7) % 7 + 1
            for block in blocks where block.weekday == weekday {
                guard let start = cal.date(byAdding: .minute, value: block.startMinute, to: day),
                      let end = cal.date(byAdding: .minute, value: block.startMinute + block.durationMinutes, to: day)
                else { continue }
                let s = max(start, week.start), e = min(end, week.end)
                if e > s { raw.append(DateInterval(start: s, end: e)) }
            }
        }
        raw.sort { $0.start < $1.start }
        var merged: [DateInterval] = []
        for interval in raw {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    func week(at now: Date = Date()) -> FreeTimeWeek {
        let week = weekInterval(containing: now)
        let list = intervals(inWeekOf: now)
        var total: TimeInterval = 0, elapsed: TimeInterval = 0
        var current: DateInterval?, next: DateInterval?
        for interval in list {
            total += interval.duration
            if interval.end <= now {
                elapsed += interval.duration
            } else if interval.start <= now {
                elapsed += now.timeIntervalSince(interval.start)
                current = interval
            } else if next == nil {
                next = interval
            }
        }
        return FreeTimeWeek(weekStart: week.start, weekEnd: week.end, total: total, elapsed: elapsed,
                            current: current, next: next)
    }

    /// 보통 한 주의 자유시간 (분). 겹치는 토막은 한 번만 센다.
    var weeklyMinutes: Int {
        // 서머타임이 없는 기준 주에서 센다
        Int(intervals(inWeekOf: Self.referenceDate).reduce(0) { $0 + $1.duration } / 60)
    }

    private static let referenceDate: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 1; c.day = 14; c.hour = 12
        return Calendar.current.date(from: c) ?? Date()
    }()
}
