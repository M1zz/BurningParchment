// ContentView.swift
// 메인 화면

import SwiftUI
import WidgetKit

struct ContentView: View {
    @EnvironmentObject var bedtimeManager:    BedtimeManager
    @EnvironmentObject var deadlineManager:   DeadlineManager
    @EnvironmentObject var reflectionManager: ReflectionManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings    = false
    @State private var showDeadlines   = false
    @State private var showReflections = false
    @State private var autoOpenReflectionInput = false
    @State private var showReflectionNudge = false
    @State private var nudgeEvaluatedThisSession = false
    @AppStorage("reflectionNudgeDismissedDate") private var nudgeDismissedISO: String = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let nudgeWindowSeconds: Double = 5400  // 취침 90분 전부터
    private static let nudgeAutoHideSeconds: Double = 9

    private var pages: [PeriodType] {
        let basePeriods: [PeriodType] = [.day, .week, .month, .year]
            .filter { !bedtimeManager.hiddenPeriods.contains($0.rawValue) }
        let nearestDeadline = deadlineManager.deadlines.first(where: { !$0.isExpired() })
        return basePeriods + (nearestDeadline != nil ? [.deadline] : [])
    }

    private var currentIndex: Int {
        pages.firstIndex(of: bedtimeManager.selectedPeriod) ?? 0
    }

