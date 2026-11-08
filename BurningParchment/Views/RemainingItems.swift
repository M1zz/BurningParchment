// RemainingItems.swift
// 세어 보기 — 얼마나 보냈는지, 앞으로 얼마나 남았는지, 그동안 어떤 패턴인지만 받아서 그린다.
//
// 크리스마스는 해마다 한 번이지만, 부모님과의 시간은 그렇지 않다.
// 처음 스무 해는 1년에 365일을 함께 보내다가 그 뒤로는 1년에 엿새뿐이라면, 함께할 날은 이미 대부분 지나갔다.
// 그래서 패턴을 구간으로 나눠 셈한다. 자유시간도 같은 방식으로 세는 한 종류다.

import SwiftUI

// MARK: - 모델

enum RemainingUnit: String, Codable, CaseIterable, Identifiable {
    case day, times, hour
    var id: String { rawValue }

    var label: String {
        switch self {
        case .day:   return String(localized: "며칠")
        case .times: return String(localized: "몇 번")
        case .hour:  return String(localized: "몇 시간")
        }
    }

    func format(_ n: Int) -> String {
        switch self {
        case .day:   return String(localized: "\(n)일")
        case .times: return String(localized: "\(n)번")
        case .hour:  return String(localized: "\(n)시간")
        }
    }

    /// 숫자 뒤에 붙는 단위 낱말
    var suffix: String {
        switch self {
        case .day:   return String(localized: "unit.day")
        case .times: return String(localized: "unit.times")
        case .hour:  return String(localized: "unit.hour")
        }
    }

    /// 1년에 넣을 수 있는 가장 큰 값
    var maxPerYear: Double {
        switch self {
        case .day:   return 366
        case .times: return 10_000
        case .hour:  return 8_784
        }
    }
}

struct RemainingItem: Codable, Identifiable, Equatable {
    struct Phase: Codable, Identifiable, Equatable {
        var id = UUID()
        /// 시작부터 몇 해째까지 (마지막 구간은 nil — 그 뒤로 쭉)
        var untilYear: Int?
        var perYear: Double
    }

    var id = UUID()
    var name: String
    var symbol: String
    var unit: RemainingUnit
    /// 해 순서. 마지막 구간의 `untilYear` 는 늘 nil 이다.
    var phases: [Phase]
    /// 세기 시작한 때 (저장할 때 "얼마나 보냈나요" 만큼 거슬러 올라간 날)
    var startDate: Date
    /// 처음부터 끝까지 몇 해인지 (보낸 해 + 남은 해)
    var spanYears: Double

    static let freeTimeID = UUID(uuidString: "00000000-0000-0000-0000-00000000F7EE")!
    static let symbols = ["person.2.fill", "heart.fill", "house.fill", "figure.2.and.child.holdinghands",
                          "pawprint.fill", "airplane", "book.fill", "music.note", "fork.knife", "star.fill"]

    var selectionID: String { id == Self.freeTimeID ? RemainingKind.freeTime : "custom:\(id.uuidString)" }
    var isFreeTime: Bool { id == Self.freeTimeID }

    private static let year: TimeInterval = 365.2425 * 86_400

    func elapsedYears(now: Date = Date()) -> Double {
        min(spanYears, max(0, now.timeIntervalSince(startDate) / Self.year))
    }

    var past: Int { Int(amount(from: 0, to: elapsedYears()).rounded()) }
    var remaining: Int { Int(amount(from: elapsedYears(), to: spanYears).rounded()) }

    /// 시작부터 a 해째에서 b 해째까지 쌓이는 양
    func amount(from a: Double, to b: Double) -> Double {
        guard b > a else { return 0 }
        var start = 0.0
        var sum = 0.0
        for p in phases {
            let end = Double(p.untilYear ?? 10_000)
            let overlap = min(b, end) - max(a, start)
            if overlap > 0 { sum += overlap * p.perYear }
            start = end
        }
        return sum
    }

    /// 보낸 해 · 남은 해로 시작과 길이를 다시 정한다
    mutating func set(pastYears: Int, remainingYears: Int, now: Date = Date()) {
        startDate = now.addingTimeInterval(-Double(pastYears) * Self.year)
        spanYears = Double(pastYears + remainingYears)
    }

