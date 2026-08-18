// BedtimeActivityAttributes.swift
// 다이나믹 아일랜드 & Live Activity 속성 정의

import ActivityKit
import Foundation

struct BedtimeActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var remainingSeconds: TimeInterval
        var progress: Double
        var bedtimeDate: Date
        var showMiniParchment: Bool

        var remainingTimeString: String {
            let hours = Int(remainingSeconds) / 3600
            let minutes = (Int(remainingSeconds) % 3600) / 60
            let seconds = Int(remainingSeconds) % 60
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }

        var shortTimeString: String {
            let hours = Int(remainingSeconds) / 3600
            let minutes = (Int(remainingSeconds) % 3600) / 60
            if hours > 0 {
                return String(localized: "\(hours)시간 \(minutes)분")
            }
            return String(localized: "\(minutes)분")
        }
    }

    var bedtimeString: String
}
