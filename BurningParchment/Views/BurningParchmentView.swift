// BurningParchmentView.swift
// 양피지(상단) + 타이머/게이지(하단) 레이아웃
// 오른쪽 아래 모서리부터 대각선으로 타들어감

import SwiftUI

// MARK: - Main View

struct BurningParchmentView: View {
    @EnvironmentObject var bedtimeManager: BedtimeManager
    @EnvironmentObject var deadlineManager: DeadlineManager
    @State private var phase: Double = 0
    @State private var embers: [Ember] = []
    @State private var ashes: [Ash] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    private var currentDisplayProgress: Double {
        switch bedtimeManager.selectedPeriod {
        case .day: return bedtimeManager.progress
        case .deadline:
            return deadlineManager.deadlines.first(where: { !$0.isExpired() })?.progress() ?? 0
        default:
            return bedtimeManager.periodProgress
        }
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let pw = size.width - 48
            let ph = size.height * 0.48
            let ox = (size.width - pw) / 2
            let oy: CGFloat = 8
            let isDayPeriod = bedtimeManager.selectedPeriod == .day
            let displayProgress = currentDisplayProgress

            ZStack {
                if isDayPeriod && bedtimeManager.isBeforeWakeTime && bedtimeManager.remainingSeconds <= 1800 {
                    beforeWakeView(pw: pw, ph: ph, oy: oy, size: size)
                } else if isDayPeriod && (bedtimeManager.isBeforeWakeTime || (!bedtimeManager.isCountdownActive && bedtimeManager.progress >= 1.0)) {
                    bedtimeReachedView(size: size)
                } else {
                    burningView(size: size, pw: pw, ph: ph, ox: ox, oy: oy, progress: displayProgress)
                }
            }
            .onReceive(timer) { _ in
                guard !reduceMotion else { return }
                phase += 0.05
                if bedtimeManager.isCountdownActive || !isDayPeriod {
                    updateParticles(pw: pw, ph: ph, ox: ox, oy: oy)
                }
            }
            .onAppear {
                initParticles(pw: pw, ph: ph, ox: ox, oy: oy)
            }
            .onChange(of: bedtimeManager.selectedPeriod) { _ in
                initParticles(pw: pw, ph: ph, ox: ox, oy: oy)
            }
        }
    }

    // MARK: - Burning View

    private func burningView(size: CGSize, pw: CGFloat, ph: CGFloat, ox: CGFloat, oy: CGFloat, progress: Double) -> some View {
        ZStack {
            particleCanvas(items: ashes, withGlow: false)
                .accessibilityHidden(true)

            parchmentGroup(pw: pw, ph: ph, progress: progress)
                .position(x: size.width / 2, y: oy + ph / 2)
                .accessibilityHidden(true)

            ashPileCanvas(pw: pw, ph: ph, ox: ox, oy: oy, progress: progress)
                .accessibilityHidden(true)

            if progress > 0.005 && progress < 0.995 {
                diagonalFlameCanvas(pw: pw, ph: ph, ox: ox, oy: oy, progress: progress)
                    .accessibilityHidden(true)
            }

            particleCanvas(items: embers, withGlow: true)
                .accessibilityHidden(true)

            VStack {
                Spacer()
                timerSection(progress: progress, size: size)
            }
        }
    }

    // MARK: - Before Wake

    private func beforeWakeView(pw: CGFloat, ph: CGFloat, oy: CGFloat, size: CGSize) -> some View {
        ZStack {
            Rectangle()
                .fill(parchmentGradient)
                .frame(width: pw, height: ph)
                .overlay(Rectangle().stroke(Color.brown.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
                .position(x: size.width / 2, y: oy + ph / 2)
                .accessibilityHidden(true)

            VStack {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange.opacity(0.5))
                    Text("곧 기상 시간이에요")
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Text("\(sleepRemainingString) 후 양피지가 타기 시작합니다")
                        .font(.system(size: 12, design: .serif))
                        .foregroundColor(.gray.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .accessibilityElement(children: .combine)
                .padding(.bottom, 60)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("기상 전")
        .accessibilityValue("\(sleepRemainingString) 후 시작")
    }

    // MARK: - Bedtime Reached (불타는 하트)

    private func bedtimeReachedView(size: CGSize) -> some View {
        ZStack {
            // 배경 강렬한 글로우 (1층)
            RadialGradient(
                colors: [
                    Color.red.opacity(0.2 + 0.1 * sin(phase * 2.5)),
                    Color.orange.opacity(0.12 + 0.06 * sin(phase * 3.0)),
                    Color.red.opacity(0.04),
                    Color.clear
                ],
                center: .center,
                startRadius: 10,
                endRadius: 250
            )
            .ignoresSafeArea()

            // 배경 글로우 (2층 - 흔들리는 불빛)
            RadialGradient(
                colors: [
                    Color.orange.opacity(0.15 + 0.1 * sin(phase * 4.0)),
                    Color.clear
                ],
                center: UnitPoint(
                    x: 0.5 + 0.02 * sin(phase * 2.3),
                    y: 0.38 + 0.02 * cos(phase * 1.8)
                ),
                startRadius: 30,
                endRadius: 180
            )
            .ignoresSafeArea()

            // 하트 불씨 파티클 (Canvas)
            heartEmberCanvas(size: size)

            VStack(spacing: 24) {
                Spacer()

                // 불타는 하트
                ZStack {
                    // 외부 대형 글로우 (넓은 범위)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 120))
                        .foregroundStyle(
                            RadialGradient(
                                colors: [.orange.opacity(0.3), .red.opacity(0.15), .clear],
                                center: .center,
                                startRadius: 5,
                                endRadius: 60
                            )
                        )
                        .blur(radius: 35)
                        .scaleEffect(1.1 + 0.08 * sin(phase * 2.0))

                    // 중간 글로우
                    Image(systemName: "heart.fill")
                        .font(.system(size: 95))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red.opacity(0.5), .orange.opacity(0.4), .yellow.opacity(0.2)],
                                startPoint: .bottom, endPoint: .top
                            )
                        )
                        .blur(radius: 18)
                        .scaleEffect(1.05 + 0.06 * sin(phase * 2.8))

                    // 하트 본체
                    Image(systemName: "heart.fill")
                        .font(.system(size: 75))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.7, green: 0.05, blue: 0.05),
                                    Color(red: 0.95, green: 0.3, blue: 0.05),
                                    Color(red: 1.0, green: 0.6, blue: 0.1),
                                    Color(red: 1.0, green: 0.85, blue: 0.3)
                                ],
                                startPoint: .bottom, endPoint: .top
                            )
                        )
                        .scaleEffect(1.0 + 0.03 * sin(phase * 3.0))

                    // 중앙 대형 불꽃
                    Image(systemName: "flame.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.95, blue: 0.7),
                                    .yellow,
                                    .orange.opacity(0.7),
                                    .red.opacity(0.2)
                                ],
                                startPoint: .bottom, endPoint: .top
                            )
                        )
                        .offset(y: -50 + sin(phase * 3.5) * 5)
                        .scaleEffect(1.0 + 0.2 * sin(phase * 4.5))
                        .blur(radius: 1.5)

                    // 좌상 불꽃 (크게)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow.opacity(0.9), .orange, .red.opacity(0.3)],
                                startPoint: .bottom, endPoint: .top
                            )
                        )
                        .offset(x: -22, y: -42 + sin(phase * 4.0) * 4)
                        .scaleEffect(0.85 + 0.25 * sin(phase * 3.8))
                        .opacity(0.7 + 0.3 * sin(phase * 3.2))
                        .blur(radius: 0.5)

                    // 우상 불꽃 (크게)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow.opacity(0.8), .orange, .red.opacity(0.3)],
                                startPoint: .bottom, endPoint: .top
                            )
                        )
                        .offset(x: 25, y: -45 + cos(phase * 3.7) * 5)
                        .scaleEffect(0.8 + 0.3 * sin(phase * 4.2))
                        .opacity(0.6 + 0.35 * cos(phase * 3.5))
                        .blur(radius: 0.5)

                    // 좌측 측면 불꽃
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.orange.opacity(0.7))
                        .offset(x: -35, y: -18 + sin(phase * 5.0) * 3)
                        .scaleEffect(0.7 + 0.3 * sin(phase * 4.5))
                        .opacity(0.4 + 0.4 * sin(phase * 3.0))
                        .rotationEffect(.degrees(-15 + sin(phase * 2.5) * 10))

                    // 우측 측면 불꽃
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange.opacity(0.6))
                        .offset(x: 37, y: -22 + cos(phase * 4.8) * 3)
                        .scaleEffect(0.65 + 0.35 * cos(phase * 5.0))
                        .opacity(0.35 + 0.4 * cos(phase * 2.8))
                        .rotationEffect(.degrees(15 + cos(phase * 2.3) * 10))

                    // 상단 떠오르는 작은 불씨
                    Image(systemName: "flame")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow.opacity(0.6))
                        .offset(
                            x: -10 + sin(phase * 2.0) * 5,
                            y: -65 + sin(phase * 3.0) * 6
                        )
                        .scaleEffect(0.6 + 0.4 * sin(phase * 5.5))
                        .opacity(0.3 + 0.4 * sin(phase * 4.0))

                    Image(systemName: "flame")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow.opacity(0.5))
                        .offset(
                            x: 12 + cos(phase * 2.5) * 4,
                            y: -70 + cos(phase * 3.5) * 5
                        )
                        .scaleEffect(0.5 + 0.4 * cos(phase * 6.0))
                        .opacity(0.25 + 0.35 * cos(phase * 4.5))
                }

                Text("수면 중")
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundColor(.orange.opacity(0.7))

                Text("🌙 좋은 꿈 꾸세요")
                    .font(.system(size: 15, design: .serif))
                    .foregroundColor(.gray.opacity(0.5))

                if bedtimeManager.isBeforeWakeTime {
                    Text("기상까지 \(sleepRemainingString)")
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(.gray.opacity(0.4))
                        .padding(.top, 4)
                }

                Spacer()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("수면 중")
        .accessibilityValue(bedtimeManager.isBeforeWakeTime
            ? "기상까지 \(sleepRemainingString)"
            : "좋은 꿈 꾸세요")
    }

    // MARK: - Heart Ember Canvas (하트 불씨 파티클)

    private func heartEmberCanvas(size: CGSize) -> some View {
        Canvas { ctx, canvasSize in
            let cx = canvasSize.width / 2
            let cy = canvasSize.height * 0.38

            for i in 0..<35 {
                let fi = Double(i)
                let seed = fi * 137.508

                let cycle = (phase * 0.8 + seed)
                    .truncatingRemainder(dividingBy: 4.0) / 4.0

                let startX = cx + CGFloat(sin(seed) * 30 + cos(seed * 0.7) * 15)
                let startY = cy + CGFloat(cos(seed * 0.5) * 20)

                let px = startX + CGFloat(sin(fi * 0.9 + phase * 1.5) * 12 * cycle)
                let py = startY - CGFloat(cycle * 80 + cycle * cycle * 40)

                let opacity = (1.0 - cycle) * (0.5 + 0.5 * sin(fi * 2.3 + phase * 3.0))
                let pSize = (1.0 - cycle) * (2.0 + sin(fi * 1.7) * 1.5)

                guard opacity > 0.05 && pSize > 0.3 else { continue }

                // 글로우
                let gr = pSize * 2.0
                ctx.opacity = opacity * 0.3
                ctx.fill(
                    Path(ellipseIn: CGRect(
                        x: px - CGFloat(gr), y: py - CGFloat(gr),
                        width: CGFloat(gr * 2), height: CGFloat(gr * 2)
                    )),
                    with: .color(.orange)
                )

                // 코어
                ctx.opacity = opacity
                let r = pSize / 2
                let colors: [Color] = [.yellow, .orange, Color(red: 1, green: 0.85, blue: 0.4)]
                ctx.fill(
                    Path(ellipseIn: CGRect(
                        x: px - CGFloat(r), y: py - CGFloat(r),
                        width: CGFloat(pSize), height: CGFloat(pSize)
                    )),
                    with: .color(colors[i % colors.count])
                )
            }
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    // MARK: - Timer Section (하단)

    private func timerSection(progress: Double, size: CGSize) -> some View {
        let nearestDeadline: Deadline? = bedtimeManager.selectedPeriod == .deadline
            ? deadlineManager.deadlines.first(where: { !$0.isExpired() })
            : nil

        let startLabel = bedtimeManager.periodStartLabel
        let endLabel   = nearestDeadline?.targetDateString ?? bedtimeManager.periodEndLabel
        let startIcon  = bedtimeManager.periodStartIcon
        let endIcon    = nearestDeadline != nil ? "flag.fill" : bedtimeManager.periodEndIcon
        let remaining  = 1.0 - progress

        return VStack(spacing: 12) {
            // 타이머 텍스트
            VStack(spacing: 4) {
                if let dl = nearestDeadline {
                    Text("\(dl.emoji) \(dl.title)")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundColor(.orange.opacity(0.6))
                        .lineLimit(1)
                    Text(dl.remainingString())
                        .font(.system(size: 36, weight: .ultraLight, design: .serif))
                        .foregroundColor(.orange.opacity(0.9))
                } else {
                    Text(bedtimeManager.periodLabel)
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundColor(.orange.opacity(0.6))

                    Text(bedtimeManager.selectedPeriod == .day
                            ? bedtimeManager.remainingKoreanString
                            : bedtimeManager.periodRemainingString)
                        .font(.system(size: 30, weight: .ultraLight, design: .serif))
                        .foregroundColor(.orange.opacity(0.9))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }

            // 게이지 바 — 왼쪽부터 사라지는 방향 (trailing 정렬)
            GeometryReader { geo in
                ZStack(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [.orange, .red.opacity(0.85)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * remaining, height: 8)
                        .animation(.linear(duration: 1.0), value: remaining)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 32)

            // 날짜 범위 + 남은 비율 (바 바로 아래)
            VStack(spacing: 4) {
                HStack {
                    HStack(spacing: 3) {
                        Image(systemName: startIcon).font(.system(size: 10))
                        Text(startLabel).font(.system(size: 10, design: .serif))
                    }
                    .foregroundColor(.orange.opacity(0.45))

                    Spacer()

                    HStack(spacing: 3) {
                        Text(endLabel).font(.system(size: 10, design: .serif))
                        Image(systemName: endIcon).font(.system(size: 10))
                    }
                    .foregroundColor(.orange.opacity(0.45))
                }
                .padding(.horizontal, 32)

                Text("\(Int(remaining * 100))% 남음")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
        .padding(.bottom, 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            if let dl = nearestDeadline { return String(localized: "\(dl.emoji) \(dl.title) 데드라인") }
            return bedtimeManager.periodLabel
        }())
        .accessibilityValue({
            let pct = Int(remaining * 100)
            if let dl = nearestDeadline { return String(localized: "\(dl.remainingString()), \(pct)% 남음") }
            let time = bedtimeManager.selectedPeriod == .day
                ? bedtimeManager.remainingKoreanString
                : bedtimeManager.periodRemainingString
            return String(localized: "\(time), \(pct)% 남음")
        }())
    }

    // MARK: - Sleep Remaining String
    private var sleepRemainingString: String {
        let totalSec = Int(bedtimeManager.remainingSeconds)
        let h = totalSec / 3600
        let m = (totalSec % 3600) / 60
        if h > 0 { return String(localized: "\(h)시간 \(m)분") }
        return String(localized: "\(m)분")
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
                Color.orange.opacity(0.28 + 0.10 * sin(phase * 2.0)),
                Color.red.opacity(0.14),
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
            if progress > 0 { scorchOverlay(progress: progress, shape: shape) }
            shape.stroke(Color.brown.opacity(0.2), lineWidth: 1)
        }
        .frame(width: pw, height: ph)
        .shadow(color: .black.opacity(0.5), radius: 15, y: 8)
    }

    // MARK: - Scorch

    private func scorchOverlay(progress: Double, shape: DiagonalBurnShape) -> some View {
        let t = 1.0 - progress
        return LinearGradient(
            stops: [
                .init(color: .clear,                                                         location: 0),
                .init(color: .clear,                                                         location: max(0, t - 0.18)),
                .init(color: Color(red: 0.38, green: 0.22, blue: 0.08).opacity(0.5),        location: max(0, t - 0.06)),
                .init(color: Color(red: 0.15, green: 0.07, blue: 0.02).opacity(0.92),       location: max(0.001, t)),
                .init(color: Color.black.opacity(0.95),                                      location: min(1, t + 0.01)),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .clipShape(shape)
    }

    // MARK: - Ash Pile (쌓이는 재 무더기)

    /// 양피지 바닥에서 재 더미 바닥(보이지 않는 지면)까지의 거리
    static let ashPileDropOffset: Double = 58

    /// 재 더미 표면 높이 — t(0~1, 가로 위치)와 진행도로 결정.
    /// 연소가 시작되는 오른쪽에 먼저 쌓이다가, 다 타면 중앙 쪽에 한 줌의 봉우리로 남는다.
    static func ashPileHeight(t: Double, progress: Double) -> Double {
        guard progress > 0.02 else { return 0 }
        let center = 0.80 - 0.22 * progress
        let sigma  = 0.15 + 0.11 * progress
        let gauss  = exp(-pow(t - center, 2) / (2 * sigma * sigma))
        let lump   = fbm(t * 6.3 + 11.3, 3.7, octaves: 3)
        let maxH   = 10.0 + 30.0 * progress
        return max(0, maxH * gauss * (1.0 + 0.35 * lump))
    }

    private func ashPileCanvas(pw: CGFloat, ph: CGFloat, ox: CGFloat, oy: CGFloat, progress: Double) -> some View {
        Canvas { ctx, _ in
            guard progress > 0.02 else { return }
            let baseY = Double(oy + ph) + Self.ashPileDropOffset
            let W = Double(pw)
            let X = Double(ox)
            let segments = 64

            // 바닥 그림자 — 무더기가 지면 위에 놓인 느낌
            let center = 0.80 - 0.22 * progress
            let shadowW = W * (0.30 + 0.45 * progress)
            let shadowH = 7.0 + 5.0 * progress
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 5))
                layer.opacity = 0.35
                layer.fill(
                    Path(ellipseIn: CGRect(
                        x: X + W * center - shadowW / 2,
                        y: baseY - shadowH / 2,
                        width: shadowW, height: shadowH
                    )),
                    with: .color(.black)
                )
            }

            // 무더기 본체
            var mound = Path()
            mound.move(to: CGPoint(x: X, y: baseY))
            for i in 0...segments {
                let t = Double(i) / Double(segments)
                let h = Self.ashPileHeight(t: t, progress: progress)
                mound.addLine(to: CGPoint(x: X + W * t, y: baseY - h))
            }
            mound.addLine(to: CGPoint(x: X + W, y: baseY))
            mound.closeSubpath()

            let peakH = 10.0 + 30.0 * progress
            ctx.opacity = 1.0
            ctx.fill(mound, with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.44, green: 0.40, blue: 0.36),
                    Color(red: 0.28, green: 0.24, blue: 0.20),
                    Color(red: 0.10, green: 0.08, blue: 0.06),
                ]),
                startPoint: CGPoint(x: X + W * 0.5, y: baseY - peakH),
                endPoint:   CGPoint(x: X + W * 0.5, y: baseY)
            ))

            // 표면 잔재 얼룩 (밝은 재 조각들)
            for j in 0..<18 {
                let fj = Double(j)
                let tx = Self.hash2D(fj, 1.0)
                let h = Self.ashPileHeight(t: tx, progress: progress)
                guard h > 5 else { continue }
                let depth = Self.hash2D(fj, 2.0) * 0.65
                let px = X + W * tx
                let py = baseY - h * (1.0 - depth) + 1.5
                let s = 1.0 + Self.hash2D(fj, 3.0) * 1.8
                let g = 0.40 + Self.hash2D(fj, 4.0) * 0.22
                ctx.opacity = 0.5 + Self.hash2D(fj, 5.0) * 0.3
                ctx.fill(
                    Path(ellipseIn: CGRect(x: px - s / 2, y: py - s / 2, width: s, height: s)),
                    with: .color(Color(red: g, green: g * 0.94, blue: g * 0.86))
                )
            }

            // 아직 타는 중이면 무더기 속 잔불이 깜빡인다
            if progress < 0.995 {
                let leadT = min(0.92, 0.85 - 0.20 * progress)
                for j in 0..<6 {
                    let fj = Double(j)
                    let tx = leadT + (Self.hash2D(fj, 7.0) - 0.5) * 0.35
                    guard tx > 0, tx < 1 else { continue }
                    let h = Self.ashPileHeight(t: tx, progress: progress)
                    guard h > 4 else { continue }
                    let flicker = 0.5 + 0.5 * sin(phase * 3.0 + fj * 2.1)
                    let px = X + W * tx
                    let py = baseY - h + 2.0 + Self.hash2D(fj, 8.0) * 3.0
                    let s = 1.2 + flicker * 1.2

                    ctx.opacity = flicker * 0.25
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - s * 1.6, y: py - s * 1.6, width: s * 3.2, height: s * 3.2)),
                        with: .color(.orange)
                    )
                    ctx.opacity = 0.25 + flicker * 0.55
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - s / 2, y: py - s / 2, width: s, height: s)),
                        with: .color(Color(red: 1.0, green: 0.55 + flicker * 0.3, blue: 0.15))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Diagonal Flame Canvas (유기적 불꽃 - 직선 그라디언트 없음)

    private func diagonalFlameCanvas(pw: CGFloat, ph: CGFloat, ox: CGFloat, oy: CGFloat, progress: Double) -> some View {
        Canvas { ctx, _ in
            let pts = Self.burnLinePoints(pw: pw, ph: ph, progress: progress, phase: phase)

            let nLen = sqrt(Double(ph * ph + pw * pw))
            let nx = Double(ph) / nLen
            let ny = Double(pw) / nLen
            let tx = -ny
            let ty =  nx

            for i in stride(from: 0, to: pts.count, by: 2) {
                let pt = pts[i]
                let fi = Double(i)

                let n1 = sin(fi * 0.55 + phase * 4.0) * 0.5 + 0.5
                let n2 = cos(fi * 0.90 + phase * 3.0)
                let n3 = sin(fi * 1.70 + phase * 5.5)

                let flameH = 14.0 + n1 * 26.0 + n3 * 7.0
                let flameW =  5.0 + n1 *  4.5
                let sway   = n2 * 3.0

                let bx  = Double(pt.x) + Double(ox)
                let by  = Double(pt.y) + Double(oy)
                let tipX = bx + nx * flameH + tx * sway
                let tipY = by + ny * flameH + ty * sway

                let midX = bx + nx * flameH * 0.45
                let midY = by + ny * flameH * 0.45
                let ctrl1 = CGPoint(x: midX + tx * (flameW * 0.25 + sway * 0.5),
                                    y: midY + ty * (flameW * 0.25 + sway * 0.5))
                let ctrl2 = CGPoint(x: midX - tx * (flameW * 0.25 - sway * 0.5),
                                    y: midY - ty * (flameW * 0.25 - sway * 0.5))

                var flame = Path()
                flame.move(to: CGPoint(x: bx + tx * flameW * 0.5, y: by + ty * flameW * 0.5))
                flame.addQuadCurve(to: CGPoint(x: tipX, y: tipY), control: ctrl1)
                flame.addQuadCurve(to: CGPoint(x: bx - tx * flameW * 0.5, y: by - ty * flameW * 0.5), control: ctrl2)
                flame.closeSubpath()

                ctx.opacity = 0.55 + n1 * 0.45 + n2 * 0.10
                ctx.fill(flame, with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 1.0, green: 0.97, blue: 0.72),
                        Color(red: 1.0, green: 0.68, blue: 0.12),
                        Color(red: 0.95, green: 0.28, blue: 0.04).opacity(0.50),
                        .clear,
                    ]),
                    startPoint: CGPoint(x: bx, y: by),
                    endPoint:   CGPoint(x: tipX, y: tipY)
                ))
            }
        }
        .blur(radius: 2.5)
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    // MARK: - 2D Value Noise & fBm

    private static func hash2D(_ x: Double, _ y: Double) -> Double {
        var v = sin(x * 127.1 + y * 311.7) * 43758.5453123
        v = v - floor(v)
        return v
    }

    private static func valueNoise2D(_ x: Double, _ y: Double) -> Double {
        let ix = floor(x), iy = floor(y)
        let fx = x - ix, fy = y - iy
        let ux = fx * fx * (3.0 - 2.0 * fx)
        let uy = fy * fy * (3.0 - 2.0 * fy)
        let a = hash2D(ix, iy)
        let b = hash2D(ix + 1, iy)
        let c = hash2D(ix, iy + 1)
        let d = hash2D(ix + 1, iy + 1)
        return a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy
    }

    private static func fbm(_ x: Double, _ y: Double, octaves: Int = 5) -> Double {
        var value = 0.0, amp = 0.5, freq = 1.0
        for _ in 0..<octaves {
            value += amp * (valueNoise2D(x * freq, y * freq) * 2.0 - 1.0)
            amp *= 0.5; freq *= 2.0
        }
        return value
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

        let segments = 80
        var points: [CGPoint] = []

        for i in 0...segments {
            let t = Double(i) / Double(segments)
            let bx = startPt.0 + (endPt.0 - startPt.0) * t
            let by = startPt.1 + (endPt.1 - startPt.1) * t

            let edgeFade = min(Double(i), Double(segments - i)) / 6.0
            let fade = min(edgeFade, 1.0)

            // 위치 기반 2D fBm → 종이 밀도/두께 시뮬레이션 (안정적 패턴)
            let scale = 0.018
            let staticNoise = fbm(bx * scale + 3.7, by * scale + 7.1)

            // 작은 애니메이션 노이즈 → 불꽃이 살아있는 느낌
            let flicker = sin(Double(i) * 0.6 + phase * 2.0) * 2.5
                        + cos(Double(i) * 1.1 + phase * 3.0) * 1.5

            let noise = (staticNoise * 45.0 + flicker) * fade

            let px = max(0, min(W, bx + nx * noise))
            let py = max(0, min(H, by + ny * noise))
            points.append(CGPoint(x: px, y: py))
        }

        return points
    }

    // MARK: - Horizontal Burn Points

    static func horizontalBurnPoints(pw: CGFloat, ph: CGFloat, ox: CGFloat, oy: CGFloat, progress: Double, phase: Double) -> [CGPoint] {
        let burnY = ph * (1.0 - progress)
        let count = 40
        var pts: [CGPoint] = []
        for i in 0...count {
            let t = Double(i) / Double(count)
            let jitter = sin(Double(i) * 1.4 + phase * 2.2) * 2.5
                       + cos(Double(i) * 0.8 + phase * 1.7) * 1.5
            pts.append(CGPoint(x: ox + pw * t, y: oy + burnY + CGFloat(jitter)))
        }
        return pts
    }

    // MARK: - Particles

    private func initParticles(pw: CGFloat, ph: CGFloat, ox: CGFloat, oy: CGFloat) {
        let p = currentDisplayProgress
        let pts = Self.burnLinePoints(pw: pw, ph: ph, progress: p, phase: phase)
        embers = (0..<25).map { _ in Ember.spawn(on: pts, ox: ox, oy: oy, pw: pw, ph: ph) }
        ashes  = (0..<30).map { _ in Ash.spawn(on: pts, ox: ox, oy: oy, pw: pw, ph: ph) }
    }

    private func updateParticles(pw: CGFloat, ph: CGFloat, ox: CGFloat, oy: CGFloat) {
        let p = currentDisplayProgress
        let pts = Self.burnLinePoints(pw: pw, ph: ph, progress: p, phase: phase)

        let nLen = sqrt(Double(ph * ph + pw * pw))
        let nx = Double(ph) / nLen
        let ny = Double(pw) / nLen

        for i in embers.indices {
            embers[i].pos.x -= CGFloat(nx * Double(embers[i].speed))
            embers[i].pos.y -= CGFloat(ny * Double(embers[i].speed))
            embers[i].pos.x += CGFloat(sin(phase + Double(i) * 0.7) * 0.6)
            embers[i].pos.y += CGFloat(cos(phase + Double(i) * 0.5) * 0.4)
            embers[i].opacity -= 0.012
            embers[i].size    *= 0.997
            if embers[i].opacity <= 0 {
                embers[i] = Ember.spawn(on: pts, ox: ox, oy: oy, pw: pw, ph: ph)
            }
        }

        let pileBaseY = Double(oy + ph) + Self.ashPileDropOffset
        for i in ashes.indices {
            let a = ashes[i]
            // 나풀거리며 낙하 — 좌우로 흔들리고, 낙하 속도도 함께 출렁인다
            ashes[i].pos.y += a.speed * (0.7 + 0.3 * CGFloat(sin(phase * a.swayFreq * 1.6 + a.swayPhase)))
            ashes[i].pos.x += a.swayAmp * 0.35 * CGFloat(sin(phase * a.swayFreq + a.swayPhase))
            ashes[i].opacity -= 0.0025

            // 재 더미 표면에 닿으면 그 자리에 스며든다
            let t = Double((ashes[i].pos.x - ox) / pw)
            let surfaceY = pileBaseY - Self.ashPileHeight(t: min(max(t, 0), 1), progress: p)
            let landed = Double(ashes[i].pos.y) >= surfaceY

            if ashes[i].opacity <= 0 || landed || Double(ashes[i].pos.y) > pileBaseY + 20 {
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
            .environmentObject(DeadlineManager())
    }
}
