// TimeFormat.swift
// 시각 표기를 기기의 언어·지역 설정에 맞춰 만든다.
// 오전/오후 를 "AM"/"PM" 으로 하드코딩하면 한국어 기기에서도 영어가 섞여 나오므로
// 앱·위젯 모두 이 헬퍼를 통해 시각 문자열을 만든다.

import Foundation

enum TimeFormat {
    /// "오전 7:00" (ko) / "7:00 AM" (en) / "07:00" (24시간제 설정)
    static func short(hour: Int, minute: Int) -> String {
        guard let date = date(hour: hour, minute: minute) else {
            return String(format: "%02d:%02d", hour, minute)
        }
        return date.formatted(.dateTime.hour().minute())
    }

    /// 시(hour) 피커 한 칸에 들어갈 라벨. 12시간제 지역에서는 "오전 7" / "AM 7",
    /// 24시간제 지역에서는 "07" 로 나온다.
    static func hourLabel(_ hour: Int) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("j")
        guard f.dateFormat?.contains("a") == true else {
            return String(format: "%02d", hour)
        }
        let h12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        let symbol = hour >= 12 ? (f.pmSymbol ?? "PM") : (f.amSymbol ?? "AM")
        return "\(symbol) \(h12)"
    }

    private static func date(hour: Int, minute: Int) -> Date? {
        Calendar.current.date(from: DateComponents(
            year: 2000, month: 1, day: 1, hour: hour, minute: minute
        ))
    }
}
