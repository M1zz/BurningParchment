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

// MARK: - 불꽃 크기 (무료)
// 불꽃이 솟는 높이만 바꾼다. 기본은 작게 — 양피지를 가리지 않는 정도.

enum FlameSize: String, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    static let storageKey = "flameSize"

    var label: String {
        switch self {
        case .small:  return String(localized: "작게")
        case .medium: return String(localized: "보통")
        case .large:  return String(localized: "크게")
        }
    }

    /// 불꽃 높이 배율 (보통 = 1)
    var height: Double {
        switch self {
        case .small:  return 0.75
        case .medium: return 1.0
        case .large:  return 1.4
        }
    }
}

private struct FlameSizeKey: EnvironmentKey {
    static let defaultValue: FlameSize = .small
}

extension EnvironmentValues {
    /// 불꽃 높이. 최상위(BurningParchmentApp)에서 설정값을 넣는다.
    var flameSize: FlameSize {
        get { self[FlameSizeKey.self] }
        set { self[FlameSizeKey.self] = newValue }
    }
}

// MARK: - 가벼운 불꽃 (무료)
// 불꽃을 초당 15번만 그린다(기본 30번). 움직이는 빠르기는 그대로다.
// 불꽃이 기기에 부담을 주면(앱이 쓰는 CPU 가 1분 내내 높거나 기기가 뜨거우면) 한 번 바꾸자고 묻는다.

enum LightFlame {
    static let storageKey = "lightFlame"
    /// 바꾸자고 이미 물었는지. 한 번만 묻는다 — 거절해도 설정 ▸ 불꽃 크기에서 켤 수 있다.
    static let suggestedKey = "lightFlameSuggested"

    /// 불꽃 캐러셀처럼 시간으로 그리는 곳의 갱신 간격
    static func frameInterval(light: Bool) -> TimeInterval { light ? 1.0 / 15.0 : 1.0 / 30.0 }
}

/// 양피지가 타는 동안 앱이 쓴 CPU 시간을 10초마다 재서, 1분 평균이 높거나 기기가 뜨거우면 `isHeavy` 를 켠다.
/// 양피지가 가려지거나 앱이 뒤로 가면 `stop()` 으로 멈추고, 다시 시작하면 처음부터 1분을 잰다.
@MainActor
final class FlameLoadMonitor: ObservableObject {
    @Published private(set) var isHeavy = false

    /// 코어 하나를 기준으로 한 비율. 실기기에서 아직 맞춰 보지 않은 값이다.
    static let cpuThreshold = 0.6
    private static let interval: TimeInterval = 10
    private static let windowCount = 6

    private var timer: Timer?
    private var last: (cpu: Double, wall: Double)?
    private var samples: [Double] = []

    func start() {
        guard timer == nil else { return }
        #if DEBUG
        // 제안 화면 확인용: -forceFlameHeavy YES
        if UserDefaults.standard.bool(forKey: "forceFlameHeavy") { isHeavy = true; return }
        #endif
        last = Self.reading()
        let t = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        t.tolerance = 2
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        last = nil
        samples.removeAll()
    }

    private func sample() {
        let now = Self.reading()
        defer { last = now }
        guard let last, now.wall > last.wall else { return }
        samples.append((now.cpu - last.cpu) / (now.wall - last.wall))
        if samples.count > Self.windowCount { samples.removeFirst() }

        let hot = ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
        let average = samples.reduce(0, +) / Double(samples.count)
        if hot || (samples.count == Self.windowCount && average > Self.cpuThreshold) {
            isHeavy = true
            stop()
        }
    }

    /// 이 앱이 지금까지 쓴 CPU 시간(초)과 지금 시각
    private static func reading() -> (cpu: Double, wall: Double) {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        func seconds(_ t: timeval) -> Double { Double(t.tv_sec) + Double(t.tv_usec) / 1_000_000 }
        return (seconds(usage.ru_utime) + seconds(usage.ru_stime), ProcessInfo.processInfo.systemUptime)
    }
}
