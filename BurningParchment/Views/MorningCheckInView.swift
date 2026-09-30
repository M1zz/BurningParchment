// MorningCheckInView.swift
// 아침 확인 — 어젯밤 내일의 양피지가 얼마나 그을렸는지는 여기서 정해진다.
//
// 벌은 확인된 만큼만 준다.
//   · 건강 앱 수면 기록이 있으면 잠든 시각으로 되돌린다 (묻지 않는다)
//   · 없으면 한 번 묻는다. 기본 답은 "제시간에 잤어요" — 사용자를 믿는다
//   · 답하지 않고 닫으면 그을음 없이 넘어간다
// 제시간에 잠든 게 확인되면 불을 끄지 못했어도 "저절로 꺼진 조각"을 준다.

import SwiftUI

struct MorningCheckIn: Identifiable {
    enum Step { case ask, late, result, writeBack }
    let night: DateInterval
    let step: Step
    var id: Date { night.start }
}

struct MorningCheckInView: View {
    let night: DateInterval

    @EnvironmentObject var nightManager:    NightManager
    @EnvironmentObject var fragmentManager: FragmentManager
    @EnvironmentObject var excuseManager:   BedtimeExcuseManager
    @Environment(\.dismiss) private var dismiss

    @State private var step: MorningCheckIn.Step
    @State private var sleptAt: Date
    @State private var reason = ""
    @State private var nextAction = ""
    @State private var showsBack = false
    @State private var connecting = false
    @State private var healthMissing = false

    init(checkIn: MorningCheckIn) {
        self.night = checkIn.night
        _step = State(initialValue: checkIn.step)
        _sleptAt = State(initialValue: checkIn.night.start.addingTimeInterval(30 * 60))
    }

    private var record: NightRecord? { nightManager.record(forBedtime: night.start) }
    private var fragment: ParchmentFragment? { fragmentManager.fragment(forBedtime: night.start) }

