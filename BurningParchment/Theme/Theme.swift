// Theme.swift
// 라이트/다크 두 벌의 색을 한 곳에 모아 둔다.
//
// 색은 전부 UIKit 의 동적 UIColor 로 만든다. 그래서 호출부는 colorScheme 을
// 읽지 않아도 되고, Canvas·Shape·Gradient 처럼 Environment 가 닿지 않는
// 곳에서도 같은 이름을 그대로 쓸 수 있다.
//
// ⚠️ 여기 있는 것은 "UI 크롬"의 색이다 — 배경·글자·면·강조.
//    불꽃·재·그을음·양피지처럼 **실제 물질의 색**은 라이트에서도 그대로여야
//    하므로 토큰으로 바꾸지 말 것. 촛불은 낮에도 주황색이다.

import SwiftUI

// MARK: - 사용자가 고르는 테마

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return String(localized: "시스템 설정")
        case .light:  return String(localized: "라이트")
        case .dark:   return String(localized: "다크")
        }
    }

    var icon: String {
        switch self {
        case .system: return "iphone"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    /// nil 이면 시스템 설정을 따른다.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    static let storageKey = "appTheme"
}

// MARK: - 팔레트

private func dynamic(light: UIColor, dark: UIColor) -> Color {
    Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
}

private func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> UIColor {
    UIColor(red: r, green: g, blue: b, alpha: a)
}

extension Color {

    // MARK: 배경
    //
    // 다크 값은 지금 화면에 쓰이던 색을 그대로 옮겨 온 것이다 (다크 모드는 한 픽셀도
    // 변하지 않아야 한다). 라이트는 볕에 둔 양피지 — 흰색이 아니라 따뜻한 미색이다.

    /// 메인 화면 바닥. 다크는 순수한 검정이었다.
    static let appBackground = dynamic(
        light: rgb(0.968, 0.945, 0.902),
        dark:  rgb(0, 0, 0)
    )

    /// 시트·설정처럼 살짝 온기가 도는 바닥.
    static let appBackgroundWarm = dynamic(
        light: rgb(0.949, 0.921, 0.871),
        dark:  rgb(0.08, 0.06, 0.04)
    )

    // MARK: 글자·면
    //
    // `ink` 는 예전의 `.white` 자리다. 글자로도 쓰고, 낮은 불투명도로 카드 면으로도
    // 쓰인다. 다크에서 흰색이 두 역할을 겸하던 것과 같은 방식이다.

    static let ink = dynamic(
        light: rgb(0.145, 0.114, 0.078),
        dark:  rgb(1, 1, 1)
    )

    /// 예전의 `.gray` 자리 — 보조 글자.
    ///
    /// 라이트 값이 회색이 아니라 짙은 갈색인 이유: 호출부가 대부분
    /// `.opacity(0.4)~(0.6)` 으로 흐려 쓴다. 미색 바탕에 중간 회색을 40% 로 얹으면
    /// 거의 사라지므로, 흐려진 뒤에도 읽히도록 바탕에서 충분히 먼 색을 바닥값으로 둔다.
    static let inkMuted = dynamic(
        light: rgb(0.243, 0.196, 0.137),
        dark:  UIColor.systemGray
    )

    // MARK: 강조 (불씨)

    /// 예전의 `.orange` 자리. 다크에서는 SwiftUI 의 orange 를 그대로 되돌려 주므로
    /// 기존 화면과 완전히 같다. 라이트에서는 미색 위에서 읽히도록 태운 주황으로 낮춘다.
    static let ember = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(Color.orange).resolvedColor(with: t)
            : rgb(0.678, 0.302, 0.075)
    })

    /// 경고·만료처럼 붉은 강조. (불꽃 그라디언트의 빨강과는 다른 용도다)
    static let emberDeep = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(Color.red).resolvedColor(with: t)
            : rgb(0.604, 0.169, 0.078)
    })

    /// 배경에 깔리는 은은한 불빛. 라이트에서는 알파를 크게 낮춰 둔다 —
    /// 미색 바탕에 주황을 진하게 얹으면 화면이 탁해진다. 호출부의
    /// `.opacity(...)` 와 곱해지므로 값을 따로 고치지 않아도 된다.
    static let emberGlow = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(Color.orange).resolvedColor(with: t)
            : rgb(0.851, 0.514, 0.180, 0.40)
    })

    /// 배경 불빛의 붉은 쪽.
    static let emberGlowDeep = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(Color.red).resolvedColor(with: t)
            : rgb(0.769, 0.310, 0.145, 0.34)
    })

    /// 강조색 위에 얹는 글자 (선택된 캡슐 안의 글자 등).
    /// 다크에서는 검정이었고, 라이트에서도 태운 주황 위라면 여전히 밝은 쪽이 낫다.
    static let onEmber = dynamic(
        light: rgb(0.988, 0.973, 0.945),
        dark:  rgb(0, 0, 0)
    )

    /// 저장 완료 같은 긍정 신호. 미색 바탕에서는 밝은 초록이 거의 안 보이므로
    /// 라이트 쪽을 훨씬 짙게 잡는다.
    static let successInk = dynamic(
        light: rgb(0.106, 0.451, 0.216),
        dark:  rgb(0.30, 0.78, 0.42)
    )

    /// 떠 있는 요소의 그림자. 라이트에서는 훨씬 옅어야 한다.
    static let appShadow = dynamic(
        light: rgb(0.35, 0.27, 0.18, 0.30),
        dark:  rgb(0, 0, 0, 1)
    )
}

// MARK: - 불꽃 합성 모드

/// 불꽃·불씨 레이어의 합성 모드.
///
/// 어두운 바탕에서 `.screen` 은 불빛이 번지는 느낌을 아주 싸게 만들어 준다.
/// 그런데 screen 은 밝은 쪽으로만 밀기 때문에 미색 바탕에서는 결과가 거의 흰색으로
/// 날아가 버린다 — 라이트 모드에서 불꽃이 통째로 사라졌던 이유다.
/// 그래서 라이트에서는 그냥 겹쳐 그린다 (미색 위의 주황은 그 자체로 잘 보인다).
private struct FireBlend: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.blendMode(colorScheme == .dark ? .screen : .normal)
    }
}

extension View {
    func fireBlend() -> some View { modifier(FireBlend()) }
}
