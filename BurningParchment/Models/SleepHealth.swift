// SleepHealth.swift
// 건강 앱의 수면 기록에서 "그 밤에 잠든 시각"만 읽는다. 쓰지 않고, 기기 밖으로 보내지 않는다.

import Foundation
import HealthKit

enum SleepHealth {
    private static let store = HKHealthStore()
    private static let sleepType = HKCategoryType(.sleepAnalysis)
    /// 사용자가 연결을 한 번이라도 눌렀는가. 읽기 권한은 iOS 가 허용 여부를 알려 주지 않아서
    /// (거절해도 "기록 없음"처럼 보인다) 연결을 시도했다는 사실만 기억한다.
    static let connectedKey = "sleepHealthConnected"

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static var isConnected: Bool {
        UserDefaults.standard.bool(forKey: connectedKey)
    }

    @discardableResult
    static func connect() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: [sleepType])
            UserDefaults.standard.set(true, forKey: connectedKey)
            return true
        } catch {
            return false
        }
    }

    /// 그 밤에 잠든 시각. 기록이 없거나 읽을 수 없으면 nil — 그때는 아침에 직접 묻는다.
    static func sleepOnset(in night: DateInterval) async -> Date? {
        guard isAvailable, isConnected else { return nil }
        let window = HKQuery.predicateForSamples(
            withStart: night.start.addingTimeInterval(-3 * 3600),
            end: night.end.addingTimeInterval(3 * 3600),
            options: []
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: window)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        guard let samples = try? await descriptor.result(for: store) else { return nil }

        // 워치가 있으면 실제 수면 단계가, 아이폰만 있으면 "잠자리에 든" 구간만 남는다.
        // 잠든 기록이 있으면 그걸, 없으면 잠자리에 든 시각을 쓴다.
        let asleepValues = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
        let asleep = samples.filter { asleepValues.contains($0.value) }
        let inBed  = samples.filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
        let candidates = asleep.isEmpty ? inBed : asleep

        // 취침 전에 끝난 낮잠은 빼고, 기상 시각보다 한참 뒤에 시작한 잠도 뺀다
        return candidates
            .filter { $0.endDate > night.start && $0.startDate < night.end.addingTimeInterval(3600) }
            .map(\.startDate)
            .min()
    }
}
