// ContentView.swift
// 메인 화면

import SwiftUI
import Combine
import WidgetKit
import TipKit
import LeeoKit

struct ContentView: View {
    @EnvironmentObject var bedtimeManager:    BedtimeManager
    @EnvironmentObject var deadlineManager:   DeadlineManager
    @EnvironmentObject var reflectionManager: ReflectionManager
    @EnvironmentObject var excuseManager:     BedtimeExcuseManager
    @EnvironmentObject var storeManager:      StoreManager
    @EnvironmentObject var fragmentManager:   FragmentManager
    @EnvironmentObject var nightManager:      NightManager
    @EnvironmentObject var freeTimeManager:   FreeTimeManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings    = false
    @State private var showDeadlines   = false
    @State private var showReflections = false
    @State private var autoOpenReflectionInput = false
    @State private var showReflectionNudge = false
    @State private var nudgeEvaluatedThisSession = false
    @State private var showBlowOut     = false
    @State private var showFragments   = false
    // 만족도 질문 — 회고·데드라인 화면에서 무언가를 해내고 돌아온 때 묻는다 (앱을 켜자마자가 아니라)
    @State private var showReviewGate  = false
    @State private var eventsAtVisit   = 0
    @State private var morningCheckIn: MorningCheckIn?
    @State private var evaluatingMorning = false
    /// 아침 확인을 저절로 띄운 밤(취침 시각). 하룻밤에 한 번만 띄우고, 그 뒤로는 사용자가 열 때만.
    @AppStorage("morningCheckInAutoShownBedtime") private var morningAutoShownBedtime: Double = 0
    @AppStorage("reflectionNudgeDismissedDate") private var nudgeDismissedISO: String = ""

    /// 밤에 앱이 켜져 있는 동안 "깨어 있던 흔적"을 남기는 간격
    private let awakeTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var typeSize

    /// 처음 연 사람에게 보이는 안내, 업데이트 뒤 한 번 보이는 새 소식
    @State private var showOnboarding = false
    @State private var showWhatsNew = false
    @State private var greeted = false
    @AppStorage(LaunchAudience.onboardingKey) private var hasCompletedOnboarding = false
    @AppStorage(LaunchAudience.whatsNewKey) private var lastSeenWhatsNew = ""
    private let swipeTip = SwipePeriodsTip()

    /// 머리 줄 아이콘의 불투명도. 대비 증가에서는 흐리게 두지 않는다.
    private var headerIconOpacity: Double { contrast == .increased ? 0.95 : 0.6 }

    private static let nudgeWindowSeconds: Double = 5400  // 취침 90분 전부터
    private static let nudgeAutoHideSeconds: Double = 9

