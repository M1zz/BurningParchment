// ContentView.swift
// 메인 화면

import SwiftUI
import WidgetKit

struct ContentView: View {
    @EnvironmentObject var bedtimeManager:    BedtimeManager
    @EnvironmentObject var deadlineManager:   DeadlineManager
    @EnvironmentObject var reflectionManager: ReflectionManager
    @EnvironmentObject var excuseManager:     BedtimeExcuseManager
    @EnvironmentObject var storeManager:      StoreManager
    @EnvironmentObject var fragmentManager:   FragmentManager
    @EnvironmentObject var nightManager:      NightManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings    = false
    @State private var showDeadlines   = false
    @State private var showReflections = false
    @State private var autoOpenReflectionInput = false
    @State private var showReflectionNudge = false
    @State private var nudgeEvaluatedThisSession = false
    @State private var showBlowOut     = false
    @State private var showFragments   = false
    @State private var morningCheckIn: MorningCheckIn?
    @State private var evaluatingMorning = false
    /// 아침 확인을 저절로 띄운 밤(취침 시각). 하룻밤에 한 번만 띄우고, 그 뒤로는 사용자가 열 때만.
    @AppStorage("morningCheckInAutoShownBedtime") private var morningAutoShownBedtime: Double = 0
    @AppStorage("reflectionNudgeDismissedDate") private var nudgeDismissedISO: String = ""

    /// 밤에 앱이 켜져 있는 동안 "깨어 있던 흔적"을 남기는 간격
    private let awakeTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
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
                Color.emberGlow.opacity(0.18 + progress * 0.07),
                Color.emberGlowDeep.opacity(0.07),
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
                Color.appBackground.ignoresSafeArea()

                if bedtimeManager.selectedPeriod != .day || bedtimeManager.isCountdownActive {
                    fullScreenGlow
                        .accessibilityHidden(true)
                }

