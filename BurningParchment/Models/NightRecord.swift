// NightRecord.swift
// 취침 이후 타기 시작하는 "내일의 양피지" — 하룻밤의 기록과 아침의 확정.
//
// 앱은 사용자가 자고 있는지 모른다. 그래서 밤사이 타는 모습은 보여주기만 하고,
// 그을음은 아침에 확인된 만큼만 남긴다. 확인할 수 있는 길은 둘뿐이다.
//   1. 건강 앱 수면 기록 — 잠든 시각으로 불을 되돌린다
//   2. 아침에 사용자가 직접 알려 준 잠든 시각
// 어느 쪽도 없으면(답하지 않았거나, 앱을 열지 않았거나) 그을음은 0 이다.
// 앱을 열심히 쓰지 않는 사람이 모르는 사이에 벌을 받는 일은 없어야 한다.

import Foundation

struct NightRecord: Codable, Identifiable, Hashable {
    let id: UUID
    /// 이 밤의 취침 시각 — 밤을 가리는 키
    let bedtimeDate: Date
    /// 이 밤의 기상 시각 (설정 기준)
    let wakeDate: Date

    /// 취침 이후 앱을 열어 두었던 마지막 순간. 아침 질문의 기본값을 채우는 데만 쓴다 —
    /// 새벽에 잠깐 깨서 연 것일 수도 있으니 이것만으로 그을리지 않는다.
    var lastAwakeAt: Date?
    /// 취침 이후 후 불어 끈 순간. 이것도 아침 질문의 기본값일 뿐이다.
    var extinguishedAt: Date?
    /// 건강 앱이 알려 준 잠든 시각
    var sleepOnset: Date?
    /// 아침에 사용자가 알려 준 잠든 시각
    var reportedSleepAt: Date?

    var outcome: Outcome?
    /// 확정된 그을음 — 취침 시각을 넘겨 깨어 있던 시간
    var charredSeconds: TimeInterval
    var resolvedAt: Date?

    enum Outcome: String, Codable {
        /// 취침 전에 스스로 불을 껐다
        case keptBedtime
        /// 건강 앱 수면 기록으로 확인했다
        case health
        /// 아침에 직접 알려 주었다
        case reported
        /// 아무 확인도 없었다 — 그을음 없이 넘어간다
        case unanswered
    }

    /// 이 정도 늦은 건 제시간으로 친다
    static let graceSeconds: TimeInterval = 600

    init(bedtimeDate: Date, wakeDate: Date) {
        self.id = UUID()
        self.bedtimeDate = bedtimeDate
        self.wakeDate = wakeDate
        self.charredSeconds = 0
    }

    var isResolved: Bool { outcome != nil }

    var nightLength: TimeInterval { max(wakeDate.timeIntervalSince(bedtimeDate), 1) }

    /// 내일의 양피지가 그을린 비율 (0~1). 밤 전체를 깨어 있으면 한 장이 다 탄다.
    var charredFraction: Double { min(max(charredSeconds / nightLength, 0), 1) }

    /// 잠든 시각을 그을음으로 바꾼다. 유예 시간 안이면 0.
    func lateSeconds(sleptAt: Date) -> TimeInterval {
        let late = sleptAt.timeIntervalSince(bedtimeDate)
        guard late > Self.graceSeconds else { return 0 }
        return min(late, nightLength)
    }

    /// 밤사이 화면에 보이는 타는 정도 — 불을 껐으면 그 자리에서 멈춘다
    func liveBurnProgress(now: Date) -> Double {
        let end = min(extinguishedAt ?? now, now)
        return min(max(end.timeIntervalSince(bedtimeDate) / nightLength, 0), 1)
    }

    /// 아침 질문에 미리 채워 둘 "잠든 것 같은 시각" — 마지막으로 깨어 있던 흔적
    var suggestedSleepAt: Date? {
        [lastAwakeAt, extinguishedAt].compactMap { $0 }.max()
    }

