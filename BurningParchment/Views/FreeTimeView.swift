// FreeTimeView.swift
// 불타는 자유시간 (프로) — 소개 카드와 자유시간을 정하는 화면.
//
// 자유시간을 정하고 일주일 셈을 보는 것까지는 누구나 한다. 그 시간만 양피지가 타게 하는 건 프로.
// 자기 시간으로 먼저 "일주일에 나만의 시간이 이만큼뿐이구나" 를 보게 하고, 태우는 건 그다음이다.

import SwiftUI

// MARK: - 일주일 셈

/// 자유시간이 깨어 있는 시간 중 얼마인지, 한 해로 치면 며칠인지
struct FreeTimeSummary: View {
    @EnvironmentObject var freeTimeManager: FreeTimeManager
    @EnvironmentObject var bedtimeManager: BedtimeManager

    private var weeklyMinutes: Int { freeTimeManager.weeklyMinutes }

    private var awakeWeeklyMinutes: Int {
        let wake = bedtimeManager.wakeHour * 60 + bedtimeManager.wakeMinute
        let bed = bedtimeManager.bedtimeHour * 60 + bedtimeManager.bedtimeMinute
        let daily = bed > wake ? bed - wake : bed + 1440 - wake
        return daily * 7
    }

    private var share: Int {
        awakeWeeklyMinutes > 0 ? Int((Double(weeklyMinutes) / Double(awakeWeeklyMinutes) * 100).rounded()) : 0
    }

    /// 한 해(52주) 동안의 자유시간을 날수로
    private var yearDays: Int { Int((Double(weeklyMinutes) * 52 / 1440).rounded()) }

    var body: some View {
        HStack(spacing: 0) {
            stat(value: BurningParchmentView.durationString(TimeInterval(weeklyMinutes * 60)),
                 caption: String(localized: "일주일 나만의 시간"))
            divider
            stat(value: "\(share)%", caption: String(localized: "깨어 있는 시간 중"))
            divider
            stat(value: String(localized: "약 \(yearDays)일"), caption: String(localized: "한 해로 치면"))
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.ink.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.ember.opacity(0.12), lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle().fill(Color.ember.opacity(0.12)).frame(width: 1, height: 34)
    }

    private func stat(value: String, caption: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundColor(.ember.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(.system(size: 11))
                .foregroundColor(.inkMuted.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}

// MARK: - 한 주 띠

/// 월~일 일곱 줄. 하루 24시간 막대 위에 잠은 어둡게, 자유시간은 불빛으로.
struct FreeTimeWeekStrip: View {
    @EnvironmentObject var freeTimeManager: FreeTimeManager
    @EnvironmentObject var bedtimeManager: BedtimeManager

    var body: some View {
        VStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                HStack(spacing: 8) {
                    Text(FreeTimeBlock.weekdaySymbol(day))
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(.inkMuted.opacity(0.7))
                        .frame(width: 30, alignment: .leading)
                    Canvas { ctx, size in
                        func rect(_ s: Int, _ e: Int) -> CGRect {
                            CGRect(x: size.width * CGFloat(s) / 1440, y: 0,
                                   width: size.width * CGFloat(e - s) / 1440, height: size.height)
                        }
                        let bg = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 3)
                        ctx.fill(bg, with: .color(Color.ink.opacity(0.05)))
                        ctx.clip(to: bg)
                        for (s, e) in sleepSegments {
                            ctx.fill(Path(rect(s, e)), with: .color(Color.ink.opacity(0.12)))
                        }
                        for (s, e) in segments(for: day) {
                            ctx.fill(Path(roundedRect: rect(s, e), cornerRadius: 2), with: .color(Color.ember.opacity(0.85)))
                        }
                    }
                    .frame(height: 12)
                }
            }
            HStack(spacing: 8) {
                Color.clear.frame(width: 30, height: 1)
                HStack {
                    ForEach([0, 6, 12, 18, 24], id: \.self) { h in
                        Text("\(h)")
                            .font(.system(size: 9))
                            .foregroundColor(.inkMuted.opacity(0.45))
                        if h != 24 { Spacer() }
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// 잠자는 구간 (그날 0~1440분 안에서)
    private var sleepSegments: [(Int, Int)] {
        let wake = bedtimeManager.wakeHour * 60 + bedtimeManager.wakeMinute
        let bed = bedtimeManager.bedtimeHour * 60 + bedtimeManager.bedtimeMinute
        return bed > wake ? [(0, wake), (bed, 1440)] : [(bed, wake)]
    }

    /// 그날의 자유시간 구간. 전날 밤에 시작해 자정을 넘어온 몫도 그린다.
    private func segments(for day: Int) -> [(Int, Int)] {
        let previous = day == 1 ? 7 : day - 1
        var result: [(Int, Int)] = []
        for b in freeTimeManager.blocks {
            let end = b.startMinute + b.durationMinutes
            if b.weekday == day { result.append((b.startMinute, min(end, 1440))) }
            if b.weekday == previous, end > 1440 { result.append((0, end - 1440)) }
        }
        return result
    }
}

// MARK: - 소개 카드 (자유시간 탭)

/// 프로가 아니거나 자유시간을 아직 안 정했을 때 양피지 자리에 뜬다.
struct FreeTimeIntroView: View {
    @EnvironmentObject var freeTimeManager: FreeTimeManager
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var bedtimeManager: BedtimeManager
    var onEdit: () -> Void
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "hourglass")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.ember.opacity(0.75))
                    .padding(.top, 24)

                Text("불타는 자유시간")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundColor(.ember.opacity(0.9))

                Text("잠자는 시간도, 일하는 시간도 빼고\n정말 나만을 위한 시간만 골라 두세요.\n그 시간이 지나갈 때만 이번 주 양피지가 타요.")
                    .font(.system(size: 14, design: .serif))
                    .foregroundColor(.inkMuted.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                if freeTimeManager.isConfigured {
                    FreeTimeSummary()
                    FreeTimeWeekStrip()
                        .padding(.horizontal, 4)
                }

                VStack(spacing: 10) {
                    if freeTimeManager.isConfigured && !storeManager.isPro {
                        primaryButton(String(localized: "프로로 자유시간만 태우기"), icon: "flame.fill") {
                            showPaywall = true
                        }
                        Button("자유시간 고치기", action: onEdit)
                            .font(.system(size: 14, design: .serif))
                            .foregroundColor(.ember.opacity(0.8))
                    } else {
                        primaryButton(String(localized: "나의 자유시간 정하기"), icon: "plus", action: onEdit)
                        if !storeManager.isPro {
                            Text("정해 보고 셈을 보는 건 무료예요. 그 시간만 태우는 건 프로예요.")
                                .font(.system(size: 11))
                                .foregroundColor(.inkMuted.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .freeTime)
                .environmentObject(storeManager)
        }
    }

    private func primaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 16, weight: .semibold, design: .serif))
            .foregroundColor(.onEmber)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.ember))
        }
    }
}

