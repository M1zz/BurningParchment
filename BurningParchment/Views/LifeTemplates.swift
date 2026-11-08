// LifeTemplates.swift
// 인생의 시간 — 머리로는 그려지지 않는 남은 시간을 곡선으로 보여 준다.
//
// 부모님과 함께하는 날은 해마다 고르게 오지 않는다. 처음 스무 해에 거의 다 쓰고, 그 뒤로는 한 해에 며칠뿐이다.
// 그래서 "앞으로 30년" 이라는 말이 실제로는 "앞으로 300일" 이다. 이 차이를 숫자 대신 곡선으로 보여 준다.
//
// 템플릿은 묻는 말 두세 개로 구간(`RemainingItem.Phase`)을 만들어 줄 뿐이다. 저장하면 보통의 세어 둔 것과
// 똑같아서, 구간 · 1년에 쓰는 양 · 남은 해를 사람마다 그대로 고칠 수 있다. 따로 저장하는 형식은 없다.

import SwiftUI
import Charts

// MARK: - 템플릿

struct LifeTemplate: Identifiable {
    struct Question: Identifiable {
        let id: String
        let title: String
        let range: ClosedRange<Int>
        let initial: Int
    }

    /// 묻는 말로 만든 결과 — 세어 보기의 세 질문(보낸 해 · 남은 해 · 패턴)과 같은 모양이다
    struct Shape {
        var phases: [RemainingItem.Phase]
        var pastYears: Int
        var remainingYears: Int
    }

    let id: String
    let name: String
    let symbol: String
    let unit: RemainingUnit
    /// 왜 곡선이 이런 모양인지 한 줄로
    let why: String
    let questions: [Question]
    let build: ([String: Int]) -> Shape
    /// 소중한 사람 묶음 안에서의 사이(부모님 · 아이 …). nil 이면 따로 서는 템플릿이다.
    var relation: String? = nil

    /// 사이를 고르면 곡선이 바뀌는 한 장의 템플릿 — 부모님 · 아이 · 친구 · 연인 · 그 외
    static let peopleName = String(localized: "소중한 사람과 함께하는 날")

    func item(_ values: [String: Int]) -> (RemainingItem, Shape) {
        let shape = build(values)
        var item = RemainingItem(name: name, symbol: symbol, unit: unit, phases: shape.phases,
                                 startDate: Date(), spanYears: 0)
        item.normalize()
        item.set(pastYears: shape.pastYears, remainingYears: shape.remainingYears)
        return (item, shape)
    }

    private static func phase(_ until: Int?, _ perYear: Double) -> RemainingItem.Phase {
        .init(untilYear: until, perYear: perYear)
    }

