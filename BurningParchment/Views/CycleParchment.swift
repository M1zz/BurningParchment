// CycleParchment.swift
// 되풀이되는 날마다 한 박자씩 타는 양피지 — 아침은 하루, 주말은 한 주, 보름달은 한 달, 핼리 혜성은 76년에 걸쳐 탄다.
// 지난 한 번에서 새 종이가 되고, 다음 한 번이 오면 다 탄다. 큰 양피지와 같은 대각선 탄 자국을 쓴다.

import SwiftUI

struct CycleParchment: View {
    /// 0 이면 새 종이, 1 이면 다 탔다
    let progress: Double
    let caption: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.parchmentAnimationPaused) private var animationPaused

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15, paused: reduceMotion || animationPaused)) { timeline in
            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000) * 0.6
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack(alignment: .topLeading) {
                    paper(progress: progress, phase: phase)
                    if progress > 0.005 && progress < 0.995 {
                        flame(w: w, h: h, phase: phase)
                    }
                }
            }
        }
        .frame(height: 96)
        .overlay(alignment: .bottomLeading) {
            Text(caption)
                .font(.system(.footnote, design: .serif).weight(.semibold))
                .foregroundColor(Self.ink)
                .monospacedDigit()
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Self.paperLight.opacity(0.85)))
                .padding(8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
    }

    private func paper(progress: Double, phase: Double) -> some View {
        let shape = DiagonalBurnShape(progress: progress, phase: phase)
        let t = 1.0 - progress
        return ZStack {
            shape.fill(LinearGradient(colors: [Self.paperLight, Self.paperDark],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
            if progress > 0 {
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: max(0, t - 0.18)),
                    .init(color: Self.scorch.opacity(0.5), location: max(0, t - 0.06)),
                    .init(color: Self.char.opacity(0.92), location: max(0, t)),
                    .init(color: .black.opacity(0.95), location: min(1, t + 0.01)),
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(shape)
            }
            shape.stroke(Color.brown.opacity(0.2), lineWidth: 1)
        }
    }

    /// 탄 자국을 따라 작은 불꽃
    private func flame(w: CGFloat, h: CGFloat, phase: Double) -> some View {
        Canvas { ctx, _ in
            let pts = BurningParchmentView.burnLinePoints(pw: w, ph: h, progress: progress, phase: phase)
            ctx.addFilter(.blur(radius: 3))
            for i in stride(from: 0, to: pts.count, by: 3) {
                let n = sin(Double(i) * 0.7 + phase * 4) * 0.5 + 0.5
                let r = 3 + n * 5
                let p = pts[i]
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r * 1.4, width: r * 2, height: r * 2.4)),
                         with: .color(Color.emberGlow.opacity(0.55 + n * 0.35)))
            }
        }
        .allowsHitTesting(false)
    }

    private static let paperLight = Color(red: 0.86, green: 0.78, blue: 0.62)
    private static let paperDark = Color(red: 0.73, green: 0.62, blue: 0.46)
    private static let scorch = Color(red: 0.38, green: 0.22, blue: 0.08)
    private static let char = Color(red: 0.15, green: 0.07, blue: 0.02)
    private static let ink = Color(red: 0.28, green: 0.18, blue: 0.10)
}
