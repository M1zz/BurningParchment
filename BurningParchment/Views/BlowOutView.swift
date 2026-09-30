// BlowOutView.swift
// 타고 있는 양피지에 "후" 불어 불을 끈다.
//   취침 30분 전 ~ 취침: 오늘의 양피지 — 남은 조각은 아침까지 식혀 두고, 뒷면은 아침에 적는다
//   취침 이후:            내일의 양피지 — 끈 자리에서 멈춘다 (그을음은 아침에 확인된 만큼만 남는다)

import SwiftUI
import Combine

struct BlowOutView: View {
    @EnvironmentObject var bedtimeManager:  BedtimeManager
    @EnvironmentObject var fragmentManager: FragmentManager
    @EnvironmentObject var nightManager:    NightManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var detector = BlowDetector()

    private enum Stage { case blowing, extinguished }
    @State private var stage: Stage = .blowing
    @State private var phase: Double = 0
    @State private var smoke: [Smoke] = []
    /// 조각 가장자리의 모양. 타는 동안 흔들리지 않게 한 번 정해 두고, 끈 조각에도 그대로 남긴다.
    @State private var edgeSeed = Double.random(in: 0...100)
    @State private var scrapSize: CGSize = .zero

    // 불이 꺼진 순간의 모습 — 조각은 이 값으로 만든다
    @State private var snapshot: Snapshot?

    private struct Snapshot {
        let bedDate: Date
        let burnProgress: Double
        let remainingSeconds: TimeInterval
        let edgePhase: Double
    }

    /// 지금 끄는 게 내일의 양피지인가 (취침 이후). 화면을 연 순간의 밤으로 고정한다.
    @State private var night: DateInterval?
    @State private var targetFixed = false

    private var liveProgress: Double {
        if let night {
            return nightManager.record(forBedtime: night.start)?.liveBurnProgress(now: Date())
                ?? min(max(Date().timeIntervalSince(night.start) / max(night.duration, 1), 0), 1)
        }
        return bedtimeManager.progress
    }