    /// 내 나이 · 기대 수명은 이미 적어 둔 값에서 시작한다
    static func all(myAge: Int, expectancy: Int) -> [LifeTemplate] {
        let myRemaining = { (v: [String: Int]) in max(0, expectancy - (v["me"] ?? myAge)) }
        let me = Question(id: "me", title: String(localized: "내 나이"), range: 0...110, initial: myAge)
        let their = Question(id: "their", title: String(localized: "그분 나이"), range: 0...110, initial: myAge)
        let together = Question(id: "together", title: String(localized: "함께한 해"), range: 0...100, initial: 5)
        /// 연인 · 그 외: 1년에 고르게 함께하고, 둘 중 먼저 닿는 쪽까지
        let steady = { (v: [String: Int], fallback: Int) in
            Shape(phases: [phase(nil, Double(v["perYear"] ?? fallback))],
                  pastYears: v["together"] ?? 5,
                  remainingYears: max(0, expectancy - max(v["me"] ?? myAge, v["their"] ?? myAge)))
        }
        return [
            LifeTemplate(
                id: "parents", name: String(localized: "부모님과 함께하는 날"), symbol: "person.2.fill", unit: .day,
                why: String(localized: "스무 살까지는 거의 매일, 그 뒤로는 1년에 며칠뿐이에요"),
                questions: [me,
                            Question(id: "parent", title: String(localized: "부모님 나이"), range: 30...110,
                                     initial: min(110, max(30, myAge + 30))),
                            Question(id: "perYear", title: String(localized: "요즘 1년에 함께하는 날"), range: 0...365, initial: 10)],
                build: { v in
                    Shape(phases: [phase(20, 330), phase(nil, Double(v["perYear"] ?? 10))],
                          pastYears: v["me"] ?? myAge,
                          remainingYears: max(0, expectancy - (v["parent"] ?? myAge + 30)))
                },
                relation: String(localized: "부모님")),
            LifeTemplate(
                id: "child", name: String(localized: "아이와 함께하는 날"), symbol: "figure.2.and.child.holdinghands", unit: .day,
                why: String(localized: "열두 살이 지나면 친구에게, 스무 살이 지나면 세상으로 가요"),
                questions: [Question(id: "child", title: String(localized: "아이 나이"), range: 0...60, initial: 5), me],
                build: { v in
                    Shape(phases: [phase(12, 330), phase(18, 200), phase(25, 60), phase(nil, 15)],
                          pastYears: v["child"] ?? 5, remainingYears: myRemaining(v))
                },
                relation: String(localized: "아이")),
            LifeTemplate(
                id: "friends", name: String(localized: "친구와 만나는 날"), symbol: "person.3.fill", unit: .day,
                why: String(localized: "학교에서는 매일 보던 친구를, 어른이 되면 1년에 몇 번 봐요"),
                questions: [me,
                            Question(id: "perYear", title: String(localized: "요즘 1년에 만나는 날"), range: 0...365, initial: 12)],
                build: { v in
                    Shape(phases: [phase(7, 30), phase(19, 200), phase(27, 80), phase(nil, Double(v["perYear"] ?? 12))],
                          pastYears: v["me"] ?? myAge, remainingYears: myRemaining(v))
                },
                relation: String(localized: "친구")),
            LifeTemplate(
                id: "partner", name: String(localized: "연인과 함께하는 날"), symbol: "heart.fill", unit: .day,
                why: String(localized: "매일이 쌓여 가장 긴 시간이 돼요"),
                questions: [me, their, together,
                            Question(id: "perYear", title: String(localized: "요즘 1년에 함께하는 날"), range: 0...365, initial: 300)],
                build: { steady($0, 300) },
                relation: String(localized: "연인")),
            LifeTemplate(
                id: "someone", name: peopleName, symbol: "person.fill", unit: .day,
                why: String(localized: "자주 못 봐도, 한 번 한 번이 쌓여요"),
                questions: [me, their, together,
                            Question(id: "perYear", title: String(localized: "요즘 1년에 함께하는 날"), range: 0...365, initial: 6)],
                build: { steady($0, 6) },
                relation: String(localized: "그 외")),
            LifeTemplate(
                id: "travel", name: String(localized: "몸이 허락하는 여행"), symbol: "airplane", unit: .times,
                why: String(localized: "예순다섯이 넘으면 먼 길이 줄고, 일흔다섯이 넘으면 거의 멈춰요"),
                questions: [me,
                            Question(id: "perYear", title: String(localized: "요즘 1년에 떠나는 여행"), range: 0...50, initial: 2)],
                build: { v in
                    let n = Double(v["perYear"] ?? 2)
                    return Shape(phases: [phase(20, 1), phase(65, n), phase(75, (n / 2).rounded(.up)), phase(nil, 0)],
                                 pastYears: v["me"] ?? myAge, remainingYears: myRemaining(v))
                }),
            LifeTemplate(
                id: "pet", name: String(localized: "반려동물과 함께하는 날"), symbol: "pawprint.fill", unit: .day,
                why: String(localized: "매일 함께지만, 우리보다 훨씬 빨리 지나가요"),
                questions: [Question(id: "pet", title: String(localized: "반려동물 나이"), range: 0...30, initial: 3),
                            Question(id: "life", title: String(localized: "반려동물 기대 수명"), range: 1...35, initial: 15)],
                build: { v in
                    let age = v["pet"] ?? 3
                    return Shape(phases: [phase(nil, 365)], pastYears: age, remainingYears: max(0, (v["life"] ?? 15) - age))
                }),
        ]
    }
}

// MARK: - 곡선

/// 해마다 쓰는 양을 막대로. 지나간 해는 재, 남은 해는 불씨. 앞쪽에 몰린 모양이 그대로 보인다.
struct CountCurveChart: View {
    let item: RemainingItem

