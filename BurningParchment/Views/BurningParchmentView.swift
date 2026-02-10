// BurningParchmentView.swift
// 양피지(상단) + 타이머/게이지(하단) 레이아웃
// 오른쪽 아래 모서리부터 대각선으로 타들어감

import SwiftUI

// MARK: - Main View

struct BurningParchmentView: View {
    @EnvironmentObject var bedtimeManager: BedtimeManager
    @State private var phase: Double = 0
    @State private var embers: [Ember] = []
    @State private var ashes: [Ash] = []

    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let pw = size.width - 48
            let ph = size.height * 0.48
            let ox = (size.width - pw) / 2
            let oy: CGFloat = 8
            let progress = bedtimeManager.progress

            ZStack {
                if bedtimeManager.isBeforeWakeTime {
                    beforeWakeView(pw: pw, ph: ph, oy: oy, size: size)
                } else if !bedtimeManager.isCountdownActive && progress >= 1.0 {
                    bedtimeReachedView(size: size)
                } else {
                    burningView(size: size, pw: pw, ph: ph, ox: ox, oy: oy, progress: progress)
                }
            }
            .onReceive(timer) { _ in
                phase += 0.05
                if bedtimeManager.isCountdownActive {
                    updateParticles(pw: pw, ph: ph, ox: ox, oy: oy)
                }
            }
            .onAppear {
                initParticles(pw: pw, ph: ph, ox: ox, oy: oy)
            }
        }
    }

    // MARK: - Burning View

    private func burningView(size: CGSize, pw: CGFloat, ph: CGFloat, ox: CGFloat, oy: CGFloat, progress: Double) -> some View {
        ZStack {
            // 배경 글로우
            if progress > 0 {
                burnGlow(size: size, progress: progress)
            }

            // 재 파티클
            particleCanvas(items: ashes, withGlow: false)

            // 양피지 (상단 배치)
            parchmentGroup(pw: pw, ph: ph, progress: progress)
                .position(x: size.width / 2, y: oy + ph / 2)

            // 불꽃
            if progress > 0.005 && progress < 0.995 {
                flameCanvas(pw: pw, ph: ph, ox: ox, oy: oy, progress: progress)
            }

            // 불씨 파티클
            particleCanvas(items: embers, withGlow: true)

            // 하단: 타이머 + 게이지
            VStack {
                Spacer()
                timerSection(progress: progress, size: size)
            }
        }
    }

    // MARK: - Before Wake

    private func beforeWakeView(pw: CGFloat, ph: CGFloat, oy: CGFloat, size: CGSize) -> some View {
        ZStack {
            DiagonalBurnShape(progress: 0, phase: 0)
                .fill(parchmentGradient)
                .frame(width: pw, height: ph)
                .overlay(
                    DiagonalBurnShape(progress: 0, phase: 0)
                        .stroke(Color.brown.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
                .position(x: size.width / 2, y: oy + ph / 2)

            VStack {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange.opacity(0.5))
                    Text("기상시간에 양피지가\n타기 시작합니다")
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 60)
            }
        }
    }

    // MARK: - Bedtime Reached (불타는 하트)

    private func bedtimeReachedView(size: CGSize) -> some View {
        ZStack {
            // 배경 따뜻한 글로우
            RadialGradient(
                colors: [
                    Color.red.opacity(0.12 + 0.05 * sin(phase * 1.5)),
                    Color.orange.opacity(0.05),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 200
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // 불타는 하트
                ZStack {
                    // 외부 글로우
                    Image(systemName: "heart.fill")
                        .font(.system(size: 90))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red.opacity(0.4), .orange.opacity(0.3)],
                                startPoint: .bottom, endPoint: .top
                            )
                        )
                        .blur(radius: 25)
                        .scaleEffect(1.05 + 0.05 * sin(phase * 2.0))

                    // 하트 본체
                    Image(systemName: "heart.fill")
                        .font(.system(size: 75))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.8, green: 0.1, blue: 0.1),
                                    Color(red: 0.95, green: 0.4, blue: 0.1),
                                    Color(red: 1.0, green: 0.75, blue: 0.2)
                                ],
                                startPoint: .bottom, endPoint: .top
                            )
                        )
                        .scaleEffect(1.0 + 0.02 * sin(phase * 2.5))

                    // 중앙 불꽃
                    Image(systemName: "flame.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange.opacity(0.8), .red.opacity(0.4)],
                                startPoint: .bottom, endPoint: .top
                            )
                        )
                        .offset(y: -46 + sin(phase * 3.0) * 3)
                        .scaleEffect(0.9 + 0.15 * sin(phase * 4.0))
                        .blur(radius: 1)

                    // 좌측 불꽃
                    Image(systemName: "flame")
                        .font(.system(size: 20))
                        .foregroundColor(.orange.opacity(0.6))
                        .offset(x: -28, y: -30)
                        .scaleEffect(0.8 + 0.2 * sin(phase * 3.5))
                        .opacity(0.5 + 0.3 * sin(phase * 2.5))

                    // 우측 불꽃
                    Image(systemName: "flame")
                        .font(.system(size: 18))
                        .foregroundColor(.orange.opacity(0.5))
                        .offset(x: 30, y: -35)
                        .scaleEffect(0.7 + 0.25 * sin(phase * 4.0))
                        .opacity(0.4 + 0.3 * cos(phase * 3.0))
                }

                Text("취침 시간입니다")
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundColor(.orange.opacity(0.7))

                Text("🌙 좋은 꿈 꾸세요")
                    .font(.system(size: 15, design: .serif))
                    .foregroundColor(.gray.opacity(0.5))

                Spacer()
            }
        }
    }

    // MARK: - Timer Section (하단)

    private func timerSection(progress: Double, size: CGSize) -> some View {
        VStack(spacing: 14) {
            // 남은 시간
            VStack(spacing: 4) {
                Text("취침까지 남은 시간")
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundColor(.orange.opacity(0.6))

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    TimeDigitView(value: bedtimeManager.remainingHours, label: "h")
                    Text(":")
                        .font(.system(size: 34, weight: .light, design: .serif))
                        .foregroundColor(.orange.opacity(0.5))
                    TimeDigitView(value: bedtimeManager.remainingMinutes, label: "m")
                    Text(":")
                        .font(.system(size: 34, weight: .light, design: .serif))
                        .foregroundColor(.orange.opacity(0.5))
                    TimeDigitView(value: bedtimeManager.remainingSecs, label: "s")
                }
            }

            // 게이지 바
            HStack(spacing: 8) {
                Text("🔥").font(.system(size: 13))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)

                Text("🌙").font(.system(size: 13))
            }
            .padding(.horizontal, 32)

            Text("\(Int((1.0 - progress) * 100))% 남음")
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundColor(.gray.opacity(0.6))
        }
        .padding(.bottom, 28)
    }

    // MARK: - Parchment Gradient

    private var parchmentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.86, green: 0.78, blue: 0.62),
                Color(red: 0.80, green: 0.70, blue: 0.54),
                Color(red: 0.73, green: 0.62, blue: 0.46),
                Color(red: 0.66, green: 0.54, blue: 0.39),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Background Glow

    private func burnGlow(size: CGSize, progress: Double) -> some View {
        let k = 2.0 * (1.0 - progress)
        let cx = min(1.0, max(0.3, 1.0 - k * 0.25))
        let cy = min(0.5, max(0.1, 0.5 - k * 0.15))

        return RadialGradient(
            colors: [
                Color.orange.opacity(0.18 + 0.06 * sin(phase * 2.0)),
                Color.red.opacity(0.07),
                Color.clear
            ],
            center: UnitPoint(x: cx, y: cy),
            startRadius: 10,
            endRadius: max(size.width, size.height) * 0.6
        )
        .ignoresSafeArea()
    }

    // MARK: - Particle Canvas

    private func particleCanvas(items: [Particle], withGlow: Bool) -> some View {
        Canvas { ctx, _ in
            for p in items {
                if withGlow {
                    let gr = p.size * 1.8
                    ctx.opacity = p.opacity * 0.3
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: p.pos.x - gr, y: p.pos.y - gr, width: gr * 2, height: gr * 2)),
                        with: .color(.orange)
                    )
                }
                ctx.opacity = p.opacity
                let r = p.size / 2
                ctx.fill(
                    Path(ellipseIn: CGRect(x: p.pos.x - r, y: p.pos.y - r, width: p.size, height: p.size)),
                    with: .color(p.color)
                )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Parchment Group

    private func parchmentGroup(pw: CGFloat, ph: CGFloat, progress: Double) -> some View {
        let shape = DiagonalBurnShape(progress: progress, phase: phase)

        return ZStack {
            shape.fill(parchmentGradient)

            if progress > 0 {
                scorchOverlay(progress: progress, shape: shape)
            }

            shape.stroke(Color.brown.opacity(0.2), lineWidth: 1)

            if progress > 0.005 && progress < 0.995 {
                edgeGlow(progress: progress, shape: shape)
            }
        }
        .frame(width: pw, height: ph)
        .shadow(color: .black.opacity(0.5), radius: 15, y: 8)
    }

    // MARK: - Scorch

    private func scorchOverlay(progress: Double, shape: DiagonalBurnShape) -> some View {
        let t = 1.0 - progress
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: max(0, t - 0.18)),
                .init(color: Color(red: 0.38, green: 0.22, blue: 0.08).opacity(0.5), location: max(0, t - 0.06)),
                .init(color: Color(red: 0.15, green: 0.07, blue: 0.02).opacity(0.92), location: max(0.001, t)),
                .init(color: Color.black.opacity(0.95), location: min(1, t + 0.01)),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(shape)
    }

    // MARK: - Edge Glow

    private func edgeGlow(progress: Double, shape: DiagonalBurnShape) -> some View {
        let t = 1.0 - progress
        return LinearGradient(
            stops: [
                .init(color: .clear, location: max(0, t - 0.07)),
                .init(color: Color.orange.opacity(0.6 + 0.25 * sin(phase * 3.0)), location: max(0.001, t - 0.012)),
                .init(color: Color.red.opacity(0.35), location: t),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(shape)
    }

    // MARK: - Flame Canvas

    private func flameCanvas(pw: CGFloat, ph: CGFloat, ox: CGFloat, oy: CGFloat, progress: Double) -> some View {
        Canvas { ctx, _ in
            let pts = Self.burnLinePoints(pw: pw, ph: ph, progress: progress, phase: phase)

            let nLen = sqrt(Double(ph * ph + pw * pw))
            let nx = Double(ph) / nLen
            let ny = Double(pw) / nLen
            let tx = -ny
            let ty = nx

            for i in stride(from: 0, to: pts.count, by: 2) {
                let pt = pts[i]
                let fi = Double(i)

                let n1 = sin(fi * 0.5 + phase * 4.0) * 0.5 + 0.5
                let n2 = cos(fi * 0.9 + phase * 3.0)
                let n3 = sin(fi * 1.7 + phase * 5.0)

                let flameH = 16.0 + n1 * 24.0 + n3 * 6.0
                let flameW = 5.0 + n1 * 4.0

                let bx = Double(pt.x) + Double(ox)
                let by = Double(pt.y) + Double(oy)
                let tipX = bx + nx * flameH
                let tipY = by + ny * flameH
                let midX = bx + nx * flameH * 0.5
                let midY = by + ny * flameH * 0.5

                var flame = Path()
                flame.move(to: CGPoint(x: bx + tx * flameW * 0.5, y: by + ty * flameW * 0.5))
                flame.addQuadCurve(
                    to: CGPoint(x: tipX, y: tipY),
                    control: CGPoint(
                        x: midX + tx * flameW * 0.3 + nx * flameH * 0.12,
                        y: midY + ty * flameW * 0.3 + ny * flameH * 0.12
                    )
                )
                flame.addQuadCurve(
                    to: CGPoint(x: bx - tx * flameW * 0.5, y: by - ty * flameW * 0.5),
                    control: CGPoint(
                        x: midX - tx * flameW * 0.3 + nx * flameH * 0.12,
                        y: midY - ty * flameW * 0.3 + ny * flameH * 0.12
                    )
                )
                flame.closeSubpath()

                ctx.opacity = 0.55 + n1 * 0.45 + n2 * 0.1
                ctx.fill(flame, with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 1.0, green: 0.97, blue: 0.7),
                        Color(red: 1.0, green: 0.7, blue: 0.15),
                        Color(red: 0.95, green: 0.3, blue: 0.05).opacity(0.5),
                        Color.red.opacity(0),
                    ]),
                    startPoint: CGPoint(x: bx, y: by),
                    endPoint: CGPoint(x: tipX, y: tipY)
                ))
            }
        }
        .blur(radius: 2)
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    // MARK: - Burn Line Points

    static func burnLinePoints(pw: CGFloat, ph: CGFloat, progress: Double, phase: Double) -> [CGPoint] {
        let k = 2.0 * (1.0 - progress)
        let W = Double(pw)
        let H = Double(ph)

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

        let segments = 50
        var points: [CGPoint] = []

        for i in 0...segments {
            let t = Double(i) / Double(segments)
            let bx = startPt.0 + (endPt.0 - startPt.0) * t
            let by = startPt.1 + (endPt.1 - startPt.1) * t

            let edgeFade = min(Double(i), Double(segments - i)) / 4.0
            let fade = min(edgeFade, 1.0)

            let noise = (sin(Double(i) * 0.7 + phase * 1.5) * 8.0
                       + cos(Double(i) * 1.4 + phase * 2.2) * 5.0
                       + sin(Double(i) * 2.3 + phase * 3.0) * 3.0) * fade

            let px = max(0, min(W, bx + nx * noise))
            let py = max(0, min(H, by + ny * noise))
            points.append(CGPoint(x: px, y: py))
        }

        return points
    }

    // MARK: - Particles

    private func initParticles(pw: CGFloat, ph: CGFloat, ox: CGFloat, oy: CGFloat) {
        let pts = Self.burnLinePoints(pw: pw, ph: ph, progress: bedtimeManager.progress, phase: phase)
        embers = (0..<25).map { _ in Ember.spawn(on: pts, ox: ox, oy: oy, pw: pw, ph: ph) }
        ashes = (0..<20).map { _ in Ash.spawn(on: pts, ox: ox, oy: oy, pw: pw, ph: ph) }
    }

    private func updateParticles(pw: CGFloat, ph: CGFloat, ox: CGFloat, oy: CGFloat) {
        let pts = Self.burnLinePoints(pw: pw, ph: ph, progress: bedtimeManager.progress, phase: phase)

        let nLen = sqrt(Double(ph * ph + pw * pw))
        let nx = Double(ph) / nLen
        let ny = Double(pw) / nLen

        for i in embers.indices {
            embers[i].pos.x -= CGFloat(nx * Double(embers[i].speed))
            embers[i].pos.y -= CGFloat(ny * Double(embers[i].speed))
            embers[i].pos.x += CGFloat(sin(phase + Double(i) * 0.7) * 0.6)
            embers[i].pos.y += CGFloat(cos(phase + Double(i) * 0.5) * 0.4)
            embers[i].opacity -= 0.012
            embers[i].size *= 0.997
            if embers[i].opacity <= 0 {
                embers[i] = Ember.spawn(on: pts, ox: ox, oy: oy, pw: pw, ph: ph)
            }
        }

        for i in ashes.indices {
            ashes[i].pos.y += CGFloat(ashes[i].speed)
            ashes[i].pos.x += CGFloat(sin(phase * 0.4 + Double(i)) * 0.3)
            ashes[i].opacity -= 0.006
            if ashes[i].opacity <= 0 || ashes[i].pos.y > ph + oy + 50 {
                ashes[i] = Ash.spawn(on: pts, ox: ox, oy: oy, pw: pw, ph: ph)
            }
        }
    }
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
            opacity: .random(in: 0.15...0.4),
            speed: .random(in: 0.3...1.0),
            color: Color(red: .random(in: 0.2...0.4), green: .random(in: 0.15...0.25), blue: .random(in: 0.1...0.18))
        )
    }
}

// MARK: - Time Digit View

struct TimeDigitView: View {
    let value: Int
    let label: String

    var body: some View {
        Text(String(format: "%02d", value))
            .font(.system(size: 40, weight: .ultraLight, design: .serif))
            .foregroundColor(.orange.opacity(0.9))
            .monospacedDigit()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        BurningParchmentView()
            .environmentObject(BedtimeManager())
    }
}
