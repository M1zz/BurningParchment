//
//  BedtimeIntents.swift
//  BurningParchment
//
//  "불타는 내인생, 몇 시간 남았어?" — 잠들 시각까지 남은 시간을 말로 알려 준다.
//  설정은 앱과 위젯이 쓰는 App Group 에서 읽는다(BedtimeManager.init 과 같은 자리).
//

import AppIntents
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
