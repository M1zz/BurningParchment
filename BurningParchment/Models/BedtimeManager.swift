// BedtimeManager.swift
// 기상시간~취침시간 기준으로 하루 남은 시간을 관리

import SwiftUI
import Combine
import ActivityKit
import UserNotifications
import WidgetKit

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
    @Published var showParchmentInWidget: Bool = true {
        didSet {
            UserDefaults.standard.set(showParchmentInWidget, forKey: keyParchmentInWidget)
            if liveActivityRunning {
                if #available(iOS 16.2, *) { updateLiveActivityState() }
            }
        }
    }

    private var timer: Timer?
    private var liveActivityRunning = false
    private var lastLAUpdate: Date = .distantPast
    private var lastWidgetReload: Date = .distantPast
    private var scheduledNotifBedDate: Date?
    private var currentBedDate: Date = .distantFuture

    private let sharedDefaults = UserDefaults(suiteName: "group.com.burningparchment.app")

    // MARK: - UserDefaults Keys
    private let keyBedH = "bedtimeHour"
    private let keyBedM = "bedtimeMinute"
    private let keyWakeH = "wakeHour"
    private let keyWakeM = "wakeMinute"
    private let keyParchmentInWidget = "parchmentInWidget"

    // MARK: - Computed Properties
    var bedtimeString: String { formatTime(hour: bedtimeHour, minute: bedtimeMinute) }
    var wakeTimeString: String { formatTime(hour: wakeHour, minute: wakeMinute) }

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
        self.showParchmentInWidget = ud.object(forKey: keyParchmentInWidget) as? Bool ?? true

        requestNotificationPermission()
        startMonitoring()
    }

    // MARK: - Save
    private func save() {
        let ud = UserDefaults.standard
        ud.set(bedtimeHour, forKey: keyBedH)
        ud.set(bedtimeMinute, forKey: keyBedM)
        ud.set(wakeHour, forKey: keyWakeH)
        ud.set(wakeMinute, forKey: keyWakeM)

        // 설정 변경 시 알림 & LA 재설정
        scheduledNotifBedDate = nil
        if liveActivityRunning {
            if #available(iOS 16.2, *) { endAllLiveActivities() }
            liveActivityRunning = false
        }
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
                isBeforeWakeTime = true
                isCountdownActive = false
                progress = 0
                remainingSeconds = todayWake.timeIntervalSince(now)
                totalSeconds = 0
                saveSharedData()
                return
            }
        }

        currentBedDate = bedDate
        let total = bedDate.timeIntervalSince(wakeDate)
        let remaining = bedDate.timeIntervalSince(now)

        if remaining <= 0 {
            isCountdownActive = false
            isBeforeWakeTime = false
            progress = 1.0
            remainingSeconds = 0
            totalSeconds = total

            if liveActivityRunning {
                if #available(iOS 16.2, *) { endAllLiveActivities() }
                liveActivityRunning = false
            }
        } else {
            isCountdownActive = true
            isBeforeWakeTime = false
            remainingSeconds = remaining
            totalSeconds = max(total, 1)
            progress = min(max(1.0 - (remaining / total), 0.0), 1.0)

            // Live Activity 자동 시작 & 업데이트
            if #available(iOS 16.2, *) {
                if !liveActivityRunning {
                    autoStartLiveActivity()
                } else if Date().timeIntervalSince(lastLAUpdate) > 60 {
                    updateLiveActivityState()
                }
            }

            // 1시간 전 알림 예약
            if scheduledNotifBedDate != bedDate {
                scheduleNotification(bedDate: bedDate)
                scheduledNotifBedDate = bedDate
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
    @available(iOS 16.2, *)
    private func autoStartLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard Activity<BedtimeActivityAttributes>.activities.isEmpty else {
            liveActivityRunning = true
            return
        }

        let attributes = BedtimeActivityAttributes(bedtimeString: bedtimeString)
        let state = BedtimeActivityAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            progress: progress,
            bedtimeDate: currentBedDate,
            showMiniParchment: showParchmentInWidget
        )
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            _ = try Activity<BedtimeActivityAttributes>.request(
                attributes: attributes, content: content, pushType: nil
            )
            liveActivityRunning = true
            lastLAUpdate = Date()
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    @available(iOS 16.2, *)
    private func updateLiveActivityState() {
        let state = BedtimeActivityAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            progress: progress,
            bedtimeDate: currentBedDate,
            showMiniParchment: showParchmentInWidget
        )
        let content = ActivityContent(state: state, staleDate: nil)
        lastLAUpdate = Date()

        Task {
            for activity in Activity<BedtimeActivityAttributes>.activities {
                await activity.update(content)
            }
        }
    }

    @available(iOS 16.2, *)
    private func endAllLiveActivities() {
        let state = BedtimeActivityAttributes.ContentState(
            remainingSeconds: 0, progress: 1.0, bedtimeDate: currentBedDate,
            showMiniParchment: showParchmentInWidget
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            for activity in Activity<BedtimeActivityAttributes>.activities {
                await activity.end(content, dismissalPolicy: .immediate)
            }
        }
    }

    @available(iOS 16.2, *)
    func startLiveActivity() {
        autoStartLiveActivity()
    }

    deinit { timer?.invalidate() }
}