    /// 구간을 해 순서로 세우고, 겹치거나 거꾸로 된 경계를 바로잡는다
    mutating func normalize() {
        guard !phases.isEmpty else { phases = [Phase(untilYear: nil, perYear: 0)]; return }
        let last = phases.first { $0.untilYear == nil } ?? phases[phases.count - 1]
        var bounded = phases.filter { $0.id != last.id && $0.untilYear != nil }
            .sorted { ($0.untilYear ?? 0) < ($1.untilYear ?? 0) }
        var prev = 0
        for i in bounded.indices {
            let v = max(prev + 1, min(119, bounded[i].untilYear ?? prev + 1))
            bounded[i].untilYear = v
            prev = v
        }
        var tail = last
        tail.untilYear = nil
        phases = bounded + [tail]
    }

    /// 새로 만들 때의 예 — 부모님과의 시간
    static func template(pastYears: Int, remainingYears: Int) -> RemainingItem {
        var item = RemainingItem(name: "", symbol: "person.2.fill", unit: .day,
                                 phases: [Phase(untilYear: 20, perYear: 365), Phase(untilYear: nil, perYear: 6)],
                                 startDate: Date(), spanYears: 0)
        item.set(pastYears: pastYears, remainingYears: remainingYears)
        return item
    }

    /// 자유시간 — 정해 둔 자유시간이 있으면 그 주간 시간을 1년으로 늘려 패턴으로 쓴다
    static func freeTimeTemplate(pastYears: Int, remainingYears: Int, weeklyMinutes: Int) -> RemainingItem {
        let perYear = weeklyMinutes > 0 ? (Double(weeklyMinutes) / 60 * 52).rounded() : 730
        var item = RemainingItem(id: freeTimeID, name: String(localized: "자유시간"), symbol: "hourglass", unit: .hour,
                                 phases: [Phase(untilYear: nil, perYear: perYear)],
                                 startDate: Date(), spanYears: 0)
        item.set(pastYears: pastYears, remainingYears: remainingYears)
        return item
    }
}

/// 세어 둔 것들을 UserDefaults 에 JSON 으로 둔다
enum RemainingItemStore {
    static let key = "remainingItems"

    static func decode(_ data: Data) -> [RemainingItem] {
        (try? JSONDecoder().decode([RemainingItem].self, from: data)) ?? []
    }

    static func encode(_ items: [RemainingItem]) -> Data {
        (try? JSONEncoder().encode(items)) ?? Data()
    }

    static func upsert(_ item: RemainingItem, in data: Data) -> Data {
        var items = decode(data)
        if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = item } else { items.append(item) }
        return encode(items)
    }

    static func remove(_ id: UUID, in data: Data) -> Data {
        encode(decode(data).filter { $0.id != id })
    }

    /// 이 저장이 세어 둔 것(자유시간 제외)을 **새로** 하나 더하는가. 그렇다면 지금 개수를, 아니면 nil.
    /// 한도는 새로 만들 때만 건다 — 이미 있는 것을 고치는 건 누구든 그대로 된다.
    static func countBeforeAdding(_ item: RemainingItem, in data: Data) -> Int? {
        let items = decode(data)
        guard !item.isFreeTime, !items.contains(where: { $0.id == item.id }) else { return nil }
        return items.filter { !$0.isFreeTime }.count
    }
}

// MARK: - 세어 보기 (세 가지 질문)

