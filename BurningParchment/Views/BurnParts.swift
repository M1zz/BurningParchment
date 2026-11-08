// BurnParts.swift
// 타는 양피지의 부품 — 프레임 거르기 · 대각선 탄 자국 · 불씨와 재 입자 · 시각 숫자 칸.
// BurningParchmentView.swift 에서 나눴다(한 파일이 길면 한 줄을 고쳐도 통째로 다시 컴파일된다).

import SwiftUI
import Combine

/// 초당 30번 오는 타이머에서 두 번에 한 번을 고른다
final class FrameSkip {
    private var odd = false
    func skipThisTick() -> Bool { odd.toggle(); return odd }
}

// MARK: - Diagonal Burn Shape

struct DiagonalBurnShape: Shape {
    var progress: Double
    var phase: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(progress, phase) }
        set {
            progress = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        if progress >= 1.0 { return Path() }
        if progress <= 0 { return oldParchmentPath(in: rect) }

        let W = Double(rect.width)
        let H = Double(rect.height)
        let k = 2.0 * (1.0 - progress)

        let pts = BurningParchmentView.burnLinePoints(
            pw: rect.width, ph: rect.height, progress: progress, phase: phase
        )

        var path = Path()

        if k >= 1.0 {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: W, y: 0))
            path.addLine(to: pts.last!)
            for pt in pts.reversed() { path.addLine(to: pt) }
            path.addLine(to: CGPoint(x: 0, y: H))
            path.closeSubpath()
        } else {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: pts.last!)
            for pt in pts.reversed() { path.addLine(to: pt) }
            path.closeSubpath()
        }

        return path
    }

    private func oldParchmentPath(in rect: CGRect) -> Path {
        var path = Path()
        let W = rect.width
        let H = rect.height
        let segs = 30

        path.move(to: CGPoint(x: 3, y: 4))
        for i in 1...segs {
            let t = CGFloat(i) / CGFloat(segs)
            let n = sin(CGFloat(i) * 2.1 + 31) * 2.5 + cos(CGFloat(i) * 1.5 + 17) * 1.5
            path.addLine(to: CGPoint(x: W * t - 2, y: 3 + n))
        }
        for i in 1...20 {
            let t = CGFloat(i) / 20.0
            let n = sin(CGFloat(i) * 2.7 + 42) * 2.0
            path.addLine(to: CGPoint(x: W - 3 + n, y: H * t))
        }
        for i in 1...segs {
            let t = CGFloat(i) / CGFloat(segs)
            let n = sin(CGFloat(i) * 1.9 + 17) * 3.0 + cos(CGFloat(i) * 2.5 + 23) * 2.0
            path.addLine(to: CGPoint(x: W * (1.0 - t) + 2, y: H - 4 + n))
        }
        for i in 1...20 {
            let t = CGFloat(i) / 20.0
            let n = sin(CGFloat(i) * 2.3 + 73) * 2.0
            path.addLine(to: CGPoint(x: 3 + n, y: H * (1.0 - t)))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Particle Protocol

protocol Particle {
    var pos: CGPoint { get set }
    var size: CGFloat { get set }
    var opacity: Double { get set }
    var speed: CGFloat { get set }
    var color: Color { get set }
}

// MARK: - Ember

struct Ember: Particle, Identifiable {
    let id = UUID()
    var pos: CGPoint
    var size: CGFloat
    var opacity: Double
    var speed: CGFloat
    var color: Color

    static func spawn(on burnPts: [CGPoint], ox: CGFloat, oy: CGFloat, pw: CGFloat, ph: CGFloat) -> Ember {
        let pt = burnPts.randomElement() ?? CGPoint(x: pw * 0.5, y: ph * 0.5)
        return Ember(
            pos: CGPoint(x: pt.x + ox + .random(in: -8...8), y: pt.y + oy + .random(in: -8...8)),
            size: .random(in: 2...5),
            opacity: .random(in: 0.6...1.0),
            speed: .random(in: 0.8...2.5),
            color: [Color.yellow, .orange, Color(red: 1, green: 0.85, blue: 0.4)].randomElement()!
        )
    }
}

// MARK: - Ash

struct Ash: Particle, Identifiable {
    let id = UUID()
    var pos: CGPoint
    var size: CGFloat
    var opacity: Double
    var speed: CGFloat
    var color: Color
    var swayPhase: Double = 0
    var swayFreq: Double = 1.0
    var swayAmp: CGFloat = 2.0

    static func spawn(on burnPts: [CGPoint], ox: CGFloat, oy: CGFloat, pw: CGFloat, ph: CGFloat) -> Ash {
        let pt = burnPts.randomElement() ?? CGPoint(x: pw * 0.5, y: ph * 0.5)
        let nLen = sqrt(Double(ph * ph + pw * pw))
        let nx = Double(ph) / nLen
        let ny = Double(pw) / nLen
        let drift = Double.random(in: 10...40)
        return Ash(
            pos: CGPoint(
                x: pt.x + ox + CGFloat(nx * drift) + .random(in: -10...10),
                y: pt.y + oy + CGFloat(ny * drift) + .random(in: -10...10)
            ),
            size: .random(in: 1.5...4),
            opacity: .random(in: 0.25...0.55),
            speed: .random(in: 0.35...1.1),
            color: Color(red: .random(in: 0.2...0.42), green: .random(in: 0.15...0.3), blue: .random(in: 0.1...0.22)),
            swayPhase: .random(in: 0...(2 * .pi)),
            swayFreq: .random(in: 0.6...1.8),
            swayAmp: .random(in: 1.2...3.6)
        )
    }
}

// MARK: - Time Digit View

struct TimeDigitView: View {
    let value: Int
    let label: String

    var body: some View {
        Text(String(format: "%02d", value))
            .font(.system(.largeTitle, design: .serif).weight(.ultraLight))
            .foregroundColor(.ember.opacity(0.9))
            .monospacedDigit()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        BurningParchmentView()
            .environmentObject(BedtimeManager())
            .environmentObject(DeadlineManager())
            .environmentObject(FragmentManager())
            .environmentObject(NightManager())
    }
}
