// BedtimeLiveActivity.swift
// 다이나믹 아일랜드 & 잠금화면 Live Activity

import SwiftUI
import WidgetKit
import ActivityKit

struct BedtimeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BedtimeActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // ── Expanded ──
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 12) {
                        if context.state.showMiniParchment {
                            MiniParchmentView(progress: context.state.progress)
                                .frame(width: 52, height: 64)
                        } else {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.orange)
                                .frame(width: 52, height: 64)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(timerInterval: Date()...context.state.bedtimeDate, countsDown: true)
                                .font(.system(size: 26, weight: .light, design: .monospaced))
                                .foregroundColor(.orange)
                                .monospacedDigit()

                            Text("🔥 \(Int((1.0 - context.state.progress) * 100))% 남음")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Spacer()
                        Text("취침 \(context.attributes.bedtimeString)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }

            } compactLeading: {
                if context.state.showMiniParchment {
                    MiniParchmentView(progress: context.state.progress)
                        .frame(width: 18, height: 22)
                } else {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }

            } compactTrailing: {
                Text(timerInterval: Date()...context.state.bedtimeDate, countsDown: true)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.orange)
                    .monospacedDigit()
                    .frame(width: 52)

            } minimal: {
                if context.state.showMiniParchment {
                    MiniParchmentView(progress: context.state.progress)
                        .frame(width: 16, height: 20)
                } else {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
        }
    }

    // MARK: - Lock Screen
    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<BedtimeActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            // 미니 양피지 연소 시각화
            if context.state.showMiniParchment {
                MiniParchmentView(progress: context.state.progress)
                    .frame(width: 40, height: 52)
            } else {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                    .frame(width: 40, height: 52)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("취침까지")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange.opacity(0.7))

                Text(timerInterval: Date()...context.state.bedtimeDate, countsDown: true)
                    .font(.system(size: 24, weight: .light, design: .monospaced))
                    .foregroundColor(.white)
                    .monospacedDigit()

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: geo.size.width * (1.0 - context.state.progress), height: 3)
                    }
                }
                .frame(height: 3)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow.opacity(0.6))
                Text(context.attributes.bedtimeString)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.8))
    }
}

// MARK: - Mini Parchment View (위젯용 경량 양피지 연소 시각화)

struct MiniParchmentView: View {
    let progress: Double

