// ParchmentStyle.swift
// 양피지·불꽃 테마 (프로).
//
// 불꽃은 셰이더·Canvas·그라디언트 여러 곳에서 주황 계열로 그려진다. 그 색을 하나하나
// 테마별로 나누는 대신, 불꽃 레이어 전체에 색상 회전(hueRotation)을 건다 — 밝기와
// 그라디언트의 결은 그대로 두고 색만 옮겨 가므로 기본 불꽃의 질감이 모든 테마에 남는다.
// 양피지는 회전하면 탁해지므로 테마마다 종이 색을 따로 둔다.
//
// 무료는 기본(classic)만. 프로가 아니게 되면(환불 등) 고른 값은 남겨 두고 기본으로 그린다.

import SwiftUI

enum ParchmentStyle: String, CaseIterable, Identifiable {
    case classic    // 불타는 양피지 — 주황 불꽃, 볕에 그을린 양피지
    case moonlit    // 달빛 한지 — 푸른 불꽃, 서늘한 한지
    case celadon    // 청자 — 비취빛 불꽃, 옅은 청자색 종이
    case dusk       // 노을 — 자줏빛 불꽃, 장밋빛 종이

    var id: String { rawValue }

    static let storageKey = "parchmentStyle"

    var label: String {
        switch self {
        case .classic: return String(localized: "불타는 양피지")
        case .moonlit: return String(localized: "달빛 한지")
        case .celadon: return String(localized: "청자")
        case .dusk:    return String(localized: "노을")
        }
    }

    var isPro: Bool { self != .classic }

    /// 불꽃·불씨 레이어에 거는 색상 회전.  기본 불꽃은 주황(약 30°)이다.
    var flameHue: Angle {
        switch self {
        case .classic: return .degrees(0)
        case .moonlit: return .degrees(190)
        case .celadon: return .degrees(105)
        case .dusk:    return .degrees(-60)
        }
    }

    /// 종이 색 — 왼쪽 위(밝음)에서 오른쪽 아래(짙음)로.
    var paperColors: [Color] {
        switch self {
        case .classic:
            return [Color(red: 0.86, green: 0.78, blue: 0.62), Color(red: 0.80, green: 0.70, blue: 0.54),
                    Color(red: 0.73, green: 0.62, blue: 0.46), Color(red: 0.66, green: 0.54, blue: 0.39)]
        case .moonlit:
            return [Color(red: 0.88, green: 0.88, blue: 0.85), Color(red: 0.80, green: 0.81, blue: 0.79),
                    Color(red: 0.71, green: 0.73, blue: 0.72), Color(red: 0.62, green: 0.64, blue: 0.65)]
        case .celadon:
            return [Color(red: 0.82, green: 0.87, blue: 0.80), Color(red: 0.74, green: 0.81, blue: 0.73),
                    Color(red: 0.65, green: 0.73, blue: 0.65), Color(red: 0.56, green: 0.65, blue: 0.57)]
        case .dusk:
            return [Color(red: 0.90, green: 0.80, blue: 0.76), Color(red: 0.84, green: 0.72, blue: 0.68),
                    Color(red: 0.76, green: 0.62, blue: 0.60), Color(red: 0.67, green: 0.52, blue: 0.52)]
        }
    }

    var paperGradient: LinearGradient {
        LinearGradient(colors: paperColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// 고른 값과 프로 여부로 실제로 그릴 테마를 정한다.
    static func effective(raw: String, isPro: Bool) -> ParchmentStyle {
        let chosen = ParchmentStyle(rawValue: raw) ?? .classic
        return (chosen.isPro && !isPro) ? .classic : chosen
    }
}

// MARK: - Environment

private struct ParchmentStyleKey: EnvironmentKey {
    static let defaultValue: ParchmentStyle = .classic
}

extension EnvironmentValues {
    /// 지금 그릴 양피지·불꽃 테마. 최상위(ContentView)에서 프로 여부를 반영해 넣는다.
    var parchmentStyle: ParchmentStyle {
        get { self[ParchmentStyleKey.self] }
        set { self[ParchmentStyleKey.self] = newValue }
    }
}

extension View {
    /// 불꽃·불씨 레이어에 테마 색을 입힌다.
    func flameTint(_ style: ParchmentStyle) -> some View {
        hueRotation(style.flameHue)
    }
}
