// FlameKind.swift
// 불꽃의 종류 (프로).
//
// 양피지·불꽃 테마(ParchmentStyle)가 불꽃의 "빛깔"을 정한다면, 이건 불꽃의 "결"을 정한다.
// 두 설정은 따로 고른다 — 달빛 한지에 들불, 노을에 불티처럼 섞어 쓸 수 있다.
// 그리는 쪽은 FlameView 한 곳이다. 빛깔은 그 위에 flameTint 로 그대로 얹힌다.
//
// 무료는 촛불(classic)만. 프로가 아니게 되면 고른 값은 남겨 두고 촛불로 그린다.

import SwiftUI

enum FlameKind: String, CaseIterable, Identifiable {
    case classic    // 촛불 — 고요하게 일렁이는 기본 불꽃
    case blaze      // 들불 — 거세게 넘실대는 불길과 솟는 불씨
    case smolder    // 숯불 — 낮게 붉게 스미며 숨 쉬는 불
    case sparkler   // 불티 — 하얗게 달아오른 선에서 튀는 불꽃놀이

    var id: String { rawValue }

    static let storageKey = "flameKind"

    var label: String {
        switch self {
        case .classic:  return String(localized: "촛불")
        case .blaze:    return String(localized: "들불")
        case .smolder:  return String(localized: "숯불")
        case .sparkler: return String(localized: "불티")
        }
    }

    /// 카드 아래 작은 글씨
    var tagline: String {
        switch self {
        case .classic:  return String(localized: "고요하게 일렁여요")
        case .blaze:    return String(localized: "거세게 넘실대요")
        case .smolder:  return String(localized: "낮게 숨 쉬어요")
        case .sparkler: return String(localized: "톡톡 튀어 올라요")
        }
    }

    var icon: String {
        switch self {
        case .classic:  return "flame"
        case .blaze:    return "flame.fill"
        case .smolder:  return "fireplace"
        case .sparkler: return "sparkles"
        }
    }

    var isPro: Bool { self != .classic }

    /// 고른 값과 프로 여부로 실제로 그릴 불꽃을 정한다.
    static func effective(raw: String, isPro: Bool) -> FlameKind {
        let chosen = FlameKind(rawValue: raw) ?? .classic
        return (chosen.isPro && !isPro) ? .classic : chosen
    }
}

// MARK: - Environment

private struct FlameKindKey: EnvironmentKey {
    static let defaultValue: FlameKind = .classic
}

extension EnvironmentValues {
    /// 지금 그릴 불꽃의 종류. 최상위(BurningParchmentApp)에서 프로 여부를 반영해 넣는다.
    var flameKind: FlameKind {
        get { self[FlameKindKey.self] }
        set { self[FlameKindKey.self] = newValue }
    }
}