    var body: some View {
        Canvas { ctx, size in
            let W = size.width
            let H = size.height

            // 1) 그림자 (탄 뒤 배경)
            let bgRect = CGRect(x: 1, y: 1, width: W - 2, height: H - 2)
            ctx.fill(
                Path(roundedRect: bgRect, cornerRadius: 2),
                with: .color(Color(red: 0.12, green: 0.08, blue: 0.05))
            )

            if progress >= 1.0 { return }

            // 2) 남은 양피지 Shape
            let parchPath = miniParchmentPath(W: W, H: H, progress: progress)
            ctx.fill(parchPath, with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.95, green: 0.88, blue: 0.7),
                    Color(red: 0.85, green: 0.72, blue: 0.5),
                    Color(red: 0.75, green: 0.6, blue: 0.38),
                ]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: W, y: H)
            ))

            // 3) 연소 경계선 불꽃 glow
            if progress > 0.01 && progress < 0.99 {
                let glowPath = miniBurnEdgePath(W: W, H: H, progress: progress)
                ctx.stroke(glowPath, with: .color(.orange.opacity(0.9)), lineWidth: 2)

                ctx.blendMode = .screen
                ctx.stroke(glowPath, with: .color(.yellow.opacity(0.5)), lineWidth: 3.5)
                ctx.blendMode = .normal
            }

            // 4) 그을린 테두리 (연소 경계 안쪽)
            if progress > 0.02 {
                let scorchPath = miniScorchPath(W: W, H: H, progress: progress)
                ctx.fill(scorchPath, with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.2, green: 0.1, blue: 0.03).opacity(0.8),
                        Color.clear,
                    ]),
                    startPoint: .init(x: W * (1.0 - progress), y: H * (1.0 - progress)),
                    endPoint: .init(x: W * max(0, 0.9 - progress), y: H * max(0, 0.9 - progress))
                ))
            }
        }
    }

    // MARK: - Noise (위젯용 경량 fBm)

    private func hash2D(_ x: Double, _ y: Double) -> Double {
        var v = sin(x * 127.1 + y * 311.7) * 43758.5453123
        v = v - Foundation.floor(v)
        return v
    }

    private func valueNoise(_ x: Double, _ y: Double) -> Double {
        let ix = Foundation.floor(x), iy = Foundation.floor(y)
        let fx = x - ix, fy = y - iy
        let ux = fx * fx * (3.0 - 2.0 * fx)
        let uy = fy * fy * (3.0 - 2.0 * fy)
        let a = hash2D(ix, iy)
        let b = hash2D(ix + 1, iy)
        let c = hash2D(ix, iy + 1)
        let d = hash2D(ix + 1, iy + 1)
        return a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy
    }

    private func fbm(_ x: Double, _ y: Double) -> Double {
        var value = 0.0, amp = 0.5, freq = 1.0
        for _ in 0..<4 {
            value += amp * (valueNoise(x * freq, y * freq) * 2.0 - 1.0)
            amp *= 0.5; freq *= 2.0
        }
        return value
    }

    // MARK: - Burn Line

    private func burnLinePoints(W: Double, H: Double, progress: Double) -> [CGPoint] {
        let k = 2.0 * (1.0 - progress)
        let startPt: (Double, Double)
        let endPt: (Double, Double)

        if k >= 1.0 {
            startPt = ((k - 1.0) * W, H)
            endPt = (W, (k - 1.0) * H)
        } else {
            startPt = (0, k * H)
            endPt = (k * W, 0)
        }

        let nLen = sqrt(H * H + W * W)
        let nx = H / nLen
        let ny = W / nLen

        let segments = 24
        var points: [CGPoint] = []

        for i in 0...segments {
            let t = Double(i) / Double(segments)
            let bx = startPt.0 + (endPt.0 - startPt.0) * t
            let by = startPt.1 + (endPt.1 - startPt.1) * t

            let edgeFade = min(Double(i), Double(segments - i)) / 3.0
            let fade = min(edgeFade, 1.0)

            let scale = 0.06
            let noise = fbm(bx * scale + 3.7, by * scale + 7.1) * min(W, H) * 0.35 * fade

            let px = max(0, min(W, bx + nx * noise))
            let py = max(0, min(H, by + ny * noise))
            points.append(CGPoint(x: px, y: py))
        }

        return points
    }

    // MARK: - Paths

    private func miniParchmentPath(W: CGFloat, H: CGFloat, progress: Double) -> Path {
        if progress <= 0 {
            return Path(roundedRect: CGRect(x: 1, y: 1, width: W - 2, height: H - 2), cornerRadius: 2)
        }

        let k = 2.0 * (1.0 - progress)
        let pts = burnLinePoints(W: Double(W), H: Double(H), progress: progress)
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

    private func miniBurnEdgePath(W: CGFloat, H: CGFloat, progress: Double) -> Path {
        let pts = burnLinePoints(W: Double(W), H: Double(H), progress: progress)
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)
        for pt in pts.dropFirst() { path.addLine(to: pt) }
        return path
    }

    private func miniScorchPath(W: CGFloat, H: CGFloat, progress: Double) -> Path {
        // 연소 경계선 근처의 그을린 영역
        let pts = burnLinePoints(W: Double(W), H: Double(H), progress: progress)
        let nLen = sqrt(Double(H * H + W * W))
        let nx = Double(H) / nLen
        let ny = Double(W) / nLen
        let offset = min(Double(W), Double(H)) * 0.15

        var path = Path()
        guard let first = pts.first else { return path }

        // burn line을 따라 안쪽으로 offset만큼 확장
        path.move(to: first)
        for pt in pts { path.addLine(to: pt) }
        for pt in pts.reversed() {
            path.addLine(to: CGPoint(
                x: max(0, min(Double(W), Double(pt.x) - nx * offset)),
                y: max(0, min(Double(H), Double(pt.y) - ny * offset))
            ))
        }
        path.closeSubpath()
        return path
    }
}