/// 얼마나 보냈나요 · 앞으로 얼마나 남았나요 · 어떤 패턴인가요
struct CountSetupForm: View {
    @Binding var item: RemainingItem
    @Binding var pastYears: Int
    @Binding var remainingYears: Int
    var nameEditable = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if nameEditable { nameCard }
            question(String(localized: "얼마나 보냈나요"),
                     hint: item.isFreeTime ? String(localized: "지금 내 나이")
                                           : String(localized: "부모님과의 시간이라면 지금 내 나이")) {
                Stepper(value: $pastYears, in: 0...120) { yearsText(pastYears) }
            }
            question(String(localized: "앞으로 얼마나 남았나요"),
                     hint: item.isFreeTime ? String(localized: "기대 수명까지 남은 해. 짐작이면 충분해요")
                                           : String(localized: "부모님과의 시간이라면 부모님이 기대 수명까지 남은 해")) {
                Stepper(value: $remainingYears, in: 0...120) { yearsText(remainingYears) }
            }
            question(String(localized: "어떤 패턴인가요"),
                     hint: item.isFreeTime ? String(localized: "예: 학생 때는 1년에 2,000시간, 일을 시작한 뒤로는 평일 저녁 2시간과 주말이면 1년에 약 1,100시간")
                                           : String(localized: "예: 처음 20년은 1년에 365일, 그 뒤로는 명절과 휴가로 1년에 6일")) {
                patternEditor
            }
            preview
        }
    }

    private func yearsText(_ n: Int) -> some View {
        Text("\(n)년")
            .font(.system(.title3, design: .serif).weight(.semibold))
            .foregroundColor(.ember)
            .monospacedDigit()
    }

    private var nameCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                TextField("부모님과의 시간", text: $item.name)
                    .font(.system(.title3, design: .serif))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(RemainingItem.symbols, id: \.self) { s in
                            Button { item.symbol = s } label: {
                                Image(systemName: s)
                                    .font(.body)
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(item.symbol == s ? .onEmber : .ink.opacity(0.7))
                                    .background(Circle().fill(item.symbol == s ? Color.ember : Color.ink.opacity(0.05)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(item.symbol == s ? .isSelected : [])
                        }
                    }
                }
            }
        }
    }

    private var patternEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("단위", selection: $item.unit) {
                ForEach(RemainingUnit.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            ForEach($item.phases) { $phase in
                phaseRow($phase)
                Divider().background(Color.ember.opacity(0.12))
            }

            Button { splitPhase() } label: {
                Label("구간 나누기", systemImage: "plus")
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.ember)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func phaseRow(_ phase: Binding<RemainingItem.Phase>) -> some View {
        let p = phase.wrappedValue
        let idx = item.phases.firstIndex { $0.id == p.id } ?? 0
        let lower = idx > 0 ? (item.phases[idx - 1].untilYear ?? 0) : 0
        let upper = idx + 1 < item.phases.count ? (item.phases[idx + 1].untilYear ?? 120) : 120
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let until = p.untilYear {
                    Stepper(value: Binding(get: { until }, set: { phase.wrappedValue.untilYear = $0 }),
                            in: (lower + 1)...max(lower + 1, upper - 1)) {
                        Text(lower == 0 ? String(localized: "처음 \(until)년") : String(localized: "\(lower)년 뒤부터 \(until)년까지"))
                            .font(.system(.body, design: .serif).weight(.medium))
                            .monospacedDigit()
                    }
                } else {
                    Text(item.phases.count == 1 ? String(localized: "내내") : String(localized: "그 뒤로 쭉"))
                        .font(.system(.body, design: .serif).weight(.medium))
                    Spacer()
                }
                if item.phases.count > 1 {
                    Button {
                        item.phases.removeAll { $0.id == p.id }
                        item.normalize()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.body)
                            .foregroundColor(.inkMuted.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("구간 지우기")
                }
            }
            HStack {
                Text("1년에")
                    .font(.system(.body, design: .serif))
                TextField("0", value: phase.perYear, format: .number.precision(.fractionLength(0...1)))
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.ink.opacity(0.05)))
                    .frame(maxWidth: 120)
                    .onChange(of: p.perYear) { _, v in
                        let clamped = min(max(v, 0), item.unit.maxPerYear)
                        if clamped != v { phase.wrappedValue.perYear = clamped }
                    }
                Text(item.unit.suffix)
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.inkMuted)
            }
        }
    }

    /// 마지막 구간 앞에 새 경계를 넣는다
    private func splitPhase() {
        let lastBound = item.phases.dropLast().last?.untilYear ?? 0
        let until = min(119, lastBound + 10)
        guard until > lastBound else { return }
        let perYear = item.phases.last?.perYear ?? 0
        item.phases.insert(.init(untilYear: until, perYear: perYear), at: item.phases.count - 1)
        item.normalize()
    }

    private var preview: some View {
        var draft = item
        draft.set(pastYears: pastYears, remainingYears: remainingYears)
        return VStack(spacing: 10) {
            if draft.phases.count > 1 && draft.spanYears > 0 {
                CountCurveChart(item: draft)
                    .frame(height: 96)
                    .padding(.top, 14)
            }
            HStack {
            Text("지나온 \(item.unit.format(draft.past))")
                .foregroundColor(.inkMuted)
            Spacer()
            Text("남은 \(item.unit.format(draft.remaining))")
                .foregroundColor(.ember)
            }
            .font(.system(.body, design: .serif).weight(.medium))
            .monospacedDigit()
        }
        .padding(.horizontal, 4)
    }

    private func question<Content: View>(_ title: String, hint: String, @ViewBuilder content: () -> Content) -> some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .foregroundColor(.ink)
                content()
                Text(hint)
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.inkMuted.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.ink.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.ember.opacity(0.12), lineWidth: 1))
            )
    }
}

