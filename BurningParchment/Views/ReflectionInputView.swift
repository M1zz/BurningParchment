// ReflectionInputView.swift
// 회고 쓰기. ReflectionUrnView.swift 에서 나눴다 — 한 파일이 3천 줄이면 한 줄을 고쳐도 통째로 다시 컴파일된다.

import SwiftUI
import LeeoKit

// MARK: - Input View

struct ReflectionInputView: View {
    @EnvironmentObject var reflectionManager: ReflectionManager
    @Environment(\.dismiss) private var dismiss

    let existing: DayReflection?
    /// 새 재를 과거 날짜로 시작할 때 쓰인다 (기록 공백 회수). nil 이면 오늘.
    let initialDate: Date?

    @State private var text: String = ""
    @State private var keyword: String = ""
    @State private var tomorrowIntent: String = ""
    @State private var date: Date = Date()
    @State private var hasIntent: Bool? = nil
    @State private var spentTime: Bool? = nil
    @State private var driftFeeling: DriftFeeling? = nil
    @State private var currentStep: InputStep = .text
    @State private var sheetDetent: PresentationDetent = .height(340)
    @State private var savedReflectionId: UUID? = nil
    @State private var saveStatus: SaveStatus = .idle
    @State private var saveWorkItem: DispatchWorkItem? = nil
    @State private var classificationPoint: CGPoint? = nil
    @FocusState private var focusedField: FocusField?

    private enum SaveStatus { case idle, scheduled, saved }
    private enum InputStep: Int, CaseIterable { case text = 0, category, tomorrow }
    private enum FocusField: Hashable { case body, tomorrow }

    private func focusField(for step: InputStep) -> FocusField? {
        switch step {
        case .text: return .body
        case .category: return nil  // 분류 그래프가 키보드에 가리지 않도록 키보드를 내림
        case .tomorrow: return .tomorrow
        }
    }

    private let suggestions = [
        String(localized: "성장"), String(localized: "감사"), String(localized: "도전"), String(localized: "휴식"),
        String(localized: "배움"), String(localized: "관계"), String(localized: "실수"), String(localized: "기쁨")
    ]

    init(existing: DayReflection?, initialDate: Date? = nil) {
        self.existing = existing
        self.initialDate = initialDate
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.appBackgroundWarm.ignoresSafeArea()

            VStack(spacing: 0) {
                chromeBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        stepContent
                            .padding(.horizontal, 22)
                            .padding(.top, 4)
                            .id(currentStep)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))

                        HStack {
                            if currentStep == .tomorrow {
                                newEntryButton
                                Spacer()
                                closeButton
                            } else {
                                Spacer()
                                nextButton
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 6)

                        stepDots
                            .padding(.top, 2)

                        if (existing != nil || initialDate != nil) && currentStep == .text {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("날짜")
                                    .scaledFont(size: 12, weight: .medium)
                                    .foregroundColor(.inkMuted.opacity(0.55))
                                DatePicker("", selection: $date, displayedComponents: [.date])
                                    .datePickerStyle(.compact)
                                    .tint(.ember)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 22)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .presentationDetents(detentSet, selection: $sheetDetent)
        .presentationDragIndicator(.visible)
        .onAppear { setup() }
        .onDisappear { flushPendingSave() }
        .onChange(of: text) { scheduleAutoSave() }
        .onChange(of: keyword) { scheduleAutoSave() }
        .onChange(of: tomorrowIntent) { scheduleAutoSave() }
        .onChange(of: hasIntent) { scheduleAutoSave() }
        .onChange(of: spentTime) { scheduleAutoSave() }
        .onChange(of: driftFeeling) { scheduleAutoSave() }
        .onChange(of: date) { scheduleAutoSave() }
        .onChange(of: classificationPoint) { scheduleAutoSave() }
    }

    private var detentSet: Set<PresentationDetent> {
        switch currentStep {
        case .category: return [.large]
        default: return [.height(340), .large]
        }
    }

    // MARK: - Chrome Bar (작은 상단)

