// ReflectionUrnView.swift
// 사용자가 직접 만드는 여러 항아리. 한 항아리 안에 4종 카테고리의 재 입자가 섞여 쌓임.

import SwiftUI
import LeeoKit

// MARK: - Main View
//
// 항아리는 사용자가 만들지 않는다.  날짜가 만든다.
// 선반에는 달 항아리가 놓이고, 달을 열면 그 달의 주 항아리가 나온다.

struct ReflectionUrnView: View {
    @EnvironmentObject var reflectionManager: ReflectionManager
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 기록 공백 구간.
    struct SweepRange: Identifiable {
        let start: Date
        let end: Date
        var id: String {
            "\(start.timeIntervalSinceReferenceDate)-\(end.timeIntervalSinceReferenceDate)"
        }
    }

    var autoOpenInput: Bool = false

    @State private var showInput = false
    @State private var editing: DayReflection? = nil
    @State private var meaningTarget: UrnPeriod? = nil
    @State private var autoOpenTriggered = false
    /// 기록 공백 회수로 연 입력. 시트에 값을 직접 실어 보내야 첫 렌더에서 날짜가 제대로 잡힌다.
    @State private var sweepInput: SweepRange? = nil
    /// onDismiss 시점엔 위 값이 이미 비므로, 정리 판정용으로 같은 구간을 따로 들고 있는다.
    @State private var pendingSweep: SweepRange? = nil
    /// 재가 날아가는 중 (0 → 그대로, 1 → 다 날아감).
    @State private var blowAway: Double = 0

    var body: some View {
        ZStack {
            Color.appBackgroundWarm.ignoresSafeArea()

            if reflectionManager.reflections.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        sweepPrompt
                        meaningPrompt
                        currentWeekCard
                        tipAsk
                        monthShelf
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }

            floatingActions
        }
        .navigationTitle("재 항아리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    NavigationLink {
                        AshInsightsView()
                            .environmentObject(reflectionManager)
                            .environmentObject(storeManager)
                    } label: {
                        Image(systemName: "chart.dots.scatter")
                            .scaledFont(size: 17)
                            .foregroundColor(.ember)
                    }
                    .accessibilityLabel("재의 흐름 보기")