    private var pages: [PeriodType] {
        let basePeriods: [PeriodType] = [.day, .week, .freeTime, .month, .year]
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
            case .freeTime: return freeTimeManager.week().progress
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
                    TipView(swipeTip, arrowEdge: .top)
                        .tipBackground(Color.appBackgroundWarm)
                        .padding(.horizontal, 20)
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
                        swipeTip.invalidate(reason: .actionPerformed)
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
                .environmentObject(storeManager)
        }
        .sheet(item: $morningCheckIn) { checkIn in
            MorningCheckInView(checkIn: checkIn)
                .environmentObject(nightManager)
                .environmentObject(fragmentManager)
                .environmentObject(excuseManager)
        }
        .onChange(of: scenePhase) { _, phase in
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
        .onChange(of: bedtimeManager.isCountdownActive) { _, active in
            if active {
                evaluateReflectionNudge()
                evaluateMorning()
            }
        }
        .onChange(of: bedtimeManager.currentNight) { _, night in
            // 새 밤이 시작되면 확인받지 못한 지난 밤들은 그을음 없이 닫는다
            if NightManager.isEnabled, let night { nightManager.closeUnanswered(before: night.start) }
            noteAwakeIfNight()
        }
        .onReceive(awakeTicker) { _ in
            if scenePhase == .active { noteAwakeIfNight() }
        }
        .onChange(of: showReflections) { _, isShowing in
            if !isShowing { autoOpenReflectionInput = false }
            askForReviewIfAccomplished(returning: !isShowing)
        }
        .onChange(of: showDeadlines) { _, isShowing in
            askForReviewIfAccomplished(returning: !isShowing)
        }
        .leeoReviewGate(BurningParchmentSpec.self, isPresented: $showReviewGate)
        .fullScreenCover(isPresented: $showOnboarding) {
            BurningOnboardingView {
                hasCompletedOnboarding = true
                showOnboarding = false
            }
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView { showWhatsNew = false }
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            AppLaunch.firstScreenAppeared()
            greetByAudience()
            noteAwakeIfNight()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                evaluateReflectionNudge()
                evaluateMorning()
            }
        }
    }

    // MARK: - 만족도 질문

    /// 회고·데드라인 화면을 열 때 해낸 일 수를 적어 두고, 닫고 돌아왔을 때 늘었으면 묻는다.
    /// 불 끄기는 "잘 자요"로 끝나는 잠자리 의식이라 거기서는 묻지 않는다.
    private func askForReviewIfAccomplished(returning: Bool) {
        let events = LeeoEngagement.shared.significantEventCount
        guard returning else { eventsAtVisit = events; return }
        guard events > eventsAtVisit, LeeoReviewRequest.shouldRequest() else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8))   // 화면이 돌아오는 전환이 끝난 뒤
            let busy = showSettings || showDeadlines || showReflections || showReflectionNudge || showBlowOut
                || showFragments || morningCheckIn != nil || showOnboarding || showWhatsNew || showReviewGate
            guard !busy, LeeoReviewRequest.shouldRequest() else { return }
            LeeoReviewRequest.markRequested()
            showReviewGate = true
        }
    }

    // MARK: - 처음 온 사람 · 업데이트한 사람

    private func greetByAudience() {
        // 전체 화면 안내가 닫히면 onAppear 가 다시 불린다 — 한 번만 판단한다
        guard !greeted else { return }
        greeted = true
        #if DEBUG
        // UI 시험·스크린샷: 실행 횟수와 상관없이 안내를 띄운다 (-showOnboarding YES)
        if UserDefaults.standard.bool(forKey: "showOnboarding") {
            showOnboarding = true
            return
        }
        // 스크린샷·UI 시험: 첫 실행이어도 안내·새 소식을 띄우지 않는다 (-skipOnboarding YES)
        if UserDefaults.standard.bool(forKey: "skipOnboarding") { return }
        #endif
        let audience = LaunchAudience.resolve(launchCount: LeeoEngagement.shared.launchCount,
                                              hasCompletedOnboarding: hasCompletedOnboarding,
                                              lastSeenWhatsNew: lastSeenWhatsNew)
        switch audience {
        case .newcomer:
            // 처음 온 사람에게 "새로워졌어요"는 뜻 모를 말이다 — 본 것으로만 적는다
            lastSeenWhatsNew = WhatsNewContent.version
            showOnboarding = true
        case .returningNeedsWhatsNew:
            // 쓰던 사람은 안내가 필요 없다 (설정에서 다시 볼 수 있다)
            hasCompletedOnboarding = true
            lastSeenWhatsNew = WhatsNewContent.version
            showWhatsNew = true
        case .returning:
            break
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
                        .font(.system(.caption2, design: .serif).weight(.medium))
                        .foregroundColor(.ember.opacity(0.75))
                }
                ForEach(Array(intents.prefix(3).enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("·")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.ember.opacity(0.6))
                        Text(item.intent)
                            .font(.system(.caption, design: .serif))
                            .foregroundColor(Color(red: 0.45, green: 0.32, blue: 0.18))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                if intents.count > 3 {
                    Text("외 \(intents.count - 3)개")
                        .font(.system(.caption2, design: .serif))
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
                            .font(.system(.footnote, design: .serif).weight(.medium))
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
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
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
                            .font(.system(.footnote, design: .serif).weight(.medium))
                            .foregroundColor(.ember.opacity(0.92))
                        Text("재 항아리에 담아주세요")
                            .font(.caption2)
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
                    nudgeBackground
                        .overlay(Capsule().stroke(Color.ember.opacity(contrast == .increased ? 0.8 : 0.35), lineWidth: 1))
                )
                .shadow(color: .ember.opacity(0.2), radius: 10, y: 2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityLabel("오늘의 회고를 남길까요? 탭하면 작성 화면으로 이동합니다")
        }
    }

    /// 투명도 줄이기를 켜면 비치는 유리 대신 불투명한 바탕을 쓴다
    @ViewBuilder
    private var nudgeBackground: some View {
        if reduceTransparency {
            Capsule().fill(Color.appBackgroundWarm)
        } else {
            Capsule().fill(.ultraThinMaterial)
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
        guard morningCheckIn == nil, !evaluatingMorning, !showBlowOut, !showOnboarding, !showWhatsNew,
              bedtimeManager.isCountdownActive, let night = bedtimeManager.lastNight else { return }

        // 옮겨붙는 흐름이 꺼져 있으면 아침에는 아무것도 띄우지 않는다 — 잠든 시각도, 조각 뒷면 쓰기도.
        // 앱은 자기 전에 후 불어 끄는 의식까지만 맡고, 뒷면은 모은 조각에서 원할 때 쓴다.
        guard NightManager.isEnabled else { return }
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
        // 건강 앱 조회는 원격으로 끌 수 있고, 세이프 모드에서는 건너뛴다 — 그때는 아침에 직접 묻는다
        let readsHealth = BurningFlag.sleepHealth.isEnabled && !AppLaunch.isSafeMode
        Task { @MainActor in
            defer { evaluatingMorning = false }
            if readsHealth, let onset = await SleepHealth.sleepOnset(in: night) {
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
                ForEach(Array(pages.enumerated()), id: \.offset) { idx, period in
                    if period == .freeTime {
                        freeTimeIndicatorItem(isActive: idx == currentIndex)
                    } else {
                        indicatorItem(isActive: idx == currentIndex)
                    }
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

    /// 불타는 자유시간 페이지는 다른 기간과 성격이 달라(하루·주·달처럼 이어서 타지 않고
    /// 정해 둔 시간에만 탄다) 점 대신 모래시계로 구분한다. 고른 인디케이터 모양과 상관없이 같다.
    /// 지금 타는 중이면 비활성일 때도 은은하게 불빛을 띤다.
    private func freeTimeIndicatorItem(isActive: Bool) -> some View {
        let burning = freeTimeManager.week().isBurning
        return Image(systemName: isActive || burning ? "hourglass" : "hourglass.bottomhalf.filled")
            .font(.system(size: isActive ? 12 : 9, weight: .semibold))
            .foregroundColor(isActive ? .ember : (burning ? .ember.opacity(0.55) : .inkMuted.opacity(0.35)))
            .frame(height: 12)
            .animation(.easeInOut(duration: 0.2), value: isActive)
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
        Group {
            if typeSize.isAccessibilitySize {
                // 아주 큰 글씨: 제목이 아이콘 줄에 밀려 잘리지 않도록 아이콘을 위, 제목을 아래로 둔다
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Spacer(); headerIcons }
                    headerTitle
                }
            } else {
                HStack(alignment: .top) {
                    headerTitle
                    Spacer()
                    headerIcons.padding(.top, 10)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var headerTitle: some View {
        Text(periodTitle)
            // 큰 제목 스타일(34pt) — 글자 크기 설정을 따른다
            .font(.system(.largeTitle, design: .serif).weight(.bold))
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
    }

    private var headerIcons: some View {
        HStack(spacing: 18) {
            if !fragmentManager.fragments.isEmpty {
                Button(action: { showFragments = true }) {
                    Image(systemName: "square.stack.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.ember.opacity(headerIconOpacity))
                }
                .accessibilityLabel("모은 조각")
                .accessibilityValue("\(fragmentManager.fragments.count)개")
                .accessibilityInputLabels([Text("모은 조각"), Text("조각")])
            }

            AshUrnButton { showReflections = true }
                .environmentObject(reflectionManager)

            Button(action: { showDeadlines = true }) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.ember.opacity(headerIconOpacity))
            }
            .accessibilityLabel("데드라인")
            .accessibilityInputLabels([Text("데드라인"), Text("목표")])
            .accessibilityValue(
                deadlineManager.deadlines.isEmpty
                    ? "없음"
                    : "\(deadlineManager.deadlines.filter { !$0.isExpired() }.count)개"
            )
            .accessibilityHint("탭하여 데드라인 관리")

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.ember.opacity(headerIconOpacity))
            }
            .accessibilityLabel("시간 설정")
            .accessibilityHint("기상 및 취침 시간 설정")
            .accessibilityInputLabels([Text("설정"), Text("시간 설정")])
        }
    }

    private var periodTitle: String {
        switch bedtimeManager.selectedPeriod {
        case .day:      return String(localized: "오늘")
        case .week:     return String(localized: "이번 주")
        case .month:    return String(localized: "이번 달")
        case .year:     return String(localized: "올해")
        case .freeTime: return String(localized: "나의 자유시간")
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
        .environmentObject(FreeTimeManager())
}