    /// 조각 둘레의 여백 — 불꽃과 연기가 뻗을 자리
    private static let flameRoom: CGFloat = 44

    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            burningStage
        }
        .onAppear {
            guard !targetFixed else { return }
            targetFixed = true
            night = bedtimeManager.currentNight
        }
        .onReceive(timer) { _ in tick() }
        .task { await detector.start() }
        .onDisappear { detector.stop() }
        .onChange(of: detector.extinguish) { _, value in
            if value >= 1 { putOut() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard stage == .blowing else { return }
            if newPhase == .active {
                Task { await detector.start() }
            } else {
                detector.stop()
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: stage == .extinguished) { _, isOut in isOut }
    }

    // MARK: - 불 끄기

    private var burningStage: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if stage == .blowing {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.inkMuted.opacity(0.7))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("닫기")
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 12)

            // 취침 30분 전이면 양피지는 모서리만 남아 있어서, 양피지 전체를 그리면 끌 불이 안 보인다.
            // 남은 조각을 크게 띄우고 그 타는 가장자리에 불꽃을 얹는다 — 끈 뒤 모아두는 조각과 같은 모양이다.
            GeometryReader { geo in
                let room = Self.flameRoom
                let inner = CGSize(width: max(geo.size.width - room * 2, 1),
                                   height: max(geo.size.height - room * 2, 1))
                let progress = snapshot?.burnProgress ?? liveProgress
                let edge = FragmentScrapView.edgePoints(burnProgress: progress, edgePhase: edgeSeed, in: inner)
                    .map { CGPoint(x: $0.x + room, y: $0.y + room) }

                ZStack {
                    FragmentScrapView(burnProgress: progress, edgePhase: edgeSeed)
                        .padding(room)

                    BurningParchmentView.flameCanvas(
                        along: edge,
                        normal: FragmentScrapView.edgeNormal,
                        phase: phase,
                        intensity: stage == .blowing ? 1 - detector.extinguish * 0.9 : 0,
                        breath: detector.breath,
                        scale: 1.5
                    )

                    smokeCanvas
                }
                .onAppear { scrapSize = geo.size }
                .onChange(of: geo.size) { _, size in scrapSize = size }
            }
            .accessibilityHidden(true)

            instructions
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
        }
    }

    @ViewBuilder
    private var instructions: some View {
        VStack(spacing: 14) {
            if stage == .extinguished {
                Text("불이 꺼졌어요")
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundColor(.ember.opacity(0.9))
                Text(night == nil
                     ? "남은 조각은 아침까지 식혀 둘게요.\n뒷면의 한 줄은 내일 아침에 적어요"
                     : "내일의 양피지가 여기서 멈췄어요.\n좋은 꿈 꾸세요")
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.inkMuted.opacity(0.8))
                    .multilineTextAlignment(.center)
                Button { dismiss() } label: {
                    Text("잘 자요")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.onEmber)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 36)
                        .background(Capsule().fill(Color.ember))
                }
                .padding(.top, 6)
            } else {
                Text(detector.availability == .unavailable
                     ? "마이크를 켜야 불을 끌 수 있어요"
                     : "화면 아래 마이크에 대고 후 불어 주세요")
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundColor(.ember.opacity(0.9))
                    .multilineTextAlignment(.center)
                if night != nil {
                    Text("내일의 양피지가 타고 있어요")
                        .font(.system(.body, design: .serif))
                        .foregroundColor(.inkMuted.opacity(0.8))
                } else {
                    Text("취침까지 \(bedtimeManager.remainingKoreanString)")
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(.inkMuted.opacity(0.7))
                        .monospacedDigit()
                }
                if detector.availability == .unavailable {
                    // 불은 입김으로만 꺼진다 — 누르기 같은 다른 길은 두지 않는다
                    Text("입김의 세기만 확인하고 소리는 녹음하지 않아요")
                        .font(.system(size: 11))
                        .foregroundColor(.inkMuted.opacity(0.5))
                        .multilineTextAlignment(.center)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("설정에서 마이크 켜기")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.ember.opacity(0.85))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 18)
                            .background(Capsule().stroke(Color.ember.opacity(0.35), lineWidth: 1))
                    }
                    .padding(.top, 6)
                }
            }
        }
        .frame(minHeight: 150)
    }

    // MARK: - Actions

    private func putOut() {
        guard stage == .blowing else { return }
        detector.stop()
        let now = Date()
        snapshot = Snapshot(
            bedDate: night?.start ?? bedtimeManager.currentBedDate,
            burnProgress: liveProgress,
            remainingSeconds: bedtimeManager.remainingSeconds,
            edgePhase: edgeSeed
        )
        if let night {
            nightManager.markExtinguished(in: night, at: now)
        } else if let snap = snapshot {
            // 뒷면은 비워 둔 채 모아둔다 — 아침에 식은 조각을 뒤집어 적는다
            fragmentManager.add(ParchmentFragment(
                bedtimeDate: snap.bedDate,
                extinguishedAt: now,
                burnProgress: snap.burnProgress,
                remainingSeconds: snap.remainingSeconds,
                edgePhase: snap.edgePhase
            ))
        }
        if !reduceMotion { spawnSmoke() }
        withAnimation(.easeOut(duration: 0.4)) { stage = .extinguished }
    }

    // MARK: - 연기

    private struct Smoke {
        var pos: CGPoint
        var size: CGFloat
        var opacity: Double
        var rise: CGFloat
        var drift: CGFloat
        var delay: Int
    }

    private func tick() {
        if stage == .blowing && !reduceMotion { phase += 0.05 }
        guard !smoke.isEmpty else { return }
        // 불꽃이 뻗던 쪽(타 버린 쪽)으로 피어오른다 — 조각 위로는 올라가지 않는다
        let nx = FragmentScrapView.edgeNormal.dx, ny = FragmentScrapView.edgeNormal.dy
        for i in smoke.indices {
            if smoke[i].delay > 0 { smoke[i].delay -= 1; continue }
            let wobble = CGFloat(sin(Double(smoke[i].pos.x + smoke[i].pos.y) * 0.05)) * 0.6
            smoke[i].pos.x += nx * smoke[i].rise + ny * (smoke[i].drift + wobble)
            smoke[i].pos.y += ny * smoke[i].rise - nx * (smoke[i].drift + wobble)
            smoke[i].size *= 1.012
            smoke[i].opacity -= 0.006
        }
        smoke.removeAll { $0.opacity <= 0 }
    }

    /// 불꽃이 있던 경계선 여기저기서 가는 연기가 피어오른다
    private func spawnSmoke() {
        guard let snap = snapshot, scrapSize.width > 0 else { return }
        let room = Self.flameRoom
        let inner = CGSize(width: scrapSize.width - room * 2, height: scrapSize.height - room * 2)
        let pts = FragmentScrapView.edgePoints(burnProgress: snap.burnProgress, edgePhase: snap.edgePhase, in: inner)
            .map { CGPoint(x: $0.x + room, y: $0.y + room) }
        smoke = (0..<46).map { i in
            let pt = pts.randomElement() ?? CGPoint(x: scrapSize.width / 2, y: scrapSize.height / 2)
            return Smoke(
                pos: CGPoint(x: pt.x + .random(in: -4...4), y: pt.y),
                size: .random(in: 6...14),
                opacity: .random(in: 0.35...0.6),
                rise: .random(in: 0.5...1.4),
                drift: .random(in: -0.3...0.3),
                delay: i / 3
            )
        }
    }

    private var smokeCanvas: some View {
        Canvas { ctx, _ in
            ctx.addFilter(.blur(radius: 6))
            for s in smoke where s.delay == 0 {
                ctx.opacity = s.opacity
                ctx.fill(
                    Path(ellipseIn: CGRect(x: s.pos.x - s.size / 2, y: s.pos.y - s.size / 2,
                                           width: s.size, height: s.size)),
                    with: .color(Color(white: 0.62))
                )
            }
        }
        .allowsHitTesting(false)
    }
}