// MARK: - 자유시간 정하기

struct FreeTimeEditorView: View {
    @EnvironmentObject var freeTimeManager: FreeTimeManager
    @EnvironmentObject var bedtimeManager: BedtimeManager
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDays: Set<Int> = [1, 2, 3, 4, 5]
    @State private var start = FreeTimeEditorView.time(20, 0)
    @State private var end = FreeTimeEditorView.time(22, 0)
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundWarm.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("잠·일·해야 할 일을 빼고, 온전히 나를 위해 쓰는 시간만 적어 주세요. 이 시간이 지나갈 때만 이번 주 양피지가 타요.")
                            .font(.system(size: 13, design: .serif))
                            .foregroundColor(.inkMuted.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)

                        if freeTimeManager.isConfigured {
                            FreeTimeSummary()
                            FreeTimeWeekStrip()
                        }

                        addSection

                        if freeTimeManager.isConfigured { blockList }

                        if !storeManager.isPro { proBanner }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("나의 자유시간")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                        .foregroundColor(.ember)
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .freeTime)
                .environmentObject(storeManager)
        }
    }

    // MARK: 더하기

    private var startMinute: Int { Self.minutes(start) }
    private var endMinute: Int { Self.minutes(end) }

    private var draftOverlapsSleep: Bool {
        let draft = FreeTimeBlock(weekday: 1, startMinute: startMinute, endMinute: endMinute)
        return !draft.fitsAwake(wakeMinute: wakeMinute, bedMinute: bedMinute)
    }

    private var wakeMinute: Int { bedtimeManager.wakeHour * 60 + bedtimeManager.wakeMinute }
    private var bedMinute: Int { bedtimeManager.bedtimeHour * 60 + bedtimeManager.bedtimeMinute }

    private var addSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(String(localized: "자유시간 더하기"), icon: "plus.circle")

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { day in
                        let on = selectedDays.contains(day)
                        Button {
                            if on { selectedDays.remove(day) } else { selectedDays.insert(day) }
                        } label: {
                            Text(FreeTimeBlock.weekdaySymbol(day))
                                .font(.system(size: 13, weight: on ? .semibold : .regular))
                                .foregroundColor(on ? .onEmber : .ember.opacity(0.8))
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(RoundedRectangle(cornerRadius: 9)
                                    .fill(on ? Color.ember : Color.ember.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }

                HStack(spacing: 8) {
                    quickChip(String(localized: "평일"), days: [1, 2, 3, 4, 5])
                    quickChip(String(localized: "주말"), days: [6, 7])
                    quickChip(String(localized: "매일"), days: Set(1...7))
                }

                HStack {
                    DatePicker("시작", selection: $start, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Text("–").foregroundColor(.inkMuted)
                    DatePicker("끝", selection: $end, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Spacer()
                    Text(BurningParchmentView.durationString(TimeInterval(
                        FreeTimeBlock(weekday: 1, startMinute: startMinute, endMinute: endMinute).durationMinutes * 60)))
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(.inkMuted.opacity(0.7))
                }
                .tint(.ember)

                if draftOverlapsSleep {
                    Label("잠자는 시간과 겹쳐요. 깨어 있는 시간 안으로 잡아 주세요.", systemImage: "moon.zzz")
                        .font(.system(size: 11))
                        .foregroundColor(.inkMuted.opacity(0.65))
                }

                Button {
                    freeTimeManager.add(weekdays: selectedDays, startMinute: startMinute, endMinute: endMinute)
                } label: {
                    Text("더하기")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundColor(.onEmber)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.ember.opacity(canAdd ? 1 : 0.35)))
                }
                .disabled(!canAdd)
            }
            .padding(14)
            .background(card)
        }
    }

    private var canAdd: Bool { !selectedDays.isEmpty && startMinute != endMinute }

    private func quickChip(_ title: String, days: Set<Int>) -> some View {
        Button { selectedDays = days } label: {
            Text(title)
                .font(.system(size: 12, weight: selectedDays == days ? .semibold : .regular))
                .foregroundColor(.ember.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().stroke(Color.ember.opacity(selectedDays == days ? 0.6 : 0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: 정해 둔 시간

    private var blockList: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(String(localized: "정해 둔 자유시간"), icon: "hourglass")

            VStack(spacing: 0) {
                ForEach(freeTimeManager.blocks) { block in
                    HStack(spacing: 10) {
                        Text(FreeTimeBlock.weekdaySymbol(block.weekday))
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .foregroundColor(.ember.opacity(0.85))
                            .frame(width: 34, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(block.rangeString)
                                .font(.system(size: 14, design: .serif))
                                .foregroundColor(.ink.opacity(0.85))
                            if !block.fitsAwake(wakeMinute: wakeMinute, bedMinute: bedMinute) {
                                Label("잠자는 시간과 겹쳐요", systemImage: "moon.zzz")
                                    .font(.system(size: 10))
                                    .foregroundColor(.inkMuted.opacity(0.6))
                            }
                        }
                        Spacer()
                        Text(BurningParchmentView.durationString(TimeInterval(block.durationMinutes * 60)))
                            .font(.system(size: 12, design: .serif))
                            .foregroundColor(.inkMuted.opacity(0.6))
                        Button {
                            withAnimation { freeTimeManager.remove(block) }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundColor(.inkMuted.opacity(0.55))
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("지우기")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)

                    if block.id != freeTimeManager.blocks.last?.id {
                        Divider().background(Color.ember.opacity(0.08)).padding(.leading, 14)
                    }
                }
            }
            .background(card)
        }
    }

    private var proBanner: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.ember)
                VStack(alignment: .leading, spacing: 2) {
                    Text("프로에서 이 시간만 양피지가 타요")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundColor(.ember.opacity(0.9))
                    Text("자유시간이 지나갈 때만 불이 붙고, 밖에서는 꺼진 채 기다려요")
                        .font(.system(size: 11))
                        .foregroundColor(.inkMuted.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.inkMuted.opacity(0.4))
            }
            .padding(14)
            .background(card)
        }
        .buttonStyle(.plain)
    }

    // MARK: 공용

    private var card: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.ink.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.ember.opacity(0.1), lineWidth: 1))
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(.ember.opacity(0.6))
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.ember.opacity(0.5))
        }
    }

    private static func time(_ h: Int, _ m: Int) -> Date {
        Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
    }

    private static func minutes(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}