    /// 새벽 1시 취침이면 달력으로는 다음 날이지만 "그날 밤"은 전날이다
    var nightDate: Date {
        Calendar.current.startOfDay(for: bedtimeDate.addingTimeInterval(-12 * 3600))
    }
}

// MARK: - Manager

final class NightManager: ObservableObject {
    @Published private(set) var records: [NightRecord] = []

    private let key = "night_records"
    private let sd  = UserDefaults(suiteName: "group.com.burningparchment.app")
    /// 오래된 밤은 들고 있을 이유가 없다
    private static let keepCount = 60

    init() { load() }

    // MARK: - Queries

    func record(forBedtime bedDate: Date) -> NightRecord? {
        records.first { abs($0.bedtimeDate.timeIntervalSince(bedDate)) < 1 }
    }

    /// 아침 확인을 기다리는 밤인가
    func isPending(_ night: DateInterval) -> Bool {
        record(forBedtime: night.start)?.isResolved != true
    }

    // MARK: - 밤사이 기록

    /// 취침 이후 앱이 켜져 있다 — 아침 질문의 기본값으로만 쓴다
    func noteAwake(in night: DateInterval, at date: Date = Date()) {
        guard night.contains(date) else { return }
        update(night) { rec in
            guard !rec.isResolved else { return }
            if (rec.lastAwakeAt ?? .distantPast) < date { rec.lastAwakeAt = date }
        }
    }

    /// 취침 이후 후 불어 불을 껐다 — 내일의 양피지가 그 자리에서 멈춘다
    func markExtinguished(in night: DateInterval, at date: Date = Date()) {
        update(night) { rec in
            guard !rec.isResolved, rec.extinguishedAt == nil else { return }
            rec.extinguishedAt = date
        }
    }

    // MARK: - 아침의 확정

    @discardableResult
    func resolve(_ night: DateInterval, outcome: NightRecord.Outcome,
                 sleptAt: Date? = nil, healthOnset: Date? = nil) -> NightRecord {
        update(night) { rec in
            rec.outcome = outcome
            rec.resolvedAt = Date()
            rec.sleepOnset = healthOnset ?? rec.sleepOnset
            switch outcome {
            case .keptBedtime, .unanswered:
                rec.charredSeconds = 0
            case .health:
                rec.charredSeconds = healthOnset.map(rec.lateSeconds(sleptAt:)) ?? 0
            case .reported:
                rec.reportedSleepAt = sleptAt
                rec.charredSeconds = sleptAt.map(rec.lateSeconds(sleptAt:)) ?? 0
            }
        }
        return record(forBedtime: night.start)!
    }

    /// 확인받지 못한 채 지나간 밤들은 그을음 없이 닫는다.
    /// 새 밤이 시작됐거나 더 최근의 밤을 확인하는 중이라면 그 이전의 밤은 더 묻지 않는다.
    func closeUnanswered(before date: Date) {
        var changed = false
        for i in records.indices where !records[i].isResolved && records[i].bedtimeDate < date {
            records[i].outcome = .unanswered
            records[i].charredSeconds = 0
            records[i].resolvedAt = Date()
            changed = true
        }
        if changed { save() }
    }

    // MARK: - Private

    private func update(_ night: DateInterval, _ body: (inout NightRecord) -> Void) {
        if let i = records.firstIndex(where: { abs($0.bedtimeDate.timeIntervalSince(night.start)) < 1 }) {
            body(&records[i])
        } else {
            var rec = NightRecord(bedtimeDate: night.start, wakeDate: night.end)
            body(&rec)
            records.insert(rec, at: 0)
            records.sort { $0.bedtimeDate > $1.bedtimeDate }
            if records.count > Self.keepCount { records.removeLast(records.count - Self.keepCount) }
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        sd?.set(data, forKey: key)
    }

    private func load() {
        guard let data = sd?.data(forKey: key),
              let decoded = try? JSONDecoder().decode([NightRecord].self, from: data)
        else { return }
        records = decoded.sorted { $0.bedtimeDate > $1.bedtimeDate }
    }
}
