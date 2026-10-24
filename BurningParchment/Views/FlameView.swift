// FlameView.swift
// 타는 경계선을 따라 솟는 불꽃 — 종류(FlameKind)마다 결이 다르다.
//
// 모든 종류가 같은 입력을 받는다: 경계선 위 점들, 불꽃이 솟는 방향, 시간(phase).
// 양피지·불 끄기 화면·설정 카드가 이 뷰 하나를 쓰므로 어디서 고르든 같은 불이 탄다.
//
//   촛불 — 열 지도 → Metal(candleFire) 로 위로 솟는 종이 불 + 숯처럼 달아오른 경계선 + 옅은 연기
//   들불 — Canvas 로 그린 열 지도 → Metal(blazeFire) 로 일렁임·흑체 색 + 글로우 + 솟는 불씨
//   숯불 — 낮은 열 띠 → Metal(smolderFire) 로 숨 쉬는 숯 + 붉은 글로우 + 느린 불씨
//   불티 — 하얗게 달아오른 선 + 꼬리를 끄는 스파크
//
// intensity 는 불의 세기(0 이면 꺼짐), breath 는 입김에 눕고 떨리는 정도, scale 은 크기.
// 빛깔(테마)은 바깥에서 flameTint 로 얹는다.

import SwiftUI

struct FlameView: View {
    let kind: FlameKind
    let points: [CGPoint]
    let normal: CGVector
    let phase: Double
    var intensity: Double = 1
    var breath: Double = 0
    var scale: Double = 1