    @ViewBuilder
    private var fullScreenGlow: some View {
        let progress: Double = {
            switch bedtimeManager.selectedPeriod {
            case .day:      return bedtimeManager.progress
            case .deadline: return deadlineManager.deadlines.first(where: { !$0.isExpired() })?.progress() ?? 0
            default:        return bedtimeManager.periodProgress
            }
        }()
        let k = 2.0 * (1.0 - progress)
        RadialGradient(
            colors: [
                Color.orange.opacity(0.18 + progress * 0.07),
                Color.red.opacity(0.07),
                Color.clear
            ],
            center: UnitPoint(
                x: min(1.0, max(0.3, 1.0 - k * 0.25)),
                y: min(0.5, max(0.1, 0.5 - k * 0.15))
            ),
            startRadius: 10,
            endRadius: 500
        )
        .ignoresSafeArea()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if bedtimeManager.selectedPeriod != .day || bedtimeManager.isCountdownActive {
                    fullScreenGlow
                        .accessibilityHidden(true)
                }

                VStack(spacing: 0) {
                    headerBar
                    BurningParchmentView()
                        .environmentObject(bedtimeManager)
                        .gesture(
                            DragGesture(minimumDistance: 30)
                                .onEnded { value in
                                    let dx = value.translation.width
                                    let dy = value.translation.height
                                    guard abs(dx) > abs(dy) * 1.5 else { return }
                                    let idx = currentIndex
                                    if dx < 0, idx < pages.count - 1 {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            bedtimeManager.selectedPeriod = pages[idx + 1]
                                        }
                                    } else if dx > 0, idx > 0 {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            bedtimeManager.selectedPeriod = pages[idx - 1]
                                        }
                                    }
                                }
                        )
                    reflectionNudgeBanner
                    pageIndicator
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showReflections) {
                ReflectionUrnView(autoOpenInput: autoOpenReflectionInput)
                    .environmentObject(reflectionManager)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(bedtimeManager)
        }
        .sheet(isPresented: $showDeadlines) {
            DeadlineListView()
                .environmentObject(deadlineManager)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                bedtimeManager.recalculate()
                WidgetCenter.shared.reloadAllTimelines()
                if bedtimeManager.selectedPeriod == .deadline &&
                   deadlineManager.deadlines.filter({ !$0.isExpired() }).isEmpty {
                    bedtimeManager.selectedPeriod = .day
                }
                nudgeEvaluatedThisSession = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    evaluateReflectionNudge()
                }
            }
        }
        .onChange(of: bedtimeManager.isCountdownActive) { active in
            if active { evaluateReflectionNudge() }
        }
        .onChange(of: showReflections) { isShowing in
            if !isShowing { autoOpenReflectionInput = false }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                evaluateReflectionNudge()
            }
        }
    }

    // MARK: - Reflection Nudge

    @ViewBuilder
    private var reflectionNudgeBanner: some View {
        if showReflectionNudge {
            Button {
                autoOpenReflectionInput = true
                showReflections = true
                markNudgeDismissedToday()
                withAnimation(.easeIn(duration: 0.3)) { showReflectionNudge = false }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.orange.opacity(0.85))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("오늘 한 줄, 남기고 잘까요?")
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(.orange.opacity(0.92))
                        Text("재 항아리에 담아주세요")
                            .font(.system(size: 10))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange.opacity(0.55))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().stroke(Color.orange.opacity(0.35), lineWidth: 1))
                )
                .shadow(color: .orange.opacity(0.2), radius: 10, y: 2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityLabel("오늘의 회고를 남길까요? 탭하면 작성 화면으로 이동합니다")
        }
    }

    private var shouldShowReflectionNudge: Bool {
        !reflectionManager.urns.isEmpty
        && !reflectionManager.hasReflectionToday
        && !isNudgeDismissedToday
        && bedtimeManager.isCountdownActive
        && bedtimeManager.remainingSeconds > 0
        && bedtimeManager.remainingSeconds < Self.nudgeWindowSeconds
    }

    private func evaluateReflectionNudge() {
        guard !nudgeEvaluatedThisSession,
              !showReflectionNudge,
              shouldShowReflectionNudge else { return }
        nudgeEvaluatedThisSession = true
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.55, dampingFraction: 0.85)) {
            showReflectionNudge = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.nudgeAutoHideSeconds) {
            withAnimation(.easeIn(duration: 0.4)) {
                showReflectionNudge = false
            }
        }
    }

    private var isNudgeDismissedToday: Bool {
        nudgeDismissedISO == Self.todayKey()
    }

    private func markNudgeDismissedToday() {
        nudgeDismissedISO = Self.todayKey()
    }

    private static func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        return f.string(from: Date())
    }

    // MARK: - Page Indicator

    @ViewBuilder
    private var pageIndicator: some View {
        if bedtimeManager.indicatorVisible {
            HStack(spacing: indicatorSpacing) {
                ForEach(Array(pages.enumerated()), id: \.offset) { idx, _ in
                    indicatorItem(isActive: idx == currentIndex)
                }
            }
            .padding(.bottom, 16)
            .accessibilityHidden(true)
        } else {
            Spacer().frame(height: 24)
        }
    }

    private var indicatorSpacing: CGFloat {
        switch bedtimeManager.indicatorShape {
        case .dot, .pill: return 6
        case .line, .bar: return 4
        }
    }

    @ViewBuilder
    private func indicatorItem(isActive: Bool) -> some View {
        if !bedtimeManager.indicatorSymbol.isEmpty {
            Image(systemName: bedtimeManager.indicatorSymbol)
                .font(.system(size: isActive ? 11 : 8))
                .foregroundColor(isActive ? .orange : .gray.opacity(0.3))
                .animation(.easeInOut(duration: 0.2), value: isActive)
        } else {
            switch bedtimeManager.indicatorShape {
            case .dot:
                Circle()
                    .fill(isActive ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: isActive ? 8 : 6, height: isActive ? 8 : 6)
                    .animation(.easeInOut(duration: 0.2), value: isActive)
            case .pill:
                Capsule()
                    .fill(isActive ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: isActive ? 22 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: isActive)
            case .line:
                RoundedRectangle(cornerRadius: 2)
                    .fill(isActive ? Color.orange : Color.gray.opacity(0.25))
                    .frame(width: isActive ? 20 : 6, height: 3)
                    .animation(.easeInOut(duration: 0.2), value: isActive)
            case .bar:
                RoundedRectangle(cornerRadius: 3)
                    .fill(isActive ? Color.orange : Color.gray.opacity(0.25))
                    .frame(width: 14, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: isActive)
            }
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(alignment: .top) {
            Text(periodTitle)
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundColor(.orange.opacity(0.9))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: bedtimeManager.selectedPeriod)
                .accessibilityAddTraits(.isHeader)
                .accessibilityValue("페이지 \(currentIndex + 1) / \(pages.count)")
                .accessibilityHint("위아래로 스와이프해 페이지 이동")
                .accessibilityAdjustableAction { direction in
                    let idx = currentIndex
                    switch direction {
                    case .increment:
                        if idx < pages.count - 1 {
                            bedtimeManager.selectedPeriod = pages[idx + 1]
                        }
                    case .decrement:
                        if idx > 0 {
                            bedtimeManager.selectedPeriod = pages[idx - 1]
                        }
                    @unknown default: break
                    }
                }

            Spacer()

            HStack(spacing: 18) {
                AshUrnButton { showReflections = true }
                    .environmentObject(reflectionManager)

                Button(action: { showDeadlines = true }) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.orange.opacity(0.6))
                }
                .accessibilityLabel("데드라인")
                .accessibilityValue(
                    deadlineManager.deadlines.isEmpty
                        ? "없음"
                        : "\(deadlineManager.deadlines.filter { !$0.isExpired() }.count)개"
                )
                .accessibilityHint("탭하여 데드라인 관리")

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange.opacity(0.6))
                }
                .accessibilityLabel("시간 설정")
                .accessibilityHint("기상 및 취침 시간 설정")
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var periodTitle: String {
        switch bedtimeManager.selectedPeriod {
        case .day:      return "오늘"
        case .week:     return "이번 주"
        case .month:    return "이번 달"
        case .year:     return "올해"
        case .deadline: return "나의 목표"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(BedtimeManager())
        .environmentObject(DeadlineManager())
        .environmentObject(ReflectionManager())
}
