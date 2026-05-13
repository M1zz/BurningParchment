// BedtimeManager.swift
// 기상시간~취침시간 기준으로 하루 남은 시간을 관리

import SwiftUI
import Combine
import UserNotifications
import WidgetKit
import ActivityKit

enum PeriodType: String, CaseIterable, Identifiable {
    case day = "1일"
    case week = "1주"
    case month = "1달"
    case year = "1년"
    var id: String { rawValue }
}

class BedtimeManager: ObservableObject {
    // MARK: - Published Properties
    @Published var bedtimeHour: Int {
        didSet { save() }
    }
    @Published var bedtimeMinute: Int {
        didSet { save() }
    }
    @Published var wakeHour: Int {
        didSet { save() }
    }
    @Published var wakeMinute: Int {
        didSet { save() }
    }
    @Published var remainingSeconds: TimeInterval = 0
    @Published var totalSeconds: TimeInterval = 0
    @Published var progress: Double = 0.0
    @Published var isCountdownActive: Bool = false
    @Published var isBeforeWakeTime: Bool = true
    @Published var selectedPeriod: PeriodType = .day
    // 수면 구간 진행률: 0 = 취침 직후, 1 = 기상 직전
    @Published var sleepProgress: Double = 0

    private var timer: Timer?
    private var lastWidgetReload: Date = .distantPast
    private var scheduledNotifBedDate: Date?
    private var currentBedDate: Date = .distantFuture
    private var liveActivity: Activity<BedtimeActivityAttributes>?
    private var lastLiveActivityUpdate: Date = .distantPast

    private let sharedDefaults = UserDefaults(suiteName: "group.com.burningparchment.app")

    // MARK: - UserDefaults Keys
    private let keyBedH = "bedtimeHour"
    private let keyBedM = "bedtimeMinute"
    private let keyWakeH = "wakeHour"
    private let keyWakeM = "wakeMinute"

    // MARK: - Computed Properties
    var bedtimeString: String { formatTime(hour: bedtimeHour, minute: bedtimeMinute) }
    var wakeTimeString: String { formatTime(hour: wakeHour, minute: wakeMinute) }

    var periodProgress: Double {
        switch selectedPeriod {
        case .day: return progress
        case .week: return weekProgress
        case .month: return monthProgress
        case .year: return yearProgress
        }
    }

    var periodRemainingString: String {
        switch selectedPeriod {
        case .day: return remainingTimeString
        case .week: return formatRemainingDays(weekRemainingDays)
        case .month: return formatRemainingDays(monthRemainingDays)
        case .year: return formatRemainingDays(yearRemainingDays)
        }
    }

    var periodLabel: String {
        switch selectedPeriod {
        case .day: return "취침까지 남은 시간"
        case .week: return "이번 주 남은 시간"
        case .month: return "이번 달 남은 시간"
        case .year: return "올해 남은 시간"
        }
    }

    private var todayFraction: Double {
        isCountdownActive ? progress : (progress >= 1.0 ? 1.0 : 0.0)
    }