/// 페이지 안에서 바로 세어 보기. 저장하면 같은 자리에 그림이 선다.
struct CountSetupPage: View {
    @EnvironmentObject var storeManager: StoreManager
    @AppStorage(RemainingItemStore.key) private var itemsData = Data()
    @State private var showPaywall = false
    @State private var item: RemainingItem
    @State private var pastYears: Int
    @State private var remainingYears: Int
    private let nameEditable: Bool
    var onSave: (RemainingItem) -> Void

    init(item: RemainingItem, nameEditable: Bool, onSave: @escaping (RemainingItem) -> Void = { _ in }) {
        _item = State(initialValue: item)
        let past = Int(item.elapsedYears().rounded())
        _pastYears = State(initialValue: past)
        _remainingYears = State(initialValue: max(0, Int(item.spanYears.rounded()) - past))
        self.nameEditable = nameEditable
        self.onSave = onSave
    }

    private var canSave: Bool { !item.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("세어 보기")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundColor(.ember.opacity(0.9))
                CountSetupForm(item: $item, pastYears: $pastYears, remainingYears: $remainingYears, nameEditable: nameEditable)
                Button(action: save) {
                    Text("세어 보기")
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .foregroundColor(.onEmber)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(canSave ? Color.ember : Color.inkMuted.opacity(0.3)))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .count).environmentObject(storeManager)
        }
    }

    private func save() {
        if let count = RemainingItemStore.countBeforeAdding(item, in: itemsData),
           !storeManager.canAddCount(currentCount: count) {
            showPaywall = true
            return
        }
        item.name = item.name.trimmingCharacters(in: .whitespaces)
        item.normalize()
        item.set(pastYears: pastYears, remainingYears: remainingYears)
        itemsData = RemainingItemStore.upsert(item, in: itemsData)
        onSave(item)
    }
}

/// 이미 센 것을 고치는 시트
struct RemainingItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(RemainingItemStore.key) private var itemsData = Data()

    @State private var item: RemainingItem
    @State private var pastYears: Int
    @State private var remainingYears: Int
    private let isNew: Bool
    var onSave: (RemainingItem) -> Void
    var onDelete: () -> Void

    init(item: RemainingItem, isNew: Bool = false,
         onSave: @escaping (RemainingItem) -> Void = { _ in }, onDelete: @escaping () -> Void = {}) {
        _item = State(initialValue: item)
        let past = Int(item.elapsedYears().rounded())
        _pastYears = State(initialValue: past)
        _remainingYears = State(initialValue: max(0, Int(item.spanYears.rounded()) - past))
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var canSave: Bool { !item.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    CountSetupForm(item: $item, pastYears: $pastYears, remainingYears: $remainingYears,
                                   nameEditable: !item.isFreeTime)
                    if !isNew {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Label("삭제", systemImage: "trash")
                                .font(.system(.body, design: .serif))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .foregroundColor(.emberDeep)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.appBackgroundWarm.ignoresSafeArea())
            .navigationTitle(isNew ? String(localized: "세어 보기") : item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Label("취소", systemImage: "xmark") }
                        .foregroundColor(.inkMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Label("저장", systemImage: "checkmark") }
                        .foregroundColor(.ember)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        item.name = item.name.trimmingCharacters(in: .whitespaces)
        item.normalize()
        item.set(pastYears: pastYears, remainingYears: remainingYears)
        itemsData = RemainingItemStore.upsert(item, in: itemsData)
        onSave(item)
        dismiss()
    }
}

// MARK: - 목록