    private struct Bar: Identifiable {
        let id: Int
        let amount: Double
        let past: Bool
        var start: Double { Double(id) + 0.1 }
        var end: Double { Double(id) + 0.9 }
        var color: Color { past ? LifeDotGrid.ashColor : Color.ember.opacity(0.75) }
    }

    private var span: Int { max(1, Int(item.spanYears.rounded(.up))) }

    private var bars: [Bar] {
        let pastYears = item.elapsedYears().rounded(.down)
        return (0..<span).map { y in
            Bar(id: y, amount: item.amount(from: Double(y), to: Double(y + 1)), past: Double(y) < pastYears)
        }
    }

    var body: some View {
        let now = item.elapsedYears()
        Chart {
            ForEach(bars) { bar in
                RectangleMark(xStart: .value(Text(verbatim: "from"), bar.start),
                              xEnd: .value(Text(verbatim: "to"), bar.end),
                              yStart: .value(Text(verbatim: "zero"), 0.0),
                              yEnd: .value(Text(verbatim: "amount"), bar.amount))
                    .foregroundStyle(bar.color)
            }
            RuleMark(x: .value(Text(verbatim: "now"), now))
                .foregroundStyle(Color.ember)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .annotation(position: .top, alignment: .center) {
                    Text("지금")
                        .font(.system(.caption, design: .serif).weight(.semibold))
                        .foregroundColor(.ember)
                }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(domain: 0...span)
        .accessibilityHidden(true)
    }
}

// MARK: - 고르기 · 묻기

/// 새로 세어 볼 때의 첫 화면 — 인생의 시간 템플릿, 아니면 직접 만들기
struct LifeTemplatePage: View {
    /// 템플릿을 고르지 않고 빈 세어 보기로
    var onBlank: () -> Void
    var onSave: (RemainingItem) -> Void

    @AppStorage(LifeSettings.birthdayKey) private var birthdayStamp: Double = 0
    @AppStorage(LifeSettings.expectancyKey) private var expectancy: Int = LifeSettings.defaultExpectancy
    @State var chosen: String? = nil
    /// 소중한 사람의 이름 — 사이를 바꿔도 남는다
    @State private var personName = ""

    private var templates: [LifeTemplate] {
        LifeTemplate.all(myAge: LifeSettings.age(birthdayStamp: birthdayStamp), expectancy: expectancy)
    }

    var body: some View {
        if let id = chosen, let t = templates.first(where: { $0.id == id }) {
            let people = t.relation == nil ? [] : templates.filter { $0.relation != nil }
            LifeTemplateForm(template: t, people: people, personName: $personName,
                             onPick: { chosen = $0 }, onBack: { chosen = nil }, onSave: onSave)
                .id(t.id)
        } else {
            gallery
        }
    }