    private var chromeBar: some View {
        HStack {
            Button {
                flushPendingSave()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundColor(.inkMuted.opacity(0.75))
                    .frame(width: 38, height: 38)
            }
            .accessibilityLabel("닫기 — 지금까지 적은 내용은 저장됩니다")
            .accessibilityInputLabels([Text("닫기")])

            Spacer()

            destinationUrnLabel

            Spacer()

            saveIndicator
                .padding(.trailing, 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var saveIndicator: some View {
        switch saveStatus {
        case .idle:
            // 비어 있을 때 — 자리를 잡고 있되 거의 안 보이게
            HStack(spacing: 5) {
                Image(systemName: "circle.dotted")
                    .scaledFont(size: 15)
                Text("자동 저장")
                    .scaledFont(size: 11, design: .serif)
            }
            .foregroundColor(.inkMuted.opacity(0.35))
            .accessibilityLabel("아직 적힌 내용이 없습니다")

        case .scheduled:
            HStack(spacing: 5) {
                Image(systemName: "circle.dotted")
                    .scaledFont(size: 15)
                Text("저장 중…")
                    .scaledFont(size: 11, design: .serif)
            }
            .foregroundColor(.ember.opacity(0.7))
            .accessibilityLabel("저장 중")

        case .saved:
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .scaledFont(size: 16)
                Text("저장됨")
                    .scaledFont(size: 11, weight: .medium, design: .serif)
            }
            .foregroundColor(.successInk)
            .accessibilityLabel("저장됨")
        }
    }

    // MARK: - Wizard Steps

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .text:
            textEditor
        case .category:
            classificationSection
        case .tomorrow:
            tomorrowIntentSection
        }
    }

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(InputStep.allCases, id: \.rawValue) { step in
                Button {
                    goTo(step)
                } label: {
                    Circle()
                        .fill(step == currentStep ? Color.ember : Color.ember.opacity(0.18))
                        .frame(width: step == currentStep ? 8 : 5,
                               height: step == currentStep ? 8 : 5)
                }
                .accessibilityLabel(accessibilityLabel(for: step))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func accessibilityLabel(for step: InputStep) -> String {
        switch step {
        case .text: return String(localized: "본문 단계")
        case .category: return String(localized: "분류 단계")
        case .tomorrow: return String(localized: "내일 메모 단계")
        }
    }

    private var nextButton: some View {
        Button {
            advance()
        } label: {
            HStack(spacing: 6) {
                Text(nextLabel)
                    .scaledFont(size: 14, weight: .semibold, design: .serif)
                Image(systemName: nextIcon)
                    .scaledFont(size: 11, weight: .semibold)
            }
            .foregroundColor(canAdvance ? .white : .inkMuted.opacity(0.4))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(canAdvance ? Color.ember.opacity(0.85) : Color.ink.opacity(0.04))
            )
        }
        .disabled(!canAdvance)
        .accessibilityLabel(nextLabel)
        .accessibilityHint(nextHint)
    }