                VStack(spacing: 0) {
                    headerBar
                    tomorrowIntentStrip
                    BurningParchmentView()
                        .environmentObject(bedtimeManager)
                        .environmentObject(nightManager)
                    blowOutPrompt
                    reflectionNudgeBanner
                    pageIndicator
                }
            }
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
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showReflections) {
                ReflectionUrnView(autoOpenInput: autoOpenReflectionInput)
                    .environmentObject(reflectionManager)
                    .environmentObject(storeManager)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(bedtimeManager)
                .environmentObject(storeManager)
        }
        .sheet(isPresented: $showDeadlines) {
            DeadlineListView()
                .environmentObject(deadlineManager)
                .environmentObject(storeManager)
        }
        .fullScreenCover(isPresented: $showBlowOut) {
            BlowOutView()
                .environmentObject(bedtimeManager)
                .environmentObject(fragmentManager)
                .environmentObject(nightManager)
        }
        .sheet(isPresented: $showFragments) {
            FragmentCollectionView()
                .environmentObject(fragmentManager)
        }
        .sheet(item: $morningCheckIn) { checkIn in
            MorningCheckInView(checkIn: checkIn)
                .environmentObject(nightManager)
                .environmentObject(fragmentManager)
                .environmentObject(excuseManager)
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
                noteAwakeIfNight()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    evaluateReflectionNudge()
                    evaluateMorning()
                }
            }
        }
        .onChange(of: bedtimeManager.isCountdownActive) { active in
            if active {
                evaluateReflectionNudge()
                evaluateMorning()
            }
        }
        .onChange(of: bedtimeManager.currentNight) { night in
            // 새 밤이 시작되면 확인받지 못한 지난 밤들은 그을음 없이 닫는다
            if NightManager.isEnabled, let night { nightManager.closeUnanswered(before: night.start) }
            noteAwakeIfNight()
        }
        .onReceive(awakeTicker) { _ in
            if scenePhase == .active { noteAwakeIfNight() }
        }
        .onChange(of: showReflections) { isShowing in
            if !isShowing { autoOpenReflectionInput = false }
        }
        .onAppear {
            noteAwakeIfNight()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                evaluateReflectionNudge()
                evaluateMorning()
            }
        }
    }

    // MARK: - Tomorrow Intent Strip
    // 어제 missed로 분류한 회고들의 "내일 어떻게?" 한 줄을 양피지 위에 띠로 띄움.
    // day 페이지에서만 노출하고, 양피지가 타들어갈수록 함께 페이드아웃.

    @ViewBuilder
    private var tomorrowIntentStrip: some View {
        let intents = reflectionManager.yesterdayPendingIntents
        if bedtimeManager.selectedPeriod == .day,
           !bedtimeManager.isBeforeWakeTime,
           bedtimeManager.isCountdownActive,
           !intents.isEmpty {
            let fade = max(0.0, 1.0 - bedtimeManager.progress * 1.3)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "scroll")
                        .font(.system(size: 10))
                        .foregroundColor(.ember.opacity(0.75))
                    Text("어제 못한 것")
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .foregroundColor(.ember.opacity(0.75))
                }
                ForEach(Array(intents.prefix(3).enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("·")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.ember.opacity(0.6))
                        Text(item.intent)
                            .font(.system(size: 12, design: .serif))
                            .foregroundColor(Color(red: 0.45, green: 0.32, blue: 0.18))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                if intents.count > 3 {
                    Text("외 \(intents.count - 3)개")
                        .font(.system(size: 10, design: .serif))
                        .foregroundColor(.ember.opacity(0.5))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.86, green: 0.78, blue: 0.62).opacity(0.85),
                            Color(red: 0.78, green: 0.68, blue: 0.50).opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.brown.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            )
            .padding(.horizontal, 28)
            .padding(.top, 4)
            .opacity(fade)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("어제 못한 것 \(intents.count)개")
            .accessibilityValue(intents.prefix(3).map { $0.intent }.joined(separator: ", "))
        }
    }

    // MARK: - Blow Out (취침 30분 전 불 끄기)

    private var tonightFragment: ParchmentFragment? {
        fragmentManager.fragment(forBedtime: bedtimeManager.currentBedDate)
    }

    /// 취침 이후, 아직 끄지 않은 내일의 양피지가 타고 있는가
    private var isTomorrowBurning: Bool {
        guard NightManager.isEnabled, let night = bedtimeManager.currentNight else { return false }
        // 기상 30분 전부터는 "곧 기상" 화면이라 끌 것이 보이지 않는다
        if bedtimeManager.isBeforeWakeTime && bedtimeManager.remainingSeconds <= 1800 { return false }
        if fragmentManager.fragment(forBedtime: night.start) != nil { return false }
        return nightManager.record(forBedtime: night.start)?.extinguishedAt == nil
    }

    @ViewBuilder
    private var blowOutPrompt: some View {
        if bedtimeManager.selectedPeriod == .day {
            if isTomorrowBurning {
                blowOutButton
                    .accessibilityHint("내일의 양피지에 붙은 불을 끕니다")
            } else if NightManager.isEnabled, bedtimeManager.isCountdownActive, let last = bedtimeManager.lastNight,
                      morningAutoShownBedtime == last.start.timeIntervalSince1970,
                      nightManager.isPending(last) {
                // 아침 확인을 닫아 두었다면 여기서 다시 열 수 있다. 답하지 않으면 그을음 없이 넘어간다.
                Button {
                    morningCheckIn = MorningCheckIn(night: last, step: .ask)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sunrise")
                        Text("어젯밤은 어땠나요?")
                            .font(.system(.body, design: .serif).weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.body)
                    }
                    .foregroundColor(.inkMuted.opacity(0.85))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                }
                .padding(.bottom, 6)
                .transition(.opacity)
            } else if bedtimeManager.isCountdownActive, tonightFragment != nil {
                Button { showFragments = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "smoke.fill")
                            .font(.system(size: 12))
                        Text("불을 껐어요 · 모은 조각 보기")
                            .font(.system(size: 13, weight: .medium, design: .serif))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.inkMuted.opacity(0.75))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                }
                .padding(.bottom, 6)
                .transition(.opacity)
            } else if bedtimeManager.isInBlowOutWindow {
                blowOutButton
                    .accessibilityHint("오늘 하루의 불을 끄고 남은 조각을 모아둡니다")
            }
        }
    }

    private var blowOutButton: some View {
        Button { showBlowOut = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "wind")
                    .font(.system(size: 14, weight: .semibold))
                Text("후 불어서 불 끄기")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
            }
            .foregroundColor(.onEmber)
            .padding(.vertical, 12)
            .padding(.horizontal, 22)
            .background(Capsule().fill(Color.ember))
            .shadow(color: .ember.opacity(0.35), radius: 10, y: 3)
        }
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
                        .foregroundColor(.ember.opacity(0.85))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("오늘 한 줄, 남기고 잘까요?")
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(.ember.opacity(0.92))
                        Text("재 항아리에 담아주세요")
                            .font(.system(size: 10))
                            .foregroundColor(.inkMuted.opacity(0.6))
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.ember.opacity(0.55))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().stroke(Color.ember.opacity(0.35), lineWidth: 1))
                )
                .shadow(color: .ember.opacity(0.2), radius: 10, y: 2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityLabel("오늘의 회고를 남길까요? 탭하면 작성 화면으로 이동합니다")
        }
    }

    private var shouldShowReflectionNudge: Bool {
        !reflectionManager.hasReflectionToday
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

    // MARK: - Night & Morning
    // 밤사이 내일의 양피지가 타는 건 보여주기만 하고, 그을음은 아침에 확인된 만큼만 남긴다.

    private func noteAwakeIfNight() {
        guard NightManager.isEnabled, let night = bedtimeManager.currentNight else { return }
        nightManager.noteAwake(in: night)
    }

    /// 낮에 앱을 열면 어젯밤을 확정한다. 건강 앱 기록이 있으면 묻지 않고, 없으면 하룻밤에 한 번만 묻는다.
    private func evaluateMorning() {
        guard morningCheckIn == nil, !evaluatingMorning, !showBlowOut,
              bedtimeManager.isCountdownActive, let night = bedtimeManager.lastNight else { return }

        // 옮겨붙는 흐름이 꺼져 있으면 잠든 시각은 묻지 않는다. 불을 끈 밤의 조각 뒷면만 권한다.
        guard NightManager.isEnabled else {
            let key = night.start.timeIntervalSince1970
            if morningAutoShownBedtime != key,
               let fragment = fragmentManager.fragment(forBedtime: night.start),
               !fragment.isFellAsleep, !fragment.isBackWritten {
                morningAutoShownBedtime = key
                morningCheckIn = MorningCheckIn(night: night, step: .writeBack)
            }
            return
        }
        // 더 지난 밤은 이제 묻지 않는다 — 앱을 며칠 안 열었어도 그 밤들은 그을음 없이 지나간다
        nightManager.closeUnanswered(before: night.start)

        let key = night.start.timeIntervalSince1970
        let autoShown = morningAutoShownBedtime == key
        let fragment = fragmentManager.fragment(forBedtime: night.start)

        if nightManager.record(forBedtime: night.start)?.isResolved == true {
            if let fragment, !fragment.isBackWritten, !autoShown {
                morningAutoShownBedtime = key
                morningCheckIn = MorningCheckIn(night: night, step: .writeBack)
            }
            return
        }

        // 취침 전에 스스로 불을 껐다 — 확인할 것이 없다. 식은 조각의 뒷면만 권한다.
        if let fragment, !fragment.isFellAsleep {
            nightManager.resolve(night, outcome: .keptBedtime)
            if !fragment.isBackWritten, !autoShown {
                morningAutoShownBedtime = key
                morningCheckIn = MorningCheckIn(night: night, step: .writeBack)
            }
            return
        }

        evaluatingMorning = true
        Task { @MainActor in
            defer { evaluatingMorning = false }
            if let onset = await SleepHealth.sleepOnset(in: night) {
                nightManager.resolve(night, outcome: .health, healthOnset: onset)
                morningAutoShownBedtime = key
                morningCheckIn = MorningCheckIn(night: night, step: .result)
            } else if !autoShown {
                morningAutoShownBedtime = key
                morningCheckIn = MorningCheckIn(night: night, step: .ask)
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
                .foregroundColor(isActive ? .ember : .inkMuted.opacity(0.3))
                .animation(.easeInOut(duration: 0.2), value: isActive)
        } else {
            switch bedtimeManager.indicatorShape {
            case .dot:
                Circle()
                    .fill(isActive ? Color.ember : Color.inkMuted.opacity(0.3))
                    .frame(width: isActive ? 8 : 6, height: isActive ? 8 : 6)
                    .animation(.easeInOut(duration: 0.2), value: isActive)
            case .pill:
                Capsule()
                    .fill(isActive ? Color.ember : Color.inkMuted.opacity(0.3))
                    .frame(width: isActive ? 22 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: isActive)
            case .line:
                RoundedRectangle(cornerRadius: 2)
                    .fill(isActive ? Color.ember : Color.inkMuted.opacity(0.25))
                    .frame(width: isActive ? 20 : 6, height: 3)
                    .animation(.easeInOut(duration: 0.2), value: isActive)
            case .bar:
                RoundedRectangle(cornerRadius: 3)
                    .fill(isActive ? Color.ember : Color.inkMuted.opacity(0.25))
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
                .foregroundColor(.ember.opacity(0.9))
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
                if !fragmentManager.fragments.isEmpty {
                    Button(action: { showFragments = true }) {
                        Image(systemName: "square.stack.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.ember.opacity(0.6))
                    }
                    .accessibilityLabel("모은 조각")
                    .accessibilityValue("\(fragmentManager.fragments.count)개")
                }

                AshUrnButton { showReflections = true }
                    .environmentObject(reflectionManager)

                Button(action: { showDeadlines = true }) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.ember.opacity(0.6))
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
                        .foregroundColor(.ember.opacity(0.6))
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
        case .day:      return String(localized: "오늘")
        case .week:     return String(localized: "이번 주")
        case .month:    return String(localized: "이번 달")
        case .year:     return String(localized: "올해")
        case .deadline: return String(localized: "나의 목표")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(BedtimeManager())
        .environmentObject(DeadlineManager())
        .environmentObject(StoreManager())
        .environmentObject(ReflectionManager())
        .environmentObject(BedtimeExcuseManager())
        .environmentObject(FragmentManager())
        .environmentObject(NightManager())
}
