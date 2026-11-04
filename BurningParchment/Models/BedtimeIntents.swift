//
//  BedtimeIntents.swift
//  BurningParchment
//
//  "불타는 내인생, 몇 시간 남았어?" — 잠들 시각까지 남은 시간을 말로 알려 준다.
//  설정은 앱과 위젯이 쓰는 App Group 에서 읽는다(BedtimeManager.init 과 같은 자리).
//
//  데드라인은 Siri · Spotlight 가 알아보게 색인한다(iOS 18+). 누르면 그 데드라인이 열린다.
//

import AppIntents
import CoreSpotlight
import Foundation

struct TimeUntilBedtimeIntent: AppIntent {
    static let title = LocalizedStringResource("잠들 시각까지", comment: "Siri: how much time is left until bedtime")
    static let description = IntentDescription(
        LocalizedStringResource("오늘 잠들 시각까지 남은 시간을 알려 줍니다.", comment: "Siri: time until bedtime description")
    )

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let group = UserDefaults(suiteName: "group.com.burningparchment.app")
        let standard = UserDefaults.standard
        let hour = group?.object(forKey: "bedtimeHour") as? Int ?? standard.object(forKey: "bedtimeHour") as? Int ?? 23
        let minute = group?.object(forKey: "bedtimeMinute") as? Int ?? standard.object(forKey: "bedtimeMinute") as? Int ?? 0

        let now = Date()
        let calendar = Calendar.current
        guard var bedtime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else {
            return .result(dialog: "")
        }
        // 자정을 넘겨 자는 사람(취침 0~5시)은 다음 날 새벽이 오늘 밤의 잠들 시각이다.
        if hour < 6, bedtime < now, now.timeIntervalSince(bedtime) > 6 * 3600 {
            bedtime = calendar.date(byAdding: .day, value: 1, to: bedtime) ?? bedtime
        }
        let time = bedtime.formatted(date: .omitted, time: .shortened)
        guard bedtime > now else {
            return .result(dialog: IntentDialog(LocalizedStringResource("잠들 시각(\(time))이 지났어요. 이제 불을 꺼요.", comment: "Siri: bedtime has passed. Argument is the bedtime")))
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute]
        let left = formatter.string(from: bedtime.timeIntervalSince(now)) ?? ""
        return .result(dialog: IntentDialog(LocalizedStringResource("잠들 시각(\(time))까지 \(left) 남았어요.", comment: "Siri: time left until bedtime. Arguments: bedtime, time left")))
    }
}

// MARK: - 데드라인

/// 열어 달라는 데드라인. ContentView 가 데드라인 목록을 열고, 목록이 그 데드라인을 띄운 뒤 비운다.
@MainActor @Observable
final class DeadlineRouter {
    static let shared = DeadlineRouter()
    var deadlineID: UUID?
}

struct DeadlineEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("데드라인", comment: "Siri/Spotlight: a deadline the user counts down to")
    )
    static let defaultQuery = DeadlineQuery()

    let id: UUID
    let title: String
    let emoji: String
    let targetDate: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(emoji) \(title)", subtitle: "\(targetDate)")
    }

    init(_ deadline: Deadline) {
        id = deadline.id
        title = deadline.title
        emoji = deadline.emoji
        targetDate = deadline.targetDateString
    }

    /// 앱과 위젯이 함께 쓰는 App Group 에서 바로 읽는다(DeadlineManager.load 와 같은 자리). 가까운 마감부터.
    static func all() -> [DeadlineEntity] {
        guard let data = UserDefaults(suiteName: "group.com.burningparchment.app")?.data(forKey: "shared_deadlines"),
              let deadlines = try? JSONDecoder().decode([Deadline].self, from: data) else { return [] }
        return deadlines.sorted { $0.targetDate < $1.targetDate }.map(DeadlineEntity.init)
    }

    /// Spotlight 에 싣는 데드라인을 지금 것에 맞춘다. 앱을 열 때와 뒤로 보낼 때 부른다.
    static func reindex() async {
        guard #available(iOS 18.0, *) else { return }
        let index = CSSearchableIndex.default()
        try? await index.deleteAppEntities(ofType: DeadlineEntity.self)
        try? await index.indexAppEntities(all())
    }
}

@available(iOS 18.0, *)
extension DeadlineEntity: IndexedEntity {
    var attributeSet: CSSearchableItemAttributeSet {
        let set = defaultAttributeSet
        set.textContent = title
        return set
    }
}

struct DeadlineQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [DeadlineEntity] {
        let wanted = Set(identifiers)
        return DeadlineEntity.all().filter { wanted.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [DeadlineEntity] {
        DeadlineEntity.all().filter { $0.title.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [DeadlineEntity] {
        DeadlineEntity.all()
    }
}

/// 데드라인을 연다. Spotlight · Siri 결과를 누르면 여기로 온다.
struct OpenDeadlineIntent: OpenIntent {
    static let title = LocalizedStringResource("데드라인 열기", comment: "Siri/Spotlight: open a deadline")
    static let description = IntentDescription(
        LocalizedStringResource("데드라인을 열어 마감까지 남은 시간을 봅니다.", comment: "Siri: open deadline description")
    )

    @Parameter(title: LocalizedStringResource("데드라인", comment: "Siri: deadline parameter"),
               description: LocalizedStringResource("열어 볼 데드라인", comment: "Siri: deadline parameter description"))
    var target: DeadlineEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        DeadlineRouter.shared.deadlineID = target.id
        return .result()
    }
}

// MARK: - Siri 문구

struct BurningParchmentShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TimeUntilBedtimeIntent(),
            phrases: [
                "How much time is left in \(.applicationName)",
                "\(.applicationName) time left"
            ],
            shortTitle: "Time Until Bedtime",
            systemImageName: "flame"
        )
    }
}
