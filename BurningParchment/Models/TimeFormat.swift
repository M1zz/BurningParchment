// TimeFormat.swift
// 시각 표기를 기기의 언어·지역 설정에 맞춰 만든다.
// 오전/오후 를 "AM"/"PM" 으로 하드코딩하면 한국어 기기에서도 영어가 섞여 나오므로
// 앱·위젯 모두 이 헬퍼를 통해 시각 문자열을 만든다.

import Foundation
import SwiftUI

enum TimeFormat {
    private static let formatters = NSCache<NSString, DateFormatter>()

    /// 템플릿에 맞춘 포맷터. 만드는 값이 비싸서 재사용한다 — 받은 쪽에서 속성을 바꾸지 말 것.
    /// 언어·지역·시간대가 바뀌면 키가 달라져 새로 만든다.
    static func formatter(_ template: String) -> DateFormatter {
        let key = "\(template)|\(Locale.current.identifier)|\(TimeZone.current.identifier)" as NSString
        if let cached = formatters.object(forKey: key) { return cached }
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate(template)
        formatters.setObject(f, forKey: key)
        return f
    }

    /// "오전 7:00" (ko) / "7:00 AM" (en) / "07:00" (24시간제 설정)
    static func short(hour: Int, minute: Int) -> String {
        guard let date = date(hour: hour, minute: minute) else {
            return "\(twoDigits(hour)):\(twoDigits(minute))"
        }
        return date.formatted(.dateTime.hour().minute())
    }

    /// 특정 시각을 같은 형식으로
    static func short(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    /// 시(hour) 피커 한 칸에 들어갈 라벨. 12시간제 지역에서는 "오전 7" / "AM 7",
    /// 24시간제 지역에서는 "07" 로 나온다.
    static func hourLabel(_ hour: Int) -> String {
        let f = formatter("j")
        guard f.dateFormat?.contains("a") == true else {
            return twoDigits(hour)
        }
        let h12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        let symbol = hour >= 12 ? (f.pmSymbol ?? "PM") : (f.amSymbol ?? "AM")
        return "\(symbol) \(h12.formatted())"
    }

    /// "07" 처럼 두 자리로 채운 숫자. `String(format:)` 은 언제나 0~9 를 쓰므로, 아랍어 기기에서
    /// 같은 화면의 다른 숫자(٠٧)와 섞이지 않게 기기의 숫자 체계로 쓴다.
    static func twoDigits(_ n: Int) -> String {
        n.formatted(.number.precision(.integerLength(2...)).grouping(.never))
    }

    private static func date(hour: Int, minute: Int) -> Date? {
        Calendar.current.date(from: DateComponents(
            year: 2000, month: 1, day: 1, hour: hour, minute: minute
        ))
    }
}

extension LayoutDirection {
    /// 화면에 실제로 쓰인 앱 언어의 글 방향. ImageRenderer 처럼 화면 밖에서 그리는 곳은
    /// 환경을 물려받지 못해 언제나 왼쪽에서 오른쪽이 된다 — 그런 곳에 직접 넘긴다.
    static var ofAppLanguage: LayoutDirection {
        let shown = Bundle.main.preferredLocalizations.first ?? "en"
        return Locale.Language(identifier: shown).characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }
}

extension TimeFormat {
    /// 두 값을 잇는 " · ". 아랍어 숫자(٠)가 가운뎃점과 같은 모양이라 "١٤٤٨ هـ · ٩" 가 "٠" 로 읽힌다.
    /// 오른쪽에서 왼쪽으로 쓰는 언어에서는 쉼표로 잇는다.
    static var separator: String { LayoutDirection.ofAppLanguage == .rightToLeft ? "، " : " · " }
}

extension Font.Design {
    /// 숫자 · 남은 시간 칸의 글꼴. 고정폭(SF Mono)에는 아랍 글자가 없어 "ذرتا رماد" 같은 글이
    /// 낱자로 떨어져 나온다. 오른쪽에서 왼쪽으로 쓰는 언어에서는 기본 글꼴을 쓴다.
    static var digits: Font.Design { LayoutDirection.ofAppLanguage == .rightToLeft ? .default : .monospaced }
}