    // 미색 바탕(라이트)에서는 하얗게 달아오른 색이 바탕에 묻힌다 — 불티는 그때 한 톤 짙게 그린다
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.flameSize) private var flameSize
    private var onLight: Bool { colorScheme == .light }

    /// 셰이더에 넘기는 시간 — float 정밀도가 무너지지 않게 적당히 감는다
    private var shaderTime: Float { Float(phase.truncatingRemainder(dividingBy: 1200)) }
    private var flow: (Float, Float) { (Float(normal.dx), Float(normal.dy)) }

    var body: some View {
        if intensity > 0.01, points.count > 1 {
            switch kind {
            case .classic:  classic
            case .blaze:    blaze
            case .smolder:  smolder
            case .sparkler: sparkler
            }
        }
    }

    // MARK: - 촛불

    // 실제 종이 불처럼 — 타 들어가는 방향과 상관없이 위로 솟고, 가장자리는 숯처럼 달아오르고, 옅은 연기가 오른다.
    private var classic: some View {
        let up = Self.rising(normal)
        let a = min(1, intensity * 1.2)
        return ZStack {
            Self.glow(points, color: Color(red: 1.0, green: 0.50, blue: 0.12),
                      width: 34 * scale, radius: 18 * scale,
                      opacity: (0.24 + 0.06 * sin(phase * 3.1) + 0.03 * sin(phase * 7.3)) * a)

            Self.smoke(points, up: up, phase: phase, intensity: intensity, scale: scale)

            // 타는 경계선 — 숯불 셰이더로 얼룩덜룩 숨 쉬는 붉은 테두리
            Self.heatMask(points, normal: normal, phase: phase * 0.4, intensity: intensity, breath: 0,
                          scale: scale, height: 0, width: 0, band: 5)
                .blur(radius: 1.2 * scale)
                .layerEffect(ShaderLibrary.smolderFire(.float(shaderTime), .float2(flow.0, flow.1),
                                                       .float(Float(scale * 0.7))),
                             maxSampleOffset: CGSize(width: 8 * scale, height: 8 * scale))
                .fireBlend()

            Self.heatMask(points, normal: up, phase: phase, intensity: intensity, breath: breath,
                          scale: scale, height: 1.35 * flameSize.height, width: 1.3, band: 6)
                .blur(radius: 2.2 * scale)
                .layerEffect(ShaderLibrary.candleFire(.float(shaderTime), .float2(Float(up.dx), Float(up.dy)),
                                                      .float(Float(scale))),
                             maxSampleOffset: CGSize(width: 30 * scale, height: 30 * scale))
                .fireBlend()

            Self.sparks(points, normal: up, phase: phase, intensity: intensity * 0.45, scale: scale,
                        style: .rising)
        }
        .allowsHitTesting(false)
    }

    /// 불꽃이 솟는 방향 — 거의 곧장 위, 경계선 바깥쪽으로 살짝 기운다
    private static func rising(_ normal: CGVector) -> CGVector {
        let dx = Double(normal.dx) * 0.22, dy = -1.0
        let len = sqrt(dx * dx + dy * dy)
        return CGVector(dx: dx / len, dy: dy / len)
    }

    // MARK: - 연기
    // 불꽃 위로 옅게 피어올라 흩어진다. 스파크처럼 phase 만으로 그린다.

    private static func smoke(_ pts: [CGPoint], up: CGVector, phase: Double,
                              intensity: Double, scale: Double) -> some View {
        Canvas { ctx, _ in
            guard pts.count > 1 else { return }
            ctx.addFilter(.blur(radius: 9 * scale))
            let ux = Double(up.dx), uy = Double(up.dy)
            for j in 0..<16 {
                let fj = Double(j)
                let period = 2.6 + 1.6 * hash(fj, 9.1)
                let raw = phase / period + hash(fj, 2.7) * 5.0
                let cycle = floor(raw)
                let c = raw - cycle
                let o = pts[min(pts.count - 1, Int(hash(fj, cycle + 0.9) * Double(pts.count)))]
                let rise = (30 + 90 * c) * scale
                let drift = sin(phase * 0.9 + fj * 1.7) * 14 * c * scale
                let px = Double(o.x) + ux * rise - uy * drift
                let py = Double(o.y) + uy * rise + ux * drift
                let r = (8 + 26 * c) * scale
                ctx.opacity = sin(c * .pi) * 0.22 * min(1, intensity)
                ctx.fill(Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                         with: .color(Color(red: 0.55, green: 0.52, blue: 0.50)))
            }
        }
    }

    // MARK: - 들불

    private var blaze: some View {
        ZStack {
            Self.glow(points, color: Color(red: 1.0, green: 0.42, blue: 0.08),
                      width: 46 * scale, radius: 22 * scale,
                      opacity: (0.30 + 0.08 * sin(phase * 2.3)) * min(1, intensity * 1.2))

            Self.heatMask(points, normal: normal, phase: phase, intensity: intensity, breath: breath,
                          scale: scale, height: 1.75 * flameSize.height, width: 2.1, band: 10)
                .blur(radius: 3 * scale)
                .layerEffect(ShaderLibrary.blazeFire(.float(shaderTime), .float2(flow.0, flow.1),
                                                     .float(Float(scale))),
                             maxSampleOffset: CGSize(width: 40 * scale, height: 40 * scale))
                .fireBlend()

            Self.sparks(points, normal: normal, phase: phase, intensity: intensity, scale: scale,
                        style: .rising)
        }
        .allowsHitTesting(false)
    }

    // MARK: - 숯불

    private var smolder: some View {
        ZStack {
            Self.glow(points, color: Color(red: 0.85, green: 0.12, blue: 0.02),
                      width: 30 * scale, radius: 16 * scale,
                      opacity: (0.32 + 0.10 * sin(phase * 1.1)) * min(1, intensity * 1.2))

            Self.heatMask(points, normal: normal, phase: phase * 0.4, intensity: intensity, breath: breath,
                          scale: scale, height: 0.42 * flameSize.height, width: 1.5, band: 12)
                .blur(radius: 2.5 * scale)
                .layerEffect(ShaderLibrary.smolderFire(.float(shaderTime), .float2(flow.0, flow.1),
                                                       .float(Float(scale))),
                             maxSampleOffset: CGSize(width: 12 * scale, height: 12 * scale))
                .fireBlend()

            Self.sparks(points, normal: normal, phase: phase, intensity: intensity, scale: scale,
                        style: .drifting)
        }
        .allowsHitTesting(false)
    }

    // MARK: - 불티

    private var sparkler: some View {
        ZStack {
            Canvas { ctx, _ in
                var line = Path()
                line.addLines(points)
                let a = min(1, intensity * 1.3)
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 7 * scale))
                    layer.opacity = (0.55 + 0.15 * sin(phase * 7)) * a
                    layer.stroke(line, with: .color(Color(red: 1.0, green: 0.55, blue: 0.12)),
                                 style: StrokeStyle(lineWidth: 12 * scale, lineCap: .round, lineJoin: .round))
                }
                ctx.opacity = 0.95 * a
                ctx.stroke(line, with: .color(onLight ? Color(red: 1.0, green: 0.62, blue: 0.10)
                                                      : Color(red: 1.0, green: 0.95, blue: 0.80)),
                           style: StrokeStyle(lineWidth: 2.2 * scale, lineCap: .round, lineJoin: .round))
            }
            .fireBlend()

            // 낮게 깔린 작은 불꽃
            BurningParchmentView.flameCanvas(along: points, normal: normal, phase: phase,
                                             intensity: intensity * 0.8, breath: breath, scale: scale * 0.5)

            Self.sparks(points, normal: normal, phase: phase, intensity: intensity, scale: scale,
                        style: .burst, onLight: onLight)
        }
        .allowsHitTesting(false)
    }

    // MARK: - 열 지도
    // 흰색으로 그린다 — 셰이더는 알파만 열로 읽는다. 뿌리는 경계선을 따라 굵은 띠, 그 위로 혀가 솟는다.

    private static func heatMask(_ pts: [CGPoint], normal: CGVector, phase: Double,
                                 intensity: Double, breath: Double, scale: Double,
                                 height: Double, width: Double, band: Double) -> some View {
        Canvas { ctx, _ in
            let nx = Double(normal.dx), ny = Double(normal.dy)
            let tx = -ny, ty = nx

            var line = Path()
            line.addLines(pts)
            ctx.opacity = min(1, intensity * 1.3)
            ctx.stroke(line, with: .color(.white.opacity(0.92)),
                       style: StrokeStyle(lineWidth: band * scale, lineCap: .round, lineJoin: .round))
            guard height > 0 else { return }

            for i in stride(from: 0, to: pts.count, by: 2) {
                let pt = pts[i]
                let fi = Double(i)
                let n1 = sin(fi * 0.55 + phase * 4.0) * 0.5 + 0.5
                let n2 = cos(fi * 0.90 + phase * 3.0)
                let n3 = sin(fi * 1.70 + phase * 5.5)

                let h = (14.0 + n1 * 26.0 + n3 * 7.0) * height * scale * intensity * (1.0 - breath * 0.35)
                let w = (5.0 + n1 * 4.5) * width * scale
                let sway = (n2 * 3.0 + breath * 14.0 * sin(fi * 0.8 + phase * 11.0)) * scale

                let bx = Double(pt.x), by = Double(pt.y)
                let tip = CGPoint(x: bx + nx * h + tx * sway, y: by + ny * h + ty * sway)
                let midX = bx + nx * h * 0.42, midY = by + ny * h * 0.42
                let c1 = CGPoint(x: midX + tx * (w * 0.35 + sway * 0.5), y: midY + ty * (w * 0.35 + sway * 0.5))
                let c2 = CGPoint(x: midX - tx * (w * 0.35 - sway * 0.5), y: midY - ty * (w * 0.35 - sway * 0.5))

                var tongue = Path()
                tongue.move(to: CGPoint(x: bx + tx * w * 0.5, y: by + ty * w * 0.5))
                tongue.addQuadCurve(to: tip, control: c1)
                tongue.addQuadCurve(to: CGPoint(x: bx - tx * w * 0.5, y: by - ty * w * 0.5), control: c2)
                tongue.closeSubpath()

                ctx.opacity = (0.75 + n1 * 0.25) * min(1, intensity * 1.3)
                ctx.fill(tongue, with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white.opacity(0.6), location: 0.45),
                        .init(color: .clear, location: 1),
                    ]),
                    startPoint: pt, endPoint: tip
                ))
            }
        }
    }

    // MARK: - 글로우

    private static func glow(_ pts: [CGPoint], color: Color, width: Double, radius: Double,
                             opacity: Double) -> some View {
        Canvas { ctx, _ in
            var line = Path()
            line.addLines(pts)
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: radius))
                layer.opacity = opacity
                layer.stroke(line, with: .color(color),
                             style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
        }
        .fireBlend()
    }

    // MARK: - 스파크
    // 상태 없이 phase 만으로 그린다 — 같은 시각이면 같은 자리라 어느 화면에서든 그냥 얹으면 된다.
    // 스파크마다 주기가 있고, 주기가 바뀔 때마다 경계선 위 다른 자리에서 다시 튄다.

    enum SparkStyle {
        case rising     // 들불 — 불길을 타고 솟구치는 불씨
        case drifting   // 숯불 — 느릿하게 떠오르는 몇 점
        case burst      // 불티 — 사방으로 튀었다가 떨어지며 갈라지는 불꽃

        var count: Int { switch self { case .rising: 34; case .drifting: 12; case .burst: 70 } }
        /// 한 번 튀어서 사라지기까지 (phase 단위 — 1초에 약 1.5)
        var life: Double { switch self { case .rising: 1.6; case .drifting: 3.2; case .burst: 0.9 } }
        /// phase 1 동안 날아가는 거리(pt)
        var speed: Double { switch self { case .rising: 55; case .drifting: 16; case .burst: 85 } }
        /// 솟는 방향에서 퍼지는 각도(라디안, 전체 폭)
        var spread: Double { switch self { case .rising: 1.0; case .drifting: 1.3; case .burst: 2.6 } }
        var streak: Double { switch self { case .rising: 9; case .drifting: 0; case .burst: 14 } }
        /// 화면 아래로 끌어내리는 힘
        var gravity: Double { switch self { case .rising: 0; case .drifting: 0; case .burst: 60 } }
        var size: Double { switch self { case .rising: 1.8; case .drifting: 2.6; case .burst: 1.4 } }
    }

    private static func sparks(_ pts: [CGPoint], normal: CGVector, phase: Double,
                               intensity: Double, scale: Double, style: SparkStyle,
                               onLight: Bool = false) -> some View {
        Canvas { ctx, _ in
            guard pts.count > 1 else { return }
            let nx = Double(normal.dx), ny = Double(normal.dy)
            let count = Int(Double(style.count) * min(1, intensity))
            let hot = onLight ? Color(red: 1.0, green: 0.58, blue: 0.08) : Color(red: 1.0, green: 0.95, blue: 0.78)
            let warm = onLight ? Color(red: 0.92, green: 0.32, blue: 0.04) : Color(red: 1.0, green: 0.62, blue: 0.16)

            for j in 0..<count {
                let fj = Double(j)
                let period = style.life * (0.6 + 0.8 * hash(fj, 2.1))
                let raw = phase / period + hash(fj, 1.3) * 7.0
                let cycle = floor(raw)
                let c = raw - cycle                     // 이번 주기 안에서 0→1
                let age = c * period                    // phase 단위 경과

                let o = pts[min(pts.count - 1, Int(hash(fj, cycle + 0.5) * Double(pts.count)))]
                let ang = (hash(fj, cycle + 3.3) - 0.5) * style.spread
                let dx = nx * cos(ang) - ny * sin(ang)
                let dy = nx * sin(ang) + ny * cos(ang)
                let sp = style.speed * (0.45 + hash(fj, cycle + 4.4)) * scale
                let wob = style == .burst ? 0 : sin(phase * 3 + fj) * 6 * c * scale

                let px = Double(o.x) + dx * sp * age - dy * wob
                let py = Double(o.y) + dy * sp * age + dx * wob + style.gravity * scale * age * age
                let vx = dx * sp, vy = dy * sp + 2 * style.gravity * scale * age
                let vLen = max(sqrt(vx * vx + vy * vy), 0.001)

                let fade = pow(1 - c, 1.2) * (0.6 + 0.4 * hash(fj, cycle + 5.5))
                let s = style.size * scale * (1 - c * 0.55) * (0.7 + 0.6 * hash(fj, 6.6))
                let head = CGPoint(x: px, y: py)

                if style.streak > 0 {
                    let len = style.streak * scale * (1 - c * 0.5)
                    let tail = CGPoint(x: px - vx / vLen * len, y: py - vy / vLen * len)
                    var p = Path()
                    p.move(to: tail)
                    p.addLine(to: head)
                    ctx.opacity = fade
                    ctx.stroke(p, with: .linearGradient(Gradient(colors: [.clear, warm, hot]),
                                                        startPoint: tail, endPoint: head),
                               style: StrokeStyle(lineWidth: s, lineCap: .round))
                }

                // 불티는 사그라들 무렵 작은 별처럼 갈라진다
                if style == .burst, c > 0.62, hash(fj, cycle + 7.7) > 0.55 {
                    let r = 5.0 * scale * (c - 0.62) / 0.38
                    ctx.opacity = fade * 0.9
                    for k in 0..<4 {
                        let a = Double(k) * .pi / 2 + hash(fj, cycle) * 3
                        var b = Path()
                        b.move(to: head)
                        b.addLine(to: CGPoint(x: px + cos(a) * r, y: py + sin(a) * r))
                        ctx.stroke(b, with: .color(hot), style: StrokeStyle(lineWidth: 0.8 * scale, lineCap: .round))
                    }
                }

                ctx.opacity = fade * 0.35
                ctx.fill(Path(ellipseIn: CGRect(x: px - s * 1.8, y: py - s * 1.8, width: s * 3.6, height: s * 3.6)),
                         with: .color(warm))
                ctx.opacity = fade
                ctx.fill(Path(ellipseIn: CGRect(x: px - s / 2, y: py - s / 2, width: s, height: s)),
                         with: .color(style == .drifting ? warm : hot))
            }
        }
        .fireBlend()
    }

    private static func hash(_ x: Double, _ y: Double) -> Double {
        let v = sin(x * 127.1 + y * 311.7) * 43758.5453123
        return v - floor(v)
    }
}