    /// .tomorrow step 좌측 — 현재 입력을 저장하고 새 회고 시작
    private var newEntryButton: some View {
        Button {
            startNewEntry()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .scaledFont(size: 11, weight: .semibold)
                Text("새 회고")
                    .scaledFont(size: 14, weight: .semibold, design: .serif)
            }
            .foregroundColor(canAdvance ? .ember.opacity(0.9) : .inkMuted.opacity(0.4))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.ink.opacity(0.04))
                    .overlay(
                        Capsule().stroke(
                            canAdvance ? Color.ember.opacity(0.45) : Color.ember.opacity(0.15),
                            lineWidth: 1
                        )
                    )
            )
        }
        .disabled(!canAdvance)
        .accessibilityLabel("새 회고")
        .accessibilityHint("지금까지 적은 회고를 저장하고 빈 입력칸으로 넘어갑니다")
    }

    /// .tomorrow step 우측 — 시트를 닫고 마침
    private var closeButton: some View {
        Button {
            flushPendingSave()
            dismiss()
        } label: {
            HStack(spacing: 6) {
                Text("닫기")
                    .scaledFont(size: 14, weight: .semibold, design: .serif)
                Image(systemName: "checkmark")
                    .scaledFont(size: 11, weight: .semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(Color.ember.opacity(0.85))
            )
        }
        .accessibilityLabel("닫기")
        .accessibilityHint("저장하고 시트를 닫습니다")
    }

    private var nextLabel: String {
        currentStep == .tomorrow ? String(localized: "새 회고") : String(localized: "다음")
    }

    private var nextIcon: String {
        currentStep == .tomorrow ? "plus.circle" : "arrow.right"
    }

    private var nextHint: String {
        switch currentStep {
        case .text:     return String(localized: "본문을 저장하고 분류 단계로 이동합니다")
        case .category: return String(localized: "분류를 저장하고 내일 메모 단계로 이동합니다")
        case .tomorrow: return String(localized: "저장하고 새 회고를 시작합니다")
        }
    }

    private var canAdvance: Bool {
        // text 단계에서만 본문 필수. 나머지는 비워두고 건너뛰기 가능.
        currentStep != .text || !trimmed.isEmpty
    }

    private func advance() {
        flushPendingSave()

        if let next = InputStep(rawValue: currentStep.rawValue + 1) {
            let gen = UISelectionFeedbackGenerator()
            gen.selectionChanged()
            if next == .category {
                // 분류 단계: 키보드 내리고 시트 풀스크린으로 펼침
                focusedField = nil
                sheetDetent = .large
            } else {
                focusedField = focusField(for: next)
                if next == .tomorrow { sheetDetent = .large }
            }
            withAnimation(.easeInOut(duration: 0.22)) {
                currentStep = next
                // 분류 그래프 단계는 하프모달로는 다 안 보임 — 시트를 끝까지 올림
                if next == .category { sheetDetent = .large }
            }
        } else {
            startNewEntry()
        }
    }

    private func goTo(_ step: InputStep) {
        guard step != currentStep else { return }
        flushPendingSave()
        let gen = UISelectionFeedbackGenerator()
        gen.selectionChanged()
        if step == .category {
            focusedField = nil
            sheetDetent = .large
        } else {
            focusedField = focusField(for: step)
        }
        withAnimation(.easeInOut(duration: 0.22)) {
            currentStep = step
            // 분류 그래프 단계는 하프모달로는 다 안 보임 — 시트를 끝까지 올림
            if step == .category { sheetDetent = .large }
        }
    }

    private func startNewEntry() {
        flushPendingSave()

        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)

        withAnimation(.easeInOut(duration: 0.2)) {
            text = ""
            keyword = ""
            tomorrowIntent = ""
            hasIntent = nil
            spentTime = nil
            driftFeeling = nil
            classificationPoint = nil
            currentStep = .text
        }

        savedReflectionId = nil
        saveStatus = .idle

        focusedField = .body
    }

    // MARK: - Sections

    private var textEditor: some View {
        TextField(
            existing == nil ? String(localized: "오늘 하루, 한 줄로 남겨봐요.") : String(localized: "회고를 수정합니다."),
            text: $text,
            axis: .vertical
        )
        .lineLimit(1...8)
        .focused($focusedField, equals: .body)
        .scaledFont(size: 20, design: .serif)
        .foregroundColor(.ember.opacity(0.95))
        .tint(.ember)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.ink.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.ember.opacity(focusedField == .body ? 0.35 : 0.18), lineWidth: 1)
                )
        )
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("다음") { if canAdvance { advance() } }
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(canAdvance ? .ember : .inkMuted.opacity(0.4))
                    .disabled(!canAdvance)
            }
        }
    }

    // MARK: - 담길 항아리 (작은 라벨)
    // 이제 항아리는 고르는 게 아니라 날짜가 정한다.  어디 담기는지만 조용히 알려준다.

    private var destinationPeriod: UrnPeriod { UrnPeriod.week(of: date) }

    private var destinationUrnLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: "archivebox.fill")
                .scaledFont(size: 10)
            Text(destinationPeriod.title)
                .scaledFont(size: 12, weight: .medium, design: .serif)
                .lineLimit(1)
        }
        .foregroundColor(.ember.opacity(0.6))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.ink.opacity(0.04))
                .overlay(Capsule().stroke(Color.ember.opacity(0.16), lineWidth: 1))
        )
        .accessibilityLabel("\(destinationPeriod.title) 항아리에 담깁니다")
    }

    private var classificationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더 자리에 안내 또는 카테고리 미리보기 — 그래프 아래엔 아무것도 추가 안 함
            classificationHeader

            ClassificationGraph(
                point: $classificationPoint,
                onPick: applyClassificationPoint
            )
            .frame(height: 220)
        }
    }

    @ViewBuilder
    private var classificationHeader: some View {
        if let cat = previewCategory {
            HStack(spacing: 6) {
                let rgb = cat.particleColor
                Circle()
                    .fill(Color(red: rgb.0, green: rgb.1, blue: rgb.2))
                    .frame(width: 9, height: 9)
                Text("→ \(cat.title)")
                    .scaledFont(size: 13, weight: .medium, design: .serif)
                    .foregroundColor(.ember.opacity(0.85))
            }
        } else {
            Text("오늘은 어떤 하루였나요? — 콕 찍어보세요")
                .scaledFont(size: 12, weight: .medium)
                .foregroundColor(.inkMuted.opacity(0.6))
        }
    }

    private func applyClassificationPoint(_ p: CGPoint) {
        hasIntent = p.x > 0.5
        spentTime = p.y > 0.5
        // 좌상 분면 (의지❌ 시간⭕️)은 accept 고정.  stop은 신규 작성에서 더 이상 만들어지지 않음.
        driftFeeling = (p.x < 0.5 && p.y > 0.5) ? .accept : nil
    }

    private func classificationToggle(title: String,
                                      yesLabel: String,
                                      noLabel: String,
                                      value: Binding<Bool?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .scaledFont(size: 12, weight: .medium)
                .foregroundColor(.ember.opacity(0.75))
            HStack(spacing: 8) {
                togglePill(label: yesLabel, isOn: value.wrappedValue == true) { value.wrappedValue = true }
                togglePill(label: noLabel,  isOn: value.wrappedValue == false) { value.wrappedValue = false }
            }
        }
    }

    private func togglePill(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .scaledFont(size: 13, weight: isOn ? .semibold : .regular)
                .foregroundColor(isOn ? .ember : .inkMuted.opacity(0.65))
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(isOn ? Color.ember.opacity(0.15) : Color.ink.opacity(0.04))
                        .overlay(Capsule().stroke(isOn ? Color.ember.opacity(0.45) : Color.ember.opacity(0.10), lineWidth: 1))
                )
        }
    }

    private var keywordSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("키워드 (선택)")
                .scaledFont(size: 12, weight: .medium)
                .foregroundColor(.inkMuted.opacity(0.55))

            TextField("", text: $keyword)
                .scaledFont(size: 14)
                .foregroundColor(.ember.opacity(0.9))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.ink.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.ember.opacity(0.15), lineWidth: 1))
                )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { s in
                        Button { keyword = s } label: {
                            Text("#\(s)")
                                .scaledFont(size: 12, weight: .medium)
                                .foregroundColor(keyword == s ? .ember : .inkMuted.opacity(0.6))
                                .padding(.vertical, 5)
                                .padding(.horizontal, 10)
                                .background(
                                    Capsule().fill(keyword == s
                                        ? Color.ember.opacity(0.15)
                                        : Color.ink.opacity(0.05))
                                )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tomorrow Intent

    private var tomorrowIntentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sunrise")
                    .scaledFont(size: 11)
                    .foregroundColor(.ember.opacity(0.7))
                Text(tomorrowQuestion)
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundColor(.inkMuted.opacity(0.65))
            }

            TextField(tomorrowPlaceholder, text: $tomorrowIntent)
                .scaledFont(size: 14, design: .serif)
                .foregroundColor(.ember.opacity(0.9))
                .focused($focusedField, equals: .tomorrow)
                .submitLabel(.done)
                .onSubmit { flushPendingSave(); dismiss() }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.ink.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.ember.opacity(0.18), lineWidth: 1))
                )

            Text("내일 아침, 양피지 상단에 띠로 떠올라 하루와 함께 타들어가요.")
                .scaledFont(size: 10)
                .foregroundColor(.inkMuted.opacity(0.45))
        }
    }

    /// 사용자가 그래프에서 찍은 분류에 따라 "내일 어떻게?" 질문 자체가 달라짐.
    private var tomorrowQuestion: String {
        guard let cat = previewCategory else { return String(localized: "내일 어떻게 해볼까요?") }
        switch cat {
        case .forged:    return String(localized: "더 잘 하려면 내일 무엇을 할까요?")
        case .missed:    return String(localized: "내일 새롭게 어떤 걸 시도해볼까요?")
        case .accept:    return String(localized: "이 시간을 내일은 어떻게 다룰까요?")
        case .stop:      return String(localized: "내일은 무엇을 끊어낼까요?")
        case .scattered: return String(localized: "내일은 어떻게 다르게 보낼까요?")
        case .uncategorized: return String(localized: "내일 어떻게 해볼까요?")
        }
    }

    private var tomorrowPlaceholder: String {
        guard let cat = previewCategory else { return String(localized: "예: 점심 직후 운동 30분") }
        switch cat {
        case .forged:    return String(localized: "예: 운동 시간을 30분 늘리기")
        case .missed:    return String(localized: "예: 점심 직후 운동 30분")
        case .accept:    return String(localized: "예: 산책 20분으로 바꾸기")
        case .stop:      return String(localized: "예: SNS 사용 15분 제한")
        case .scattered: return String(localized: "예: 책 한 챕터 읽기")
        case .uncategorized: return String(localized: "예: 점심 직후 운동 30분")
        }
    }

    // MARK: - Helpers

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var previewCategory: ReflectionCategory? {
        guard let i = hasIntent, let t = spentTime else { return nil }
        switch (i, t) {
        case (true, true):   return .forged
        case (true, false):  return .missed
        case (false, true):  return nil  // 분기 필요 (stop/accept)
        case (false, false): return .scattered
        }
    }

    private var canSave: Bool { !trimmed.isEmpty }

    private func setup() {
        if let e = existing {
            text = e.text
            keyword = e.keyword ?? ""
            date = e.date
            switch e.category {
            case .forged:    hasIntent = true;  spentTime = true
            case .missed:    hasIntent = true;  spentTime = false
            case .stop:      hasIntent = false; spentTime = true; driftFeeling = .stop
            case .accept:    hasIntent = false; spentTime = true; driftFeeling = .accept
            case .scattered: hasIntent = false; spentTime = false
            case .uncategorized: break
            }
            tomorrowIntent = e.tomorrowIntent ?? ""
            savedReflectionId = e.id
            saveStatus = .saved
            // 저장된 정확한 좌표가 있으면 그걸 복원.  없으면 카테고리에서 분면 대표 좌표로 역산.
            if let saved = e.classificationPoint {
                classificationPoint = saved
            } else {
                switch e.category {
                case .forged:    classificationPoint = CGPoint(x: 0.75, y: 0.75)
                case .missed:    classificationPoint = CGPoint(x: 0.75, y: 0.25)
                case .stop, .accept:
                                    classificationPoint = CGPoint(x: 0.25, y: 0.75)
                case .scattered: classificationPoint = CGPoint(x: 0.25, y: 0.25)
                case .uncategorized: classificationPoint = nil
                }
            }
        } else {
            date = initialDate ?? Date()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            focusedField = focusField(for: currentStep)
        }
    }


    // MARK: - Autosave

    private func canAutoSave() -> Bool {
        guard !trimmed.isEmpty else { return false }
        // 분류가 (의지❌, 시간⭕️)인데 drift 미선택이면 카테고리 확정 불가 → 저장 보류
        if hasIntent == false, spentTime == true, driftFeeling == nil {
            return false
        }
        return true
    }

    private func scheduleAutoSave() {
        saveWorkItem?.cancel()

        guard canAutoSave() else {
            // 텍스트가 비어 있거나 조건 미충족이면 인디케이터를 idle로 되돌림
            // 단, 이미 저장된 회고가 있고 사용자가 더 입력 중이면 saved 상태 유지
            if savedReflectionId == nil {
                saveStatus = .idle
            }
            return
        }

        saveStatus = .scheduled
        let work = DispatchWorkItem { performAutoSave() }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
    }

    private func flushPendingSave() {
        // 시트가 닫히거나 명시적 flush가 필요할 때 debounce를 건너뛰고 즉시 저장
        saveWorkItem?.cancel()
        saveWorkItem = nil
        guard canAutoSave() else { return }
        performAutoSave()
    }

    private func performAutoSave() {
        guard !trimmed.isEmpty else { return }

        let cat: ReflectionCategory = {
            if let i = hasIntent, let t = spentTime,
               let resolved = ReflectionCategory.from(intent: i, spentTime: t, drift: driftFeeling) {
                return resolved
            }
            return .uncategorized
        }()

        let trimmedIntent = tomorrowIntent.trimmingCharacters(in: .whitespacesAndNewlines)
        let intentToSave: String? = trimmedIntent.isEmpty ? nil : trimmedIntent
        let kw = keyword.isEmpty ? nil : keyword

        if let id = savedReflectionId,
           let existingRec = reflectionManager.reflections.first(where: { $0.id == id }) {
            // 이미 저장된 회고를 갱신
            var updated = existingRec
            updated.text = trimmed
            updated.category = cat
            updated.keyword = kw
            updated.tomorrowIntent = intentToSave
            updated.classificationPoint = classificationPoint
            updated.date = DayReflection.normalize(date)
            reflectionManager.update(updated)
        } else {
            // 새 회고 생성
            let created = reflectionManager.add(
                text: trimmed,
                category: cat,
                keyword: keyword,
                tomorrowIntent: intentToSave,
                classificationPoint: classificationPoint,
                date: date
            )
            savedReflectionId = created.id
            Moments.reflectionSaved()
        }

        saveStatus = .saved
    }
}