    private var gallery: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("인생의 시간")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundColor(.ember.opacity(0.9))
                Text("남은 해와 남은 날은 같지 않아요. 무엇을 세어 볼까요?")
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.inkMuted.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
                // 사람과의 시간은 한 장으로 — 고른 사이에 따라 곡선이 바뀐다
                tile(symbol: "heart.fill", name: LifeTemplate.peopleName,
                     detail: String(localized: "부모님, 아이, 친구, 연인. 누구와 함께인지에 따라 곡선이 달라요")) {
                    chosen = "parents"
                }
                ForEach(templates.filter { $0.relation == nil }) { t in
                    tile(symbol: t.symbol, name: t.name, detail: t.why) { chosen = t.id }
                }
                tile(symbol: "plus", name: String(localized: "직접 만들기"),
                     detail: String(localized: "구간과 1년에 쓰는 양을 처음부터 정해요"), action: onBlank)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    private func tile(symbol: String, name: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.body)
                    .foregroundColor(.ember.opacity(0.85))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                    Text(detail)
                        .font(.system(.body, design: .serif))
                        .foregroundColor(.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.ink.opacity(0.03)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// 템플릿의 물음 두세 개. 답할 때마다 곡선이 바로 바뀐다. 더 고치고 싶으면 저장한 뒤 고치기에서 구간을 손본다.
private struct LifeTemplateForm: View {
    let template: LifeTemplate
    /// 소중한 사람 묶음의 사이들. 비어 있으면 따로 서는 템플릿이다.
    let people: [LifeTemplate]
    @Binding var personName: String
    var onPick: (String) -> Void
    var onBack: () -> Void
    var onSave: (RemainingItem) -> Void

    @EnvironmentObject var storeManager: StoreManager
    @AppStorage(RemainingItemStore.key) private var itemsData = Data()
    @State private var values: [String: Int]
    @State private var showPaywall = false

    init(template: LifeTemplate, people: [LifeTemplate], personName: Binding<String>,
         onPick: @escaping (String) -> Void, onBack: @escaping () -> Void, onSave: @escaping (RemainingItem) -> Void) {
        self.template = template
        self.people = people
        _personName = personName
        self.onPick = onPick
        self.onBack = onBack
        self.onSave = onSave
        _values = State(initialValue: Dictionary(uniqueKeysWithValues: template.questions.map { ($0.id, $0.initial) }))
    }

    var body: some View {
        let (item, shape) = template.item(values)
        let past = item.past, remaining = item.remaining
        let spent = past + remaining > 0 ? Int((Double(past) / Double(past + remaining) * 100).rounded()) : 100
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Button(action: onBack) {
                    Label("인생의 시간", systemImage: "chevron.left")
                        .font(.system(.body, design: .serif))
                        .foregroundColor(.ember)
                }
                .buttonStyle(.plain)

                if people.isEmpty {
                    Label(template.name, systemImage: template.symbol)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                } else {
                    personHeader
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("남은 \(template.unit.format(remaining))")
                        .font(.system(.largeTitle, design: .serif).weight(.bold))
                        .foregroundColor(.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    // 사람과의 시간은 겁주는 비율 대신, 떠올릴 수 있는 장면(함께 맞을 생일)으로
                    Group {
                        if people.isEmpty {
                            Text("벌써 \(spent)%를 보냈어요")
                        } else {
                            Text("앞으로 함께 맞을 생일 \(shape.remainingYears)번")
                        }
                    }
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.inkMuted.opacity(0.85))
                    CountCurveChart(item: item)
                        .frame(height: 120)
                        .padding(.top, 8)
                    Text(template.why)
                        .font(.system(.body, design: .serif))
                        .foregroundColor(.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)

                ForEach(template.questions) { q in
                    Stepper(value: binding(q), in: q.range) {
                        HStack {
                            Text(q.title)
                                .font(.system(.body, design: .serif))
                                .foregroundColor(.ink)
                            Spacer()
                            Text(values[q.id] ?? q.initial, format: .number)
                                .font(.system(.title3, design: .serif).weight(.semibold))
                                .foregroundColor(.ember)
                                .monospacedDigit()
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.ink.opacity(0.03)))
                }

                Text("사람마다 달라요. 저장한 뒤 고치기에서 구간과 1년에 쓰는 양을 내 삶에 맞게 바꿀 수 있어요.")
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Button { save(item) } label: {
                    Text("세어 보기")
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .foregroundColor(.onEmber)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.ember))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .count).environmentObject(storeManager)
        }
    }

    /// 이름 한 칸과 사이 고르기
    private var personHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LifeTemplate.peopleName)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundColor(.ink)
            TextField(String(localized: "이름 (예: 엄마, 지우)"), text: $personName)
                .font(.system(.body, design: .serif))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.ink.opacity(0.03)))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(people) { p in
                        let on = p.id == template.id
                        Button { onPick(p.id) } label: {
                            Text(p.relation ?? p.name)
                                .font(.system(.subheadline, design: .serif).weight(on ? .semibold : .regular))
                                .foregroundColor(on ? .onEmber : .ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(on ? Color.ember : Color.ink.opacity(0.05)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
        }
    }

    private func binding(_ q: LifeTemplate.Question) -> Binding<Int> {
        Binding(get: { values[q.id] ?? q.initial }, set: { values[q.id] = $0 })
    }

    private func save(_ item: RemainingItem) {
        var item = item
        let name = personName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !people.isEmpty, !name.isEmpty { item.name = name }
        // 한도에 닿았으면 페이월 — 무료 1개, Plus 3개, Pro 무제한 (창단 후원자는 무제한)
        if let count = RemainingItemStore.countBeforeAdding(item, in: itemsData),
           !storeManager.canAddCount(currentCount: count) {
            showPaywall = true
            return
        }
        itemsData = RemainingItemStore.upsert(item, in: itemsData)
        onSave(item)
    }
}