    /// 잠든 시각으로 고를 수 있는 범위 — 취침 시각부터 기상 시각(또는 지금)까지
    private var sleepRange: ClosedRange<Date> {
        let end = max(min(night.end, Date()), night.start.addingTimeInterval(60))
        return night.start...end
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundWarm.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 26) {
                        switch step {
                        case .ask:       askStep
                        case .late:      lateStep
                        case .result:    resultStep
                        case .writeBack: writeBackStep
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                    .animation(.easeInOut(duration: 0.25), value: step)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(step == .ask || step == .late ? String(localized: "나중에") : String(localized: "닫기")) {
                        dismiss()
                    }
                    .font(.body)
                    .foregroundColor(.inkMuted)
                }
            }
        }
        .onAppear {
            if let suggested = record?.suggestedSleepAt, sleepRange.contains(suggested) {
                sleptAt = suggested
            }
        }
    }

    // MARK: - 1. 묻기

    private var askStep: some View {
        VStack(spacing: 24) {
            header(icon: "sunrise.fill",
                   title: String(localized: "어젯밤은 어땠나요?"),
                   subtitle: String(localized: "\(TimeFormat.short(night.start)) 이후 내일의 양피지가 탔어요.\n잠든 시각만큼만 그을음으로 남겨요."))

            if let hint = awakeHint {
                Text(hint)
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.inkMuted.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.ink.opacity(0.04)))
            }

            VStack(spacing: 12) {
                primaryButton(String(localized: "제시간에 잤어요")) {
                    nightManager.resolve(night, outcome: .reported, sleptAt: night.start)
                    step = .result
                }
                secondaryButton(String(localized: "늦게 잤어요")) { step = .late }
            }

            Text("답하지 않고 닫아도 괜찮아요. 확인되지 않은 밤은 그을음 없이 넘어가요.")
                .font(.body)
                .foregroundColor(.inkMuted.opacity(0.7))
                .multilineTextAlignment(.center)

            if SleepHealth.isAvailable && !SleepHealth.isConnected {
                healthCard
            } else if healthMissing {
                Text("건강 앱에 어젯밤 수면 기록이 없어요")
                    .font(.body)
                    .foregroundColor(.inkMuted.opacity(0.7))
            }
        }
    }

    /// 새벽까지 앱을 켜 두었거나 늦게 불을 껐던 흔적이 있으면 살짝 알려 준다. 판단은 사용자가 한다.
    private var awakeHint: String? {
        guard let rec = record else { return nil }
        if let out = rec.extinguishedAt, rec.lateSeconds(sleptAt: out) > 0 {
            return String(localized: "\(TimeFormat.short(out))에 후 불어 불을 껐어요")
        }
        if let seen = rec.lastAwakeAt, rec.lateSeconds(sleptAt: seen) > 0 {
            return String(localized: "\(TimeFormat.short(seen))에 앱을 열어 본 기록이 있어요")
        }
        return nil
    }

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("건강 앱 수면 기록 연결", systemImage: "heart.text.square")
                .font(.body.weight(.semibold))
                .foregroundColor(.ember.opacity(0.9))
            Text("연결하면 아침마다 묻지 않고, 기록된 잠든 시각으로 불을 되돌려요. 수면 기록은 읽기만 하고 기기 밖으로 보내지 않아요.")
                .font(.body)
                .foregroundColor(.inkMuted.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            Button {
                connecting = true
                Task {
                    await SleepHealth.connect()
                    let onset = await SleepHealth.sleepOnset(in: night)
                    connecting = false
                    if let onset {
                        nightManager.resolve(night, outcome: .health, healthOnset: onset)
                        step = .result
                    } else {
                        healthMissing = true
                    }
                }
            } label: {
                HStack {
                    if connecting { ProgressView().tint(.ember) }
                    Text("연결하기")
                        .font(.body.weight(.medium))
                }
                .foregroundColor(.ember)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().stroke(Color.ember.opacity(0.4), lineWidth: 1))
            }
            .disabled(connecting)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.ink.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.ember.opacity(0.15), lineWidth: 1))
        )
    }

    // MARK: - 2. 늦게 잤어요

    private var lateSeconds: TimeInterval {
        record?.lateSeconds(sleptAt: sleptAt)
            ?? NightRecord(bedtimeDate: night.start, wakeDate: night.end).lateSeconds(sleptAt: sleptAt)
    }

    private var lateStep: some View {
        VStack(spacing: 24) {
            header(icon: "moon.zzz.fill",
                   title: String(localized: "몇 시쯤 잠들었나요?"),
                   subtitle: String(localized: "대강이어도 괜찮아요"))

            DatePicker("잠든 시각", selection: $sleptAt, in: sleepRange, displayedComponents: [.hourAndMinute])
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

            Text(lateSeconds > 0
                 ? String(localized: "\(BurningParchmentView.durationString(lateSeconds)) 늦게 잠들었어요. 그만큼 오늘 아침이 그을려요")
                 : String(localized: "10분 안쪽은 제시간으로 쳐요"))
                .font(.system(.body, design: .serif))
                .foregroundColor(.ember.opacity(0.85))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 16) {
                field(title: String(localized: "무엇 때문에 늦었나요? (선택)"),
                      placeholder: String(localized: "솔직하게 적어보세요..."), text: $reason)
                field(title: String(localized: "오늘은 어떻게 해 볼까요? (선택)"),
                      placeholder: String(localized: "작은 변화부터 시작해도 괜찮아요..."), text: $nextAction)
            }

            if let recent = excuseManager.thisWeekPastExcuses.first {
                VStack(alignment: .leading, spacing: 6) {
                    Label("이번 주에도 있었어요", systemImage: "clock.arrow.circlepath")
                        .font(.body.weight(.medium))
                        .foregroundColor(.ember.opacity(0.75))
                    Text(verbatim: "\(recent.dateString) · \(recent.reason)")
                        .font(.system(.body, design: .serif))
                        .foregroundColor(.inkMuted.opacity(0.8))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            primaryButton(String(localized: "기록하기")) {
                nightManager.resolve(night, outcome: .reported, sleptAt: sleptAt)
                if !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    excuseManager.add(reason: reason, nextAction: nextAction,
                                      date: record?.nightDate ?? night.start)
                }
                step = .result
            }
        }
    }

    // MARK: - 3. 결과

    @ViewBuilder
    private var resultStep: some View {
        if let rec = record, rec.charredSeconds > 0 {
            VStack(spacing: 20) {
                header(icon: "flame",
                       title: String(localized: "오늘 아침이 조금 그을렸어요"),
                       subtitle: String(localized: "어젯밤 \(BurningParchmentView.durationString(rec.charredSeconds)) 늦게 잠들었어요.\n오늘 저녁엔 조금 일찍 불을 꺼 봐요."))

                if rec.outcome == .health, let onset = rec.sleepOnset {
                    Text("건강 앱 기록: \(TimeFormat.short(onset))에 잠들었어요")
                        .font(.body)
                        .foregroundColor(.inkMuted.opacity(0.8))
                    Button {
                        sleptAt = min(max(onset, sleepRange.lowerBound), sleepRange.upperBound)
                        step = .late
                    } label: {
                        Text("기록이 틀렸나요? 직접 고치기")
                            .font(.body.weight(.medium))
                            .foregroundColor(.ember.opacity(0.85))
                    }
                }

                primaryButton(String(localized: "확인")) { dismiss() }
            }
        } else if let fragment {
            VStack(spacing: 20) {
                header(icon: "moon.stars.fill",
                       title: fragment.isFellAsleep
                           ? String(localized: "저절로 꺼진 조각을 모았어요")
                           : String(localized: "어젯밤 조각이 식었어요"),
                       subtitle: fragment.isFellAsleep
                           ? String(localized: "불을 끄지 못했어도, 제시간에 잠들었으니 불은 저절로 꺼졌어요.")
                           : String(localized: "뒤집어서 뒷면에 한 줄을 남겨 보세요."))
                if record?.outcome == .health, let onset = record?.sleepOnset {
                    Text("건강 앱 기록: \(TimeFormat.short(onset))에 잠들었어요")
                        .font(.body)
                        .foregroundColor(.inkMuted.opacity(0.8))
                }
                backWriting(fragment)
            }
        } else {
            ProgressView().tint(.ember)
                .onAppear(perform: grantFellAsleepFragment)
        }
    }

    /// 제시간에 잠든 게 확인된 밤에는 불을 끄지 못했어도 조각을 준다
    private func grantFellAsleepFragment() {
        guard fragment == nil, let rec = record, rec.isResolved, rec.charredSeconds == 0,
              rec.outcome == .health || rec.outcome == .reported else { return }
        fragmentManager.add(.fellAsleep(bedtimeDate: night.start))
    }

    // MARK: - 4. 뒷면 쓰기

    @ViewBuilder
    private var writeBackStep: some View {
        if let fragment {
            VStack(spacing: 20) {
                header(icon: "moon.stars.fill",
                       title: String(localized: "어젯밤 조각이 식었어요"),
                       subtitle: String(localized: "뒤집어서 뒷면에 한 줄을 남겨 보세요."))
                backWriting(fragment)
            }
        }
    }

    private func backWriting(_ fragment: ParchmentFragment) -> some View {
        VStack(spacing: 20) {
            FragmentFlipCard(fragment: fragment, showsBack: $showsBack)
                .frame(height: 190)
            if fragment.isBackWritten && showsBack {
                primaryButton(String(localized: "완료")) { dismiss() }
            } else {
                FragmentBackEditor(fragment: fragment) { showsBack = true }
                    .environmentObject(fragmentManager)
            }
        }
    }

    // MARK: - Parts

    private func header(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundColor(.ember.opacity(0.7))
            Text(title)
                .font(.system(.title2, design: .serif).weight(.medium))
                .foregroundColor(.ember.opacity(0.9))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(.body, design: .serif))
                .foregroundColor(.inkMuted.opacity(0.8))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundColor(.onEmber)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(Color.ember))
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundColor(.ember)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().stroke(Color.ember.opacity(0.45), lineWidth: 1))
        }
    }

    private func field(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundColor(.inkMuted)
            TextField(placeholder, text: text, axis: .vertical)
                .font(.system(.body, design: .serif))
                .foregroundColor(.ink)
                .lineLimit(1...4)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.ink.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.ember.opacity(0.2), lineWidth: 1))
                )
        }
    }
}