/// 남은 시간을 한눈에. 줄마다 지나간 몫(재)과 남은 몫(불씨)을 띠로 그린다.
struct RemainingListView: View {
    @Binding var selection: String
    @AppStorage(RemainingItemStore.key) private var itemsData = Data()
    @AppStorage(LifeSettings.birthdayKey) private var birthdayStamp: Double = 0
    @AppStorage(LifeSettings.expectancyKey) private var expectancy: Int = LifeSettings.defaultExpectancy

    @State private var editing: RemainingItem?

    private var items: [RemainingItem] { RemainingItemStore.decode(itemsData) }
    private var birthday: Date { Date(timeIntervalSince1970: birthdayStamp) }
    private var lifeEnd: Date { Calendar.current.date(byAdding: .year, value: expectancy, to: birthday) ?? Date() }

    var body: some View {
        ScrollView { rows }
            .scrollBounceBehavior(.basedOnSize)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .sheet(item: $editing) { item in
            RemainingItemEditor(item: item, onDelete: {
                itemsData = RemainingItemStore.remove(item.id, in: itemsData)
            })
        }
    }

    private var rows: some View {
        VStack(spacing: 8) {
            if let free = items.first(where: \.isFreeTime) {
                itemRow(free)
            } else {
                emptyRow(id: RemainingKind.freeTime, symbol: "hourglass", name: String(localized: "자유시간"))
            }
            ForEach(items.filter { !$0.isFreeTime }) { itemRow($0) }
            ForEach(LifeMoment.allCases) { m in
                if birthdayStamp == 0 {
                    emptyRow(id: m.rawValue, symbol: m.symbol, name: m.name)
                } else {
                    let counter = LifeCounter(birthday: birthday, lifeEnd: lifeEnd)
                    let today = Calendar.current.startOfDay(for: Date())
                    let past = counter.count(m, from: birthday, to: today)
                    let left = counter.count(m, from: today, to: lifeEnd)
                    row(id: m.rawValue, symbol: m.symbol, name: m.name,
                        value: String(localized: "\(left)번"), remainingShare: share(past: past, left: left))
                }
            }
            Button { selection = RemainingKind.new } label: {
                Label("세어 볼 것 만들기", systemImage: "plus")
                    .font(.system(.body, design: .serif).weight(.medium))
                    .foregroundColor(.ember)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.ember.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.bottom, 8)
    }

    private func itemRow(_ item: RemainingItem) -> some View {
        row(id: item.selectionID, symbol: item.symbol, name: item.name,
            value: item.unit.format(item.remaining), remainingShare: share(past: item.past, left: item.remaining))
            .contextMenu {
                Button { editing = item } label: { Label("고치기", systemImage: "pencil") }
                Button(role: .destructive) {
                    itemsData = RemainingItemStore.remove(item.id, in: itemsData)
                } label: { Label("삭제", systemImage: "trash") }
            }
            .accessibilityAction(named: Text("고치기")) { editing = item }
    }

    private func share(past: Int, left: Int) -> Double {
        past + left > 0 ? Double(left) / Double(past + left) : 0
    }

    /// 아직 세지 않은 것 — 누르면 세어 보기로
    private func emptyRow(id: String, symbol: String, name: String) -> some View {
        row(id: id, symbol: symbol, name: name, value: String(localized: "세어 보기"), remainingShare: nil)
    }

    private func row(id: String, symbol: String, name: String, value: String, remainingShare: Double?) -> some View {
        Button { selection = id } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: symbol)
                        .font(.body)
                        .foregroundColor(.ember.opacity(0.8))
                        .frame(width: 24)
                    Text(name)
                        .font(.system(.body, design: .serif))
                        .foregroundColor(.ink)
                        .lineLimit(1)
                    Spacer()
                    Text(value)
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .foregroundColor(remainingShare == nil ? .inkMuted.opacity(0.7) : .ember)
                        .monospacedDigit()
                }
                if let remainingShare {
                    GeometryReader { g in
                        HStack(spacing: 0) {
                            Rectangle().fill(LifeDotGrid.ashColor).frame(width: g.size.width * (1 - remainingShare))
                            Rectangle().fill(LifeDotGrid.emberColor)
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 5)
                    .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.ink.opacity(0.03)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