    private var weekProgress: Double {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date()) // 1=Sun, 2=Mon ... 7=Sat
        let daysFromMonday = Double((weekday - 2 + 7) % 7)
        return min((daysFromMonday + todayFraction) / 7.0, 1.0)
    }

    private var weekRemainingDays: Double {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date())
        let daysFromMonday = Double((weekday - 2 + 7) % 7)
        return max(7.0 - daysFromMonday - todayFraction, 0)
    }

    private var monthProgress: Double {
        let cal = Calendar.current
        let now = Date()
        let dayOfMonth = Double(cal.component(.day, from: now) - 1)
        let daysInMonth = Double(cal.range(of: .day, in: .month, for: now)?.count ?? 30)
        return min((dayOfMonth + todayFraction) / daysInMonth, 1.0)
    }

    private var monthRemainingDays: Double {
        let cal = Calendar.current
        let now = Date()
        let dayOfMonth = Double(cal.component(.day, from: now) - 1)
        let daysInMonth = Double(cal.range(of: .day, in: .month, for: now)?.count ?? 30)
        return max(daysInMonth - dayOfMonth - todayFraction, 0)
    }

    private var yearProgress: Double {
        let cal = Calendar.current
        let now = Date()
        let dayOfYear = Double((cal.ordinality(of: .day, in: .year, for: now) ?? 1) - 1)
        let daysInYear = Double(cal.range(of: .day, in: .year, for: now)?.count ?? 365)
        return min((dayOfYear + todayFraction) / daysInYear, 1.0)
    }

    private var yearRemainingDays: Double {
        let cal = Calendar.current
        let now = Date()
        let dayOfYear = Double((cal.ordinality(of: .day, in: .year, for: now) ?? 1) - 1)
        let daysInYear = Double(cal.range(of: .day, in: .year, for: now)?.count ?? 365)
        return max(daysInYear - dayOfYear - todayFraction, 0)
    }

    private func formatRemainingDays(_ remaining: Double) -> String {
        let days = Int(remaining)
        let hours = Int((remaining - Double(days)) * 24)
        if days > 0 { return "\(days)일 \(hours)시간" }
        return "\(hours)시간"
    }

    var remainingTimeString: String {
        let h = Int(remainingSeconds) / 3600
        let m = (Int(remainingSeconds) % 3600) / 60
        let s = Int(remainingSeconds) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var remainingHours: Int { Int(remainingSeconds) / 3600 }
    var remainingMinutes: Int { (Int(remainingSeconds) % 3600) / 60 }
    var remainingSecs: Int { Int(remainingSeconds) % 60 }

    // MARK: - Init
    init() {
        let ud = UserDefaults.standard
        self.wakeHour = ud.object(forKey: keyWakeH) as? Int ?? 7
        self.wakeMinute = ud.object(forKey: keyWakeM) as? Int ?? 0
        self.bedtimeHour = ud.object(forKey: keyBedH) as? Int ?? 23
        self.bedtimeMinute = ud.object(forKey: keyBedM) as? Int ?? 0

        requestNotificationPermission()
        reconnectLiveActivity()
        startMonitoring()
    }

    // MARK: - Save
    private func save() {
        let ud = UserDefaults.standard
        ud.set(bedtimeHour, forKey: keyBedH)
        ud.set(bedtimeMinute, forKey: keyBedM)
        ud.set(wakeHour, forKey: keyWakeH)
        ud.set(wakeMinute, forKey: keyWakeM)

        scheduledNotifBedDate = nil
        recalculate()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Shared UserDefaults (위젯용)
    private func saveSharedData() {
        guard let sd = sharedDefaults else { return }
        sd.set(progress, forKey: "shared_progress")
        sd.set(remainingSeconds, forKey: "shared_remainingSeconds")
        sd.set(bedtimeHour, forKey: "shared_bedtimeHour")
        sd.set(bedtimeMinute, forKey: "shared_bedtimeMinute")
        sd.set(wakeHour, forKey: "shared_wakeHour")
        sd.set(wakeMinute, forKey: "shared_wakeMinute")
        sd.set(isCountdownActive, forKey: "shared_isCountdownActive")
        sd.set(isBeforeWakeTime, forKey: "shared_isBeforeWakeTime")

        // 1분 간격으로 위젯 타임라인 리로드
        if Date().timeIntervalSince(lastWidgetReload) > 60 {
            lastWidgetReload = Date()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Timer
    func startMonitoring() {
        timer?.invalidate()
        recalculate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recalculate()
        }
    }

    func recalculate() {
        let now = Date()
        let cal = Calendar.current

        var wakeComps = cal.dateComponents([.year, .month, .day], from: now)
        wakeComps.hour = wakeHour
        wakeComps.minute = wakeMinute
        wakeComps.second = 0
        guard let todayWake = cal.date(from: wakeComps) else { return }

        let wakeDate: Date
        let bedDate: Date

        if now >= todayWake {
            wakeDate = todayWake
            var bedComps = cal.dateComponents([.year, .month, .day], from: todayWake)
            bedComps.hour = bedtimeHour
            bedComps.minute = bedtimeMinute
            bedComps.second = 0
            guard var bd = cal.date(from: bedComps) else { return }
            if bd <= wakeDate { bd = cal.date(byAdding: .day, value: 1, to: bd)! }
            bedDate = bd
        } else {
            let yesterdayWake = cal.date(byAdding: .day, value: -1, to: todayWake)!
            var bedComps = cal.dateComponents([.year, .month, .day], from: yesterdayWake)
            bedComps.hour = bedtimeHour
            bedComps.minute = bedtimeMinute
            bedComps.second = 0
            guard var bd = cal.date(from: bedComps) else { return }
            if bd <= yesterdayWake { bd = cal.date(byAdding: .day, value: 1, to: bd)! }

            if now < bd {
                wakeDate = yesterdayWake
                bedDate = bd
            } else {
                // 수면 구간: 어제 취침 ~ 오늘 기상
                isBeforeWakeTime = true
                isCountdownActive = false
                sleepProgress = 0
                progress = 0
                remainingSeconds = todayWake.timeIntervalSince(now)
                totalSeconds = 0
                let totalSleep = todayWake.timeIntervalSince(bd)
                if totalSleep > 0 {
                    sleepProgress = min(max(now.timeIntervalSince(bd) / totalSleep, 0), 1)
                }
                saveSharedData()
                return
            }
        }

        currentBedDate = bedDate
        let total = bedDate.timeIntervalSince(wakeDate)
        let remaining = bedDate.timeIntervalSince(now)

        if remaining <= 0 {
            // 수면 구간: 오늘 취침 ~ 내일 기상
            isCountdownActive = false
            isBeforeWakeTime = false
            progress = 1.0
            remainingSeconds = 0
            totalSeconds = total
            let nextWake = cal.date(byAdding: .day, value: 1, to: wakeDate)!
            let totalSleep = nextWake.timeIntervalSince(bedDate)
            sleepProgress = totalSleep > 0 ? min(max(now.timeIntervalSince(bedDate) / totalSleep, 0), 1) : 0
            endLiveActivity()
        } else {
            isCountdownActive = true
            isBeforeWakeTime = false
            sleepProgress = 0
            remainingSeconds = remaining
            totalSeconds = max(total, 1)
            progress = min(max(1.0 - (remaining / total), 0.0), 1.0)

            if scheduledNotifBedDate != bedDate {
                scheduleNotification(bedDate: bedDate)
                scheduledNotifBedDate = bedDate
            }
            if liveActivity == nil {
                startLiveActivity(bedDate: bedDate)
            } else {
                updateLiveActivity(bedDate: bedDate)
            }
        }

        saveSharedData()
    }

    // MARK: - Helpers
    private func formatTime(hour: Int, minute: Int) -> String {
        let h12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        let ampm = hour >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d %@", h12, minute, ampm)
    }

    // MARK: - Notifications
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func scheduleNotification(bedDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["bedtime-1h"])

        let notifDate = bedDate.addingTimeInterval(-3600)
        guard notifDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "불타는 내인생 🔥"
        content.body = "취침 1시간 전입니다. 오늘 하루도 수고했어요!"
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notifDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "bedtime-1h", content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Live Activity

    private func startLiveActivity(bedDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard liveActivity == nil else { return }

        let attrs = BedtimeActivityAttributes(bedtimeString: bedtimeString)
        let state = BedtimeActivityAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            progress: progress,
            bedtimeDate: bedDate,
            showMiniParchment: true
        )
        do {
            liveActivity = try Activity<BedtimeActivityAttributes>.request(
                attributes: attrs,
                contentState: state,
                pushType: nil
            )
        } catch {}
    }

    private func updateLiveActivity(bedDate: Date) {
        guard let activity = liveActivity else { return }
        guard Date().timeIntervalSince(lastLiveActivityUpdate) >= 30 else { return }
        lastLiveActivityUpdate = Date()

        let state = BedtimeActivityAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            progress: progress,
            bedtimeDate: bedDate,
            showMiniParchment: true
        )
        Task { await activity.update(using: state) }
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        let final = BedtimeActivityAttributes.ContentState(
            remainingSeconds: 0, progress: 1.0,
            bedtimeDate: Date(), showMiniParchment: false
        )
        Task {
            await activity.end(using: final, dismissalPolicy: .after(Date().addingTimeInterval(30)))
        }
        liveActivity = nil
    }

    private func reconnectLiveActivity() {
        liveActivity = Activity<BedtimeActivityAttributes>.activities.first
    }

    deinit { timer?.invalidate() }
}