                    NavigationLink {
                        ReflectionBookView()
                            .environmentObject(reflectionManager)
                            .environmentObject(storeManager)
                    } label: {
                        Image(systemName: "book.closed.fill")
                            .scaledFont(size: 17)
                            .foregroundColor(.ember)
                    }
                    .accessibilityLabel("회고 책으로 보기")
                }
            }
        }
        .sheet(isPresented: $showInput) {
            ReflectionInputView(existing: nil)
                .environmentObject(reflectionManager)
        }
        .sheet(item: $sweepInput, onDismiss: finishSweepIfCollected) { range in
            ReflectionInputView(existing: nil, initialDate: range.end)
                .environmentObject(reflectionManager)
        }
        .sheet(item: $editing) { item in
            ReflectionInputView(existing: item)
                .environmentObject(reflectionManager)
        }
        .sheet(item: $meaningTarget) { period in
            UrnMeaningEditView(period: period)
                .environmentObject(reflectionManager)
        }
        .onAppear {
            guard autoOpenInput, !autoOpenTriggered else { return }
            autoOpenTriggered = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showInput = true
            }
        }
    }

    // MARK: - 응원 부탁
    // 회고를 담고 돌아온 이 자리에서, 담은 수가 고비를 넘었을 때만 한 장 선다(모달 아님).
    // 이미 프로인 사람에게만 — 아직 아닌 사람에게는 페이월이 맞는 길이다.

    @ViewBuilder
    private var tipAsk: some View {
        if storeManager.isPro, let tipJar = storeManager.tipJar {
            LeeoTipAskSlot<BurningParchmentSpec>(
                tipJar: tipJar,
                reached: BurningParchmentTipMoments.reached(reflections: reflectionManager.totalReflectionCount))
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        let period = reflectionManager.currentWeekPeriod
        return VStack(spacing: 16) {
            MixedAshUrnVisual(seed: period.id, fillLevel: 0, counts: [:], hasMeaning: false)
                .frame(width: 90, height: 100)
                .accessibilityHidden(true)

            Text("아직 담긴 재가 없어요")
                .scaledFont(size: 17, weight: .medium, design: .serif)
                .foregroundColor(.inkSoft)
            Text("항아리는 이미 준비돼 있어요.\n첫 재는 \(period.title) 항아리에 담깁니다.")
                .scaledFont(size: 12, design: .serif)
                .foregroundColor(.inkSoft)
                .multilineTextAlignment(.center)

            Button {
                showInput = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                    Text("첫 재 담기")
                }
                .scaledFont(size: 14, weight: .semibold)
                .foregroundColor(.ember)
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .background(
                    Capsule().fill(Color.ember.opacity(0.15))
                        .overlay(Capsule().stroke(Color.ember.opacity(0.35), lineWidth: 1))
                )
            }
            .padding(.top, 8)
        }
    }

    // MARK: - 모아둔 재 (기록 공백 회수)
    // 앱을 며칠 안 연 사이의 시간은 어느 항아리에도 담기지 않는다.
    // 돌아왔을 때 한 번에 날려버리거나, 의미를 적어 담게 한다.

    @ViewBuilder
    private var sweepPrompt: some View {
        if let gap = reflectionManager.unrecordedAshGap {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "wind")
                        .scaledFont(size: 12)
                    Text("모아둔 재")
                        .scaledFont(size: 12, weight: .semibold)
                }
                .foregroundColor(.ember.opacity(0.75))

                Text(gapQuestion(gap.days))
                    .scaledFont(size: 16, weight: .semibold, design: .serif)
                    .foregroundColor(.ember.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(rangeLabel(gap)) — 아직 어느 항아리에도 담기지 않은 시간이에요.")
                    .scaledFont(size: 11, design: .serif)
                    .foregroundColor(.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                // 흩어져 있는 재 더미 — 날려버리면 이게 날아간다.
                AshPile(seed: gap.start.timeIntervalSinceReferenceDate,
                        count: min(gap.days * 14, 220),
                        blow: blowAway)
                    .frame(height: 34)
                    .padding(.top, 2)
                    .accessibilityHidden(true)

                HStack(spacing: 8) {
                    Button {
                        blowAwayGap(gap)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "wind")
                            Text("날려버리기")
                        }
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundColor(.inkSoft)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule().fill(Color.ink.opacity(0.05))
                                .overlay(Capsule().stroke(Color.inkMuted.opacity(0.28), lineWidth: 1))
                        )
                    }

                    Button {
                        collectGap(gap)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.pencil")
                            Text("의미 적어 담기")
                        }
                        .scaledFont(size: 13, weight: .semibold)
                        .foregroundColor(Color(red: 0.10, green: 0.07, blue: 0.05))
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(Capsule().fill(Color.ember.opacity(0.9)))
                    }
                }
                .padding(.top, 2)
                .opacity(1 - blowAway)
                .disabled(blowAway > 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.ink.opacity(0.035))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.ember.opacity(0.20 * (1 - blowAway)), lineWidth: 1))
            )
            .padding(.horizontal, 16)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// 2주 이상은 주 단위로, 그보다 짧으면 일 단위로 묻는다.
    private func gapQuestion(_ days: Int) -> String {
        days >= 14
            ? String(localized: "지난 \(days / 7)주간의 재를 어떻게 할까요?")
            : String(localized: "지난 \(days)일간의 재를 어떻게 할까요?")
    }

    private func rangeLabel(_ gap: (start: Date, end: Date, days: Int)) -> String {
        let f = TimeFormat.formatter("Md")
        return "\(f.string(from: gap.start)) ~ \(f.string(from: gap.end))"
    }

    /// 재가 바람에 실려 날아간 뒤에야 카드가 사라진다.
    private func blowAwayGap(_ gap: (start: Date, end: Date, days: Int)) {
        guard blowAway == 0 else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        guard !reduceMotion else {
            withAnimation(.easeOut(duration: 0.3)) {
                reflectionManager.sweepAsh(through: gap.end)
            }
            return
        }

        withAnimation(.easeIn(duration: Self.blowDuration)) { blowAway = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.blowDuration * 0.85) {
            withAnimation(.easeOut(duration: 0.35)) {
                reflectionManager.sweepAsh(through: gap.end)
            }
            blowAway = 0
        }
    }

    private static let blowDuration: Double = 1.15

    private func collectGap(_ gap: (start: Date, end: Date, days: Int)) {
        let range = SweepRange(start: gap.start, end: gap.end)
        pendingSweep = range
        sweepInput = range
    }

    /// 공백 구간에 실제로 재가 담겼을 때만 정리 처리한다.
    /// 그냥 시트를 닫았다면 다음에 다시 물어본다.
    private func finishSweepIfCollected() {
        guard let range = pendingSweep else { return }
        pendingSweep = nil
        let collected = reflectionManager.reflections.contains {
            $0.date >= range.start && $0.date <= range.end
        }
        if collected {
            withAnimation(.easeOut(duration: 0.3)) {
                reflectionManager.sweepAsh(through: range.end)
            }
        }
    }

    // MARK: - 의미를 기다리는 항아리
    // 다 채워진(더는 재가 안 늘어나는) 주 항아리인데 아직 이름이 없으면 한 번 물어본다.

    @ViewBuilder
    private var meaningPrompt: some View {
        if let period = reflectionManager.unnamedSealedWeeks.first {
            let count = reflectionManager.reflectionCount(in: period)
            Button {
                meaningTarget = period
            } label: {
                HStack(spacing: 14) {
                    MixedAshUrnVisual(
                        seed: period.id,
                        fillLevel: reflectionManager.fillLevel(for: period),
                        counts: reflectionManager.categoryCounts(for: period),
                        hasMeaning: false
                    )
                    .frame(width: 40, height: 46)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(period.title) 항아리에 재 \(count)톨이 남았어요")
                            .scaledFont(size: 13, weight: .semibold, design: .serif)
                            .foregroundColor(.ember.opacity(0.9))
                            .multilineTextAlignment(.leading)
                        Text("이 주는 당신에게 어떤 의미였나요?")
                            .scaledFont(size: 12, design: .serif)
                            .foregroundColor(.inkSoft)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "square.and.pencil")
                        .scaledFont(size: 14)
                        .foregroundColor(.ember.opacity(0.7))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.ember.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.ember.opacity(0.22), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .accessibilityLabel("\(period.title) 항아리에 의미 적기")
        }
    }

    // MARK: - 이번 주 항아리 (재가 지금 담기는 곳)

    private var currentWeekCard: some View {
        let period = reflectionManager.currentWeekPeriod
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader(String(localized: "지금 담기는 항아리"), period.rangeLabel)

            NavigationLink {
                UrnDetailView(period: period)
                    .environmentObject(reflectionManager)
                    .environmentObject(storeManager)
            } label: {
                urnRowLabel(period)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 선반 (달 항아리)

    private var monthShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(String(localized: "항아리 선반"),
                          String(localized: "달을 열면 그 달의 주 항아리가 나와요"))

            LazyVStack(spacing: 10) {
                ForEach(reflectionManager.monthPeriods) { month in
                    monthRow(month)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func monthRow(_ month: UrnPeriod) -> some View {
        NavigationLink {
            UrnDetailView(period: month)
                .environmentObject(reflectionManager)
                .environmentObject(storeManager)
        } label: {
            urnRowLabel(month)
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .scaledFont(size: 13, weight: .semibold, design: .serif)
                .foregroundColor(.ember.opacity(0.8))
            if !subtitle.isEmpty {
                Text(subtitle)
                    .scaledFont(size: 11, design: .serif)
                    .foregroundColor(.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 선반에 놓인 항아리 한 줄.
    private func urnRowLabel(_ period: UrnPeriod) -> some View {
        let count = reflectionManager.reflectionCount(in: period)
        let meaning = reflectionManager.meaning(for: period)

        return HStack(spacing: 14) {
            MixedAshUrnVisual(
                seed: period.id,
                fillLevel: reflectionManager.fillLevel(for: period),
                counts: reflectionManager.categoryCounts(for: period),
                hasMeaning: meaning != nil
            )
            .frame(width: 46, height: 52)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(period.title)
                    .scaledFont(size: 15, weight: .semibold, design: .serif)
                    .foregroundColor(.ember.opacity(0.88))

                if let meaning {
                    Text(meaning.displayName)
                        .scaledFont(size: 12, design: .serif)
                        .foregroundColor(.inkSoft)
                        .lineLimit(1)
                } else {
                    Text("아직 이름 없는 재")
                        .scaledFont(size: 12, design: .serif)
                        .foregroundColor(.inkSoft)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 6) {
                Text("재 \(count)톨")
                    .scaledFont(size: 11, design: .monospaced)
                    .foregroundColor(.inkSoft)
                Image(systemName: "chevron.right")
                    .scaledFont(size: 11, weight: .semibold)
                    .foregroundColor(.ember)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.ink.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.ember.opacity(0.10), lineWidth: 1))
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(period.accessibilityLabel)
        .accessibilityValue(
            (meaning?.displayName ?? String(localized: "아직 이름 없는 재"))
                + ", " + String(localized: "재 \(count)톨")
        )
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Floating Action

    private var floatingActions: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button { showInput = true } label: {
                    Image(systemName: "square.and.pencil")
                        .scaledFont(size: 20, weight: .semibold)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.ember, Color(red: 0.85, green: 0.40, blue: 0.20)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                        )
                        .shadow(color: .ember.opacity(0.35), radius: 14, y: 4)
                }
                .padding(.trailing, 22)
                .padding(.bottom, 22)
                .accessibilityLabel("새 회고 적기")
            }
        }
    }
}

// MARK: - Ash Insights (재의 흐름)
// 선반과 분리된 화면. 선반은 "무엇이 담겼나", 이 화면은 "어떻게 흘러왔나"를 맡는다.

struct AshInsightsView: View {
    @EnvironmentObject var reflectionManager: ReflectionManager

    @State private var editing: DayReflection? = nil

    var body: some View {
        ZStack {
            Color.appBackgroundWarm.ignoresSafeArea()

            if reflectionManager.reflections.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ReflectionDistributionView()
                        AshYearView()
                        EmberCalendarView(onEdit: { editing = $0 })
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("재의 흐름")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { item in
            ReflectionInputView(existing: item)
                .environmentObject(reflectionManager)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.dots.scatter")
                .scaledFont(size: 48)
                .foregroundColor(.ember)
            Text("아직 흘러간 재가 없어요")
                .scaledFont(size: 16, weight: .medium, design: .serif)
                .foregroundColor(.inkSoft)
            Text("재를 몇 톨 담으면\n분포와 잔불 달력이 여기에 나타나요.")
                .scaledFont(size: 12, design: .serif)
                .foregroundColor(.inkSoft)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Reflection Row

struct ReflectionRow: View {
    let item: DayReflection
    /// 어느 항아리의 재인지 — 항아리 안에서 볼 땐 굳이 다시 안 보여준다.
    var periodLabel: String? = nil
    /// 아직 의미가 부여되지 않은 항아리의 재는 색 없이 잿빛으로 보인다.
    var muted: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(rowDotColor)
                .frame(width: 7, height: 7)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.text)
                    .scaledFont(size: 14, design: .serif)
                    .foregroundColor(.ember.opacity(0.88))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    if let periodLabel {
                        Text(periodLabel)
                            .scaledFont(size: 10, weight: .medium)
                            .foregroundColor(.ember)
                    }
                    if item.category != .uncategorized {
                        Text(item.category.shortLabel)
                            .scaledFont(size: 10, weight: .medium)
                            .foregroundColor(rowDotColor)
                    }
                    Text(item.dateString)
                        .scaledFont(size: 10)
                        .foregroundColor(.inkSoft)
                    if let kw = item.keyword, !kw.isEmpty {
                        Text("#\(kw)")
                            .scaledFont(size: 10, weight: .medium)
                            .foregroundColor(.ember.opacity(0.7))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(Capsule().fill(Color.ember.opacity(0.10)))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.ink.opacity(0.03))
        )
    }

    private var rowDotColor: Color {
        guard !muted else { return Color(red: 0.60, green: 0.58, blue: 0.55) }
        let c = item.category.particleColor
        return Color(red: c.0, green: c.1, blue: c.2)
    }
}
