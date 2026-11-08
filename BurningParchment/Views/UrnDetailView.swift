// UrnDetailView.swift
// 항아리 안쪽 · 항아리 의미 고치기. ReflectionUrnView.swift 에서 나눴다 — 한 파일이 3천 줄이면 한 줄을 고쳐도 통째로 다시 컴파일된다.

import SwiftUI
import LeeoKit

// MARK: - Urn Detail
//
// 달 항아리를 열면 그 달의 주 항아리들이, 주 항아리를 열면 담긴 재들이 나온다.
// 어느 쪽이든 맨 위에는 "이건 당신에게 무엇이었나"를 묻는 자리가 있다.

struct UrnDetailView: View {
    @EnvironmentObject var reflectionManager: ReflectionManager
    @EnvironmentObject var storeManager: StoreManager

    let period: UrnPeriod

    @State private var editing: DayReflection? = nil
    @State private var meaningTarget: UrnPeriod? = nil

    private var meaning: UrnMeaning? { reflectionManager.meaning(for: period) }
    private var hasMeaning: Bool { meaning != nil }

    var body: some View {
        ZStack {
            Color.appBackgroundWarm.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    hero
                    meaningCard
                    countsBreakdown

                    if period.scope == .month {
                        weekShelf
                    } else {
                        ashList
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(period.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { item in
            ReflectionInputView(existing: item)
                .environmentObject(reflectionManager)
        }
        .sheet(item: $meaningTarget) { p in
            UrnMeaningEditView(period: p)
                .environmentObject(reflectionManager)
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 8) {
            MixedAshUrnVisual(
                seed: period.id,
                fillLevel: reflectionManager.fillLevel(for: period),
                counts: reflectionManager.categoryCounts(for: period),
                hasMeaning: hasMeaning
            )
            .frame(width: 180, height: 200)
            .padding(.top, 8)
            .accessibilityHidden(true)

            Text(period.rangeLabel)
                .scaledFont(size: 12, design: .serif)
                .foregroundColor(.inkMuted.opacity(0.5))
        }
    }

    // MARK: 의미
    // 재는 저절로 쌓이지만, 그게 무엇이었는지는 사용자만 정할 수 있다.

    @ViewBuilder
    private var meaningCard: some View {
        if let m = meaning {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(m.displayName)
                        .scaledFont(size: 17, weight: .semibold, design: .serif)
                        .foregroundColor(.ember.opacity(0.92))
                    Spacer(minLength: 8)
                    Button {
                        meaningTarget = period
                    } label: {
                        Text("고쳐 적기")
                            .scaledFont(size: 12, weight: .medium)
                            .foregroundColor(.ember.opacity(0.7))
                    }
                }

                if !m.trimmedText.isEmpty, m.trimmedText != m.displayName {
                    Text(m.trimmedText)
                        .scaledFont(size: 14, design: .serif)
                        .foregroundColor(.inkMuted.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.ember.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.ember.opacity(0.22), lineWidth: 1))
            )
            .padding(.horizontal, 16)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("아직은 그냥 재예요")
                    .scaledFont(size: 15, weight: .semibold, design: .serif)
                    .foregroundColor(.inkMuted.opacity(0.7))

                Text("여기 담긴 것들은 당신이 이름을 붙이기 전까진 그냥 재예요.")
                    .scaledFont(size: 12, design: .serif)
                    .foregroundColor(.inkMuted.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)

                Text(meaningQuestion)
                    .scaledFont(size: 15, weight: .medium, design: .serif)
                    .foregroundColor(.ember.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                Button {
                    meaningTarget = period
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                            .scaledFont(size: 12, weight: .semibold)
                        Text("의미 적기")
                            .scaledFont(size: 14, weight: .semibold, design: .serif)
                    }
                    .foregroundColor(.ember)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 16)
                    .background(
                        Capsule().fill(Color.ember.opacity(0.15))
                            .overlay(Capsule().stroke(Color.ember.opacity(0.35), lineWidth: 1))
                    )
                }
                .padding(.top, 2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.ink.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.inkMuted.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4])))
            )
            .padding(.horizontal, 16)
        }
    }

    private var meaningQuestion: String {
        period.scope == .week
            ? String(localized: "이 주는 당신에게 어떤 의미였나요?")
            : String(localized: "이 달은 당신에게 어떤 의미였나요?")
    }

    // MARK: 재의 구성

    private var countsBreakdown: some View {
        let counts = reflectionManager.categoryCounts(for: period)
        return HStack(spacing: 8) {
            ForEach([ReflectionCategory.forged, .missed, .stop, .accept, .scattered], id: \.self) { cat in
                let rgb: (Double, Double, Double) = hasMeaning ? cat.particleColor : (0.60, 0.58, 0.55)
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color(red: rgb.0, green: rgb.1, blue: rgb.2))
                        .frame(width: 10, height: 10)
                    Text("\(counts[cat] ?? 0)")
                        .scaledFont(size: 14, weight: .semibold, design: .monospaced)
                        .foregroundColor(.ember.opacity(hasMeaning ? 0.85 : 0.45))
                    Text(cat.shortLabel)
                        .scaledFont(size: 10)
                        .foregroundColor(.inkMuted.opacity(0.55))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.ink.opacity(0.025))
                )
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: 달 항아리 → 주 항아리 선반

    private var weekShelf: some View {
        let weeks = reflectionManager.weekPeriods(in: period)
        return VStack(alignment: .leading, spacing: 10) {
            Text("이 달의 주 항아리")
                .scaledFont(size: 13, weight: .semibold, design: .serif)
                .foregroundColor(.ember.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: 12) {
                ForEach(weeks) { week in
                    NavigationLink {
                        UrnDetailView(period: week)
                            .environmentObject(reflectionManager)
                            .environmentObject(storeManager)
                    } label: {
                        weekCell(week)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func weekCell(_ week: UrnPeriod) -> some View {
        let count = reflectionManager.reflectionCount(in: week)
        let m = reflectionManager.meaning(for: week)
        return VStack(spacing: 6) {
            MixedAshUrnVisual(
                seed: week.id,
                fillLevel: reflectionManager.fillLevel(for: week),
                counts: reflectionManager.categoryCounts(for: week),
                hasMeaning: m != nil
            )
            .frame(width: 62, height: 70)
            .accessibilityHidden(true)

            Text(week.shortTitle)
                .scaledFont(size: 12, weight: .semibold, design: .serif)
                .foregroundColor(.ember.opacity(0.85))

            Text(m?.displayName ?? String(localized: "재 \(count)톨"))
                .scaledFont(size: 10, design: .serif)
                .foregroundColor(.inkMuted.opacity(m == nil ? 0.45 : 0.7))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.ink.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.ember.opacity(0.08), lineWidth: 1))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(week.accessibilityLabel)
        .accessibilityValue((m?.displayName ?? String(localized: "아직 이름 없는 재"))
            + ", " + String(localized: "재 \(count)톨"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: 주 항아리 → 재 목록

    @ViewBuilder
    private var ashList: some View {
        let items = reflectionManager.reflections(in: period)
        if items.isEmpty {
            Text("이 항아리는 비어 있어요.")
                .scaledFont(size: 13, design: .serif)
                .foregroundColor(.inkMuted.opacity(0.5))
                .padding(.top, 12)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("담긴 재")
                    .scaledFont(size: 13, weight: .semibold, design: .serif)
                    .foregroundColor(.ember.opacity(0.8))

                ForEach(items) { item in
                    Button { editing = item } label: {
                        ReflectionRow(item: item, muted: !hasMeaning)
                    }
                    .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = item.text
                            } label: {
                                Label("복사", systemImage: "doc.on.doc")
                            }
                            Button(role: .destructive) {
                                reflectionManager.delete(id: item.id)
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                        .accessibilityAction(named: Text("삭제")) { reflectionManager.delete(id: item.id) }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Urn Meaning Edit
//
// 항아리에 의미를 새기는 화면.  담긴 재를 다시 보여주면서 "이건 당신에게 무엇이었나"를 묻는다.

struct UrnMeaningEditView: View {
    @EnvironmentObject var reflectionManager: ReflectionManager
    @Environment(\.dismiss) private var dismiss

    let period: UrnPeriod

    @State private var name: String = ""
    @State private var text: String = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case name, body }

    private var existing: UrnMeaning? { reflectionManager.meaning(for: period) }

    private var question: String {
        period.scope == .week
            ? String(localized: "이 주는 당신에게 어떤 의미였나요?")
            : String(localized: "이 달은 당신에게 어떤 의미였나요?")
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackgroundWarm.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        ashPreview
                        nameField
                        bodyField
                        if existing != nil { clearButton }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Label("취소", systemImage: "xmark") }
                        .foregroundColor(.inkMuted)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { save() } label: { Label("새기기", systemImage: "checkmark") }
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(canSave ? .ember : .inkMuted)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear {
            if let m = existing {
                name = m.name
                text = m.text
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                focusedField = .name
            }
        }
    }

    // MARK: Header

    private var header: some View {
        let count = reflectionManager.reflectionCount(in: period)
        return HStack(spacing: 14) {
            MixedAshUrnVisual(
                seed: period.id,
                fillLevel: reflectionManager.fillLevel(for: period),
                counts: reflectionManager.categoryCounts(for: period),
                hasMeaning: existing != nil
            )
            .frame(width: 54, height: 60)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(period.title)
                    .scaledFont(size: 17, weight: .semibold, design: .serif)
                    .foregroundColor(.ember.opacity(0.9))
                Text(period.rangeLabel)
                    .scaledFont(size: 11, design: .serif)
                    .foregroundColor(.inkMuted.opacity(0.5))
                Text("재 \(count)톨")
                    .scaledFont(size: 11, design: .monospaced)
                    .foregroundColor(.inkMuted.opacity(0.5))
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: 담긴 재 미리보기
    // 무엇에 의미를 붙이는지 눈앞에 두고 적게 한다.

    @ViewBuilder
    private var ashPreview: some View {
        let items = reflectionManager.reflections(in: period)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("이 항아리에 남은 것들")
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundColor(.inkMuted.opacity(0.55))

                ForEach(items.prefix(6)) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color(red: 0.60, green: 0.58, blue: 0.55))
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(item.text)
                            .scaledFont(size: 13, design: .serif)
                            .foregroundColor(.inkMuted.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                            // 지난 회고를 길게 눌러 골라 복사할 수 있게 한다
                            .textSelection(.enabled)
                        Spacer(minLength: 0)
                    }
                }

                if items.count > 6 {
                    Text("외 \(items.count - 6)톨")
                        .scaledFont(size: 11, design: .serif)
                        .foregroundColor(.inkMuted.opacity(0.4))
                        .padding(.leading, 13)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.ink.opacity(0.025))
            )
        }
    }

    // MARK: 입력

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .scaledFont(size: 15, weight: .semibold, design: .serif)
                .foregroundColor(.ember.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            Text("항아리에 새길 한 마디")
                .scaledFont(size: 12, weight: .medium)
                .foregroundColor(.inkMuted.opacity(0.55))

            TextField("예: 버텨낸 주", text: $name)
                .scaledFont(size: 17, design: .serif)
                .foregroundColor(.ember.opacity(0.95))
                .tint(.ember)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .body }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.ink.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.ember.opacity(focusedField == .name ? 0.35 : 0.18), lineWidth: 1))
                )
        }
    }

    private var bodyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("조금 더 적어두고 싶다면 (선택)")
                .scaledFont(size: 12, weight: .medium)
                .foregroundColor(.inkMuted.opacity(0.55))

            TextField("여기 쌓인 재가 나에게 무엇이었는지…", text: $text, axis: .vertical)
                .lineLimit(3...10)
                .scaledFont(size: 15, design: .serif)
                .foregroundColor(.ember.opacity(0.9))
                .tint(.ember)
                .focused($focusedField, equals: .body)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.ink.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.ember.opacity(focusedField == .body ? 0.35 : 0.15), lineWidth: 1))
                )
        }
    }

    private var clearButton: some View {
        Button(role: .destructive) {
            reflectionManager.removeMeaning(for: period)
            dismiss()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "eraser")
                    .scaledFont(size: 12)
                Text("의미 지우기")
                    .scaledFont(size: 13, weight: .medium)
            }
            .foregroundColor(.emberDeep.opacity(0.7))
        }
        .accessibilityHint("이 항아리를 다시 이름 없는 재로 되돌립니다")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard canSave else { return }
        reflectionManager.setMeaning(name: name, text: text, for: period)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        dismiss()
    }
}
