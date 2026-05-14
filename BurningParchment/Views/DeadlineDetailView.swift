// DeadlineDetailView.swift
// 데드라인 상세 — 타오르는 양피지 효과로 마감까지 남은 시간 표시

import SwiftUI

struct DeadlineDetailView: View {
    let deadline: Deadline
    @EnvironmentObject var deadlineManager: DeadlineManager
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Double = 0
    @State private var embers: [Ember] = []
    @State private var ashes:  [Ash]   = []
    @State private var currentProgress: Double
    @State private var currentRemaining: TimeInterval
    @State private var showDeleteAlert = false
    @State private var showEdit = false

    private let displayTimer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()
    private let dataTimer    = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    init(deadline: Deadline) {
        self.deadline = deadline
        _currentProgress  = State(initialValue: deadline.progress())
        _currentRemaining = State(initialValue: deadline.remaining())
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                let size = geo.size
                let pw   = size.width - 48
                let ph   = size.height * 0.46
                let ox   = (size.width - pw) / 2
                let oy: CGFloat = 72  // header 아래

                ZStack {
                    if currentProgress > 0 && currentProgress < 1 {
                        burnGlow(size: size)
                    }
                    particleLayer(items: ashes,  withGlow: false)
                    parchmentLayer(pw: pw, ph: ph, progress: currentProgress)
                        .position(x: size.width / 2, y: oy + ph / 2)
                    if currentProgress > 0.005 && currentProgress < 0.995 {
                        flameLayer(pw: pw, ph: ph, ox: ox, oy: oy)
                    }
                    particleLayer(items: embers, withGlow: true)

                    VStack {
                        headerBar
                        Spacer()
                        infoSection
                    }
                }
                .onAppear {
                    currentProgress  = deadline.progress()
                    currentRemaining = deadline.remaining()
                    let pts = BurningParchmentView.burnLinePoints(pw: pw, ph: ph, progress: currentProgress, phase: phase)
                    embers = (0..<25).map { _ in Ember.spawn(on: pts, ox: ox, oy: oy, pw: pw, ph: ph) }
                    ashes  = (0..<20).map { _ in Ash.spawn(on: pts, ox: ox, oy: oy, pw: pw, ph: ph) }
                }
                .onReceive(displayTimer) { _ in
                    phase += 0.05
                    stepParticles(pw: pw, ph: ph, ox: ox, oy: oy)
                }
                .onReceive(dataTimer) { _ in
                    currentProgress  = deadline.progress()
                    currentRemaining = deadline.remaining()
                }
            }
        }
        .alert("데드라인 삭제", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) {
                deadlineManager.delete(id: deadline.id)
                dismiss()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("'\(deadline.title)'을(를) 삭제할까요?")
        }
        .sheet(isPresented: $showEdit) {
            DeadlineFormView(editing: deadline)
                .environmentObject(deadlineManager)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }

            Spacer()

            VStack(spacing: 2) {
                Text(deadline.emoji).font(.system(size: 22))
                Text(deadline.title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundColor(.orange.opacity(0.85))
                    .lineLimit(1)
            }

            Spacer()

            Menu {
                Button { showEdit = true } label: {
                    Label("수정", systemImage: "pencil")
                }
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    Label("삭제", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: 14) {
            Text("마감까지 남은 시간")
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundColor(.orange.opacity(0.6))

            if deadline.isExpired() {
                Text("마감 완료 🏁")
                    .font(.system(size: 32, weight: .light, design: .serif))
                    .foregroundColor(.gray.opacity(0.6))
            } else {
                remainingDisplay
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
                            .fill(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * currentProgress, height: 8)
                    }
                }
                .frame(height: 8)
                Text("🏁").font(.system(size: 13))
            }
            .padding(.horizontal, 32)

            Text("\(Int((1.0 - currentProgress) * 100))% 남음")
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundColor(.gray.opacity(0.6))

            Text(deadline.targetDateString)
                .font(.system(size: 12, design: .serif))
                .foregroundColor(.gray.opacity(0.35))
        }
        .padding(.bottom, 28)
    }

    @ViewBuilder
    private var remainingDisplay: some View {
        let rem = Int(currentRemaining)
        if rem >= 86400 {
            Text(deadline.remainingString(at: Date()))
                .font(.system(size: 36, weight: .ultraLight, design: .serif))
                .foregroundColor(.orange.opacity(0.9))
        } else {
            let h = rem / 3600
            let m = (rem % 3600) / 60
            let s = rem % 60
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                TimeDigitView(value: h, label: "h")
                Text(":").font(.system(size: 34, weight: .light, design: .serif))
                    .foregroundColor(.orange.opacity(0.5))
                TimeDigitView(value: m, label: "m")
                Text(":").font(.system(size: 34, weight: .light, design: .serif))
                    .foregroundColor(.orange.opacity(0.5))
                TimeDigitView(value: s, label: "s")
            }
        }
    }

    // MARK: - Visual: Glow

    private func burnGlow(size: CGSize) -> some View {
        let k  = 2.0 * (1.0 - currentProgress)
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

    // MARK: - Visual: Particles

    private func particleLayer(items: [any Particle], withGlow: Bool) -> some View {
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

    // MARK: - Visual: Parchment

    private var parchmentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.86, green: 0.78, blue: 0.62),
                Color(red: 0.80, green: 0.70, blue: 0.54),
                Color(red: 0.73, green: 0.62, blue: 0.46),
                Color(red: 0.66, green: 0.54, blue: 0.39),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private func parchmentLayer(pw: CGFloat, ph: CGFloat, progress: Double) -> some View {
        let shape = DiagonalBurnShape(progress: progress, phase: phase)
        let t = 1.0 - progress
        return ZStack {
            shape.fill(parchmentGradient)
            if progress > 0 {
                LinearGradient(
                    stops: [
                        .init(color: .clear,                                                        location: 0),
                        .init(color: .clear,                                                        location: max(0, t - 0.18)),
                        .init(color: Color(red: 0.38, green: 0.22, blue: 0.08).opacity(0.5),       location: max(0, t - 0.06)),
                        .init(color: Color(red: 0.15, green: 0.07, blue: 0.02).opacity(0.92),      location: max(0, t)),
                        .init(color: Color.black.opacity(0.95),                                     location: min(1, t + 0.01)),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .clipShape(shape)
            }
            shape.stroke(Color.brown.opacity(0.2), lineWidth: 1)
        }
        .frame(width: pw, height: ph)
        .shadow(color: .black.opacity(0.5), radius: 15, y: 8)
    }

    // MARK: - Visual: Flame

    private func flameLayer(pw: CGFloat, ph: CGFloat, ox: CGFloat, oy: CGFloat) -> some View {
        Canvas { ctx, _ in
            let pts  = BurningParchmentView.burnLinePoints(pw: pw, ph: ph, progress: currentProgress, phase: phase)
            let nLen = sqrt(Double(ph * ph + pw * pw))
            let nx   = Double(ph) / nLen
            let ny   = Double(pw) / nLen
            let tx   = -ny
            let ty   =  nx

            for i in stride(from: 0, to: pts.count, by: 2) {
                let pt = pts[i]
                let fi = Double(i)

                let n1     = sin(fi * 0.55 + phase * 4.0) * 0.5 + 0.5
                let n2     = cos(fi * 0.90 + phase * 3.0)
                let n3     = sin(fi * 1.70 + phase * 5.5)
                let flameH = 14.0 + n1 * 26.0 + n3 * 7.0
                let flameW = 5.0  + n1 * 4.5
                let sway   = n2 * 3.0

                let bx   = Double(pt.x) + Double(ox)
                let by   = Double(pt.y) + Double(oy)
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

    // MARK: - Particles Update

    private func stepParticles(pw: CGFloat, ph: CGFloat, ox: CGFloat, oy: CGFloat) {
        let pts  = BurningParchmentView.burnLinePoints(pw: pw, ph: ph, progress: currentProgress, phase: phase)
        let nLen = sqrt(Double(ph * ph + pw * pw))
        let nx   = Double(ph) / nLen
        let ny   = Double(pw) / nLen

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
        for i in ashes.indices {
            ashes[i].pos.y += CGFloat(ashes[i].speed)
            ashes[i].pos.x += CGFloat(sin(phase * 0.4 + Double(i)) * 0.3)
            ashes[i].opacity -= 0.006
            if ashes[i].opacity <= 0 || ashes[i].pos.y > oy + ph + 50 {
                ashes[i] = Ash.spawn(on: pts, ox: ox, oy: oy, pw: pw, ph: ph)
            }
        }
    }
}
