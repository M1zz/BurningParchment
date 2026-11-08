// UrnShapes.swift
// 항아리 모양 · 새김 무늬 · 씨앗 난수. ReflectionUrnView.swift 에서 나눴다 — 한 파일이 3천 줄이면 한 줄을 고쳐도 통째로 다시 컴파일된다.

import SwiftUI
import LeeoKit

// MARK: - Urn Shape

struct UrnShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let neckW = w * 0.42
        let neckH = h * 0.12
        let lipW  = w * 0.55
        let lipH  = h * 0.06
        let bodyTopY = neckH + lipH
        let bodyMidY = h * 0.55
        let baseW = w * 0.50
        let baseY = h - h * 0.04

        p.move(to: CGPoint(x: (w - lipW) / 2, y: 0))
        p.addLine(to: CGPoint(x: (w + lipW) / 2, y: 0))
        p.addLine(to: CGPoint(x: (w + lipW) / 2, y: lipH))
        p.addLine(to: CGPoint(x: (w + neckW) / 2, y: bodyTopY))
        p.addCurve(
            to: CGPoint(x: (w + baseW) / 2, y: baseY),
            control1: CGPoint(x: w * 1.05, y: bodyTopY + (bodyMidY - bodyTopY) * 0.4),
            control2: CGPoint(x: w * 0.95, y: bodyMidY + (baseY - bodyMidY) * 0.7)
        )
        p.addLine(to: CGPoint(x: (w + baseW) / 2, y: h))
        p.addLine(to: CGPoint(x: (w - baseW) / 2, y: h))
        p.addLine(to: CGPoint(x: (w - baseW) / 2, y: baseY))
        p.addCurve(
            to: CGPoint(x: (w - neckW) / 2, y: bodyTopY),
            control1: CGPoint(x: w * 0.05, y: bodyMidY + (baseY - bodyMidY) * 0.7),
            control2: CGPoint(x: -w * 0.05, y: bodyTopY + (bodyMidY - bodyTopY) * 0.4)
        )
        p.addLine(to: CGPoint(x: (w - lipW) / 2, y: lipH))
        p.closeSubpath()
        return p
    }
}

struct UrnInteriorShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let lipH  = h * 0.06
        let neckH = h * 0.12
        let bodyTopY = neckH + lipH
        let bodyMidY = h * 0.55
        let baseW = w * 0.46
        let baseY = h - h * 0.06
        let neckInsetW = w * 0.34

        p.move(to: CGPoint(x: (w - neckInsetW) / 2, y: bodyTopY))
        p.addLine(to: CGPoint(x: (w + neckInsetW) / 2, y: bodyTopY))
        p.addCurve(
            to: CGPoint(x: (w + baseW) / 2, y: baseY),
            control1: CGPoint(x: w * 0.98, y: bodyMidY * 0.95),
            control2: CGPoint(x: w * 0.90, y: bodyMidY * 1.4)
        )
        p.addLine(to: CGPoint(x: (w - baseW) / 2, y: baseY))
        p.addCurve(
            to: CGPoint(x: (w - neckInsetW) / 2, y: bodyTopY),
            control1: CGPoint(x: w * 0.10, y: bodyMidY * 1.4),
            control2: CGPoint(x: w * 0.02, y: bodyMidY * 0.95)
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - Urn Engraving Shape
// 채움 비율에 따라 단계적으로 드러나는 선각 문양.
// 각 단계는 이전 단계를 포함 — 항아리를 "완성해가는" 느낌.

struct UrnEngravingShape: Shape {
    let fillLevel: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height

        // 단계 1 (≥ 5%): 하단부 가로선 한 줄 — 가장 먼저 드러남
        if fillLevel >= 0.05 {
            let y = h * 0.72
            p.move(to: CGPoint(x: w * 0.22, y: y))
            p.addLine(to: CGPoint(x: w * 0.78, y: y))
        }

        // 단계 2 (≥ 30%): 가로선 + 작은 마름모 3개
        if fillLevel >= 0.30 {
            let y = h * 0.62
            p.move(to: CGPoint(x: w * 0.24, y: y))
            p.addLine(to: CGPoint(x: w * 0.76, y: y))

            let diaY = h * 0.67
            for cx in [w * 0.32, w * 0.50, w * 0.68] {
                let s: CGFloat = 3.5
                p.move(to: CGPoint(x: cx, y: diaY - s))
                p.addLine(to: CGPoint(x: cx + s, y: diaY))
                p.addLine(to: CGPoint(x: cx, y: diaY + s))
                p.addLine(to: CGPoint(x: cx - s, y: diaY))
                p.closeSubpath()
            }
        }

        // 단계 3 (≥ 55%): 식물 덩굴 같은 곡선 (몸체 중간)
        if fillLevel >= 0.55 {
            // 왼쪽 덩굴
            p.move(to: CGPoint(x: w * 0.24, y: h * 0.50))
            p.addQuadCurve(
                to: CGPoint(x: w * 0.48, y: h * 0.44),
                control: CGPoint(x: w * 0.30, y: h * 0.42)
            )
            // 작은 잎
            p.move(to: CGPoint(x: w * 0.36, y: h * 0.45))
            p.addQuadCurve(
                to: CGPoint(x: w * 0.40, y: h * 0.40),
                control: CGPoint(x: w * 0.34, y: h * 0.40)
            )
            // 오른쪽 덩굴
            p.move(to: CGPoint(x: w * 0.76, y: h * 0.50))
            p.addQuadCurve(
                to: CGPoint(x: w * 0.52, y: h * 0.44),
                control: CGPoint(x: w * 0.70, y: h * 0.42)
            )
            // 작은 잎
            p.move(to: CGPoint(x: w * 0.64, y: h * 0.45))
            p.addQuadCurve(
                to: CGPoint(x: w * 0.60, y: h * 0.40),
                control: CGPoint(x: w * 0.66, y: h * 0.40)
            )
        }

        // 단계 4 (≥ 85%): 어깨/입구 띠 — 항아리 전체를 감싸는 마감 문양
        if fillLevel >= 0.85 {
            // 어깨 띠 (목 아래)
            let topY = h * 0.32
            p.move(to: CGPoint(x: w * 0.26, y: topY))
            p.addLine(to: CGPoint(x: w * 0.74, y: topY))
            // 작은 점 장식
            for cx in [w * 0.30, w * 0.50, w * 0.70] {
                p.addEllipse(in: CGRect(x: cx - 1.5, y: topY + 4, width: 3, height: 3))
            }
            // 바닥 마감선
            let baseY = h * 0.82
            p.move(to: CGPoint(x: w * 0.28, y: baseY))
            p.addLine(to: CGPoint(x: w * 0.72, y: baseY))
        }

        return p
    }
}

// MARK: - Seeded RNG

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xDEADBEEF : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
