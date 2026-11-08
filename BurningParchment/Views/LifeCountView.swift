// LifeCountView.swift
// 가운데 페이지 "남은 시간" — 이번 주 자유시간도, 남은 크리스마스도 같은 "남은 시간" 의 한 종류다.
//
// 자유시간을 고르면 지금처럼 양피지가 탄다. 크리스마스 · 생일 · 주말 같은 것을 고르면
// 태어난 날과 기대 수명으로 앞으로 몇 번 남았는지 세어, 지나간 것은 재로, 남은 것은 불씨로,
// 바로 다음 하나는 밝게 그린다. 기대 수명은 짐작일 뿐이라 숫자를 단정하지 않고 "다음 한 번" 으로 시선을 돌린다.

import SwiftUI

// MARK: - 셀 거리

enum LifeMoment: String, CaseIterable, Identifiable {
    case christmas, birthday, newYear, spring, weekend, fullMoon

    var id: String { rawValue }

    var name: String {
        switch self {
        case .christmas: return String(localized: "크리스마스")
        case .birthday:  return String(localized: "생일")
        case .newYear:   return String(localized: "새해 첫날")
        case .spring:    return String(localized: "봄")
        case .weekend:   return String(localized: "주말")
        case .fullMoon:  return String(localized: "보름달")
        }
    }

    var remainingTitle: String {
        switch self {
        case .christmas: return String(localized: "남은 크리스마스")
        case .birthday:  return String(localized: "남은 생일")
        case .newYear:   return String(localized: "남은 새해 첫날")
        case .spring:    return String(localized: "남은 봄")
        case .weekend:   return String(localized: "남은 주말")
        case .fullMoon:  return String(localized: "남은 보름달")
        }
    }

    var symbol: String {
        switch self {
        case .christmas: return "gift.fill"
        case .birthday:  return "birthday.cake.fill"
        case .newYear:   return "sunrise.fill"
        case .spring:    return "leaf.fill"
        case .weekend:   return "cup.and.saucer.fill"
        case .fullMoon:  return "moon.fill"
        }
    }

    /// 한 줄에 놓을 점 수 — 해마다 한 번이면 한 줄이 십 년, 주말이면 한 줄이 한 해
    var columns: Int {
        switch self {
        case .weekend:  return 52
        case .fullMoon: return 25
        default:        return 10
        }
    }
}

/// [start, end) 사이에 그 일이 몇 번 오는지, 그리고 다음 한 번은 언제인지
struct LifeCounter {
    let birthday: Date
    let lifeEnd: Date
    var calendar = Calendar.current

    /// 2000-01-21 04:41 UTC 보름달, 삭망월 29.530588853일
    private static let fullMoonReference = Date(timeIntervalSince1970: 948_429_660)
    private static let synodicMonth: TimeInterval = 29.530588853 * 86_400

    func count(_ moment: LifeMoment, from start: Date, to end: Date) -> Int {
        guard end > start else { return 0 }
        switch moment {
        case .weekend:
            // 토요일 수
            guard let first = calendar.nextDate(after: calendar.startOfDay(for: start).addingTimeInterval(-1),
                                                matching: DateComponents(weekday: 7),
                                                matchingPolicy: .nextTime),
                  first < end else { return 0 }
            let days = calendar.dateComponents([.day], from: first, to: end).day ?? 0
            return days / 7 + 1
        case .fullMoon:
            let p = Self.synodicMonth
            let a = (start.timeIntervalSince(Self.fullMoonReference) / p).rounded(.up)
            let b = (end.timeIntervalSince(Self.fullMoonReference) / p).rounded(.up)
            return max(0, Int(b - a))
        default:
            let y0 = calendar.component(.year, from: start)
            let y1 = calendar.component(.year, from: end)
            guard y0 <= y1 else { return 0 }
            let birthYear = calendar.component(.year, from: birthday)
            return (y0...y1).reduce(0) { n, year in
                // 태어난 그날은 생일로 치지 않는다
                guard let d = annualDate(moment, year: year), !(moment == .birthday && year == birthYear) else { return n }
                return d >= start && d < end ? n + 1 : n
            }
        }
    }

    func next(_ moment: LifeMoment, after now: Date) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch moment {
        case .weekend:
            if calendar.component(.weekday, from: today) == 7 { return today }
            return calendar.nextDate(after: today, matching: DateComponents(weekday: 7), matchingPolicy: .nextTime)
        case .fullMoon:
            let p = Self.synodicMonth
            let k = (today.timeIntervalSince(Self.fullMoonReference) / p).rounded(.up)
            return Self.fullMoonReference.addingTimeInterval(k * p)
        default:
            let year = calendar.component(.year, from: today)
            for y in year...(year + 1) {
                if let d = annualDate(moment, year: y), d >= today { return d }
            }
            return nil
        }
    }

    /// 해마다 오는 날. 2월 29일 생일은 평년에 3월 1일로 친다.
    private func annualDate(_ moment: LifeMoment, year: Int) -> Date? {
        let md: (Int, Int)
        switch moment {
        case .christmas: md = (12, 25)
        case .newYear:   md = (1, 1)
        case .spring:    md = (3, 1)
        case .birthday:
            let c = calendar.dateComponents([.month, .day], from: birthday)
            md = (c.month ?? 1, c.day ?? 1)
        case .weekend, .fullMoon: return nil
        }
        return calendar.date(from: DateComponents(year: year, month: md.0, day: md.1))
    }
}

// MARK: - 고르기

/// 남은 시간 페이지에서 무엇을 볼지. 자유시간 · 목록 · 새로 만들기가 아니면 `LifeMoment` 의 rawValue 거나 `custom:<id>` 다.
enum RemainingKind {
    static let storageKey = "remainingKind"
    static let freeTime = "freeTime"
    static let list = "list"
    /// 새로 세어 보기 (페이지 안에서 바로)
    static let new = "new"
}

struct RemainingKindPicker: View {
    @Binding var selection: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(RemainingItemStore.key) private var itemsData = Data()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(id: RemainingKind.list, name: String(localized: "목록"), symbol: "list.bullet")
                    chip(id: RemainingKind.freeTime, name: String(localized: "자유시간"), symbol: "hourglass")
                    ForEach(RemainingItemStore.decode(itemsData).filter { !$0.isFreeTime }) { item in
                        chip(id: item.selectionID, name: item.name, symbol: item.symbol)
                    }
                    ForEach(LifeMoment.allCases) { m in
                        chip(id: m.rawValue, name: m.name, symbol: m.symbol)
                    }
                    chip(id: RemainingKind.new, name: String(localized: "세어 보기"), symbol: "plus")
                }
                .padding(.horizontal, 20)
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
            .onChange(of: selection) { _, id in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    private func chip(id: String, name: String, symbol: String) -> some View {
        let selected = id == selection
        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { selection = id }
        } label: {
            Label(name, systemImage: symbol)
                .font(.system(.body, design: .serif))
                .foregroundColor(selected ? .onEmber : .ink.opacity(0.8))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(selected ? Color.ember : Color.ink.opacity(0.05)))
        }
        .buttonStyle(.plain)
        .id(id)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - 보낸 해 · 남은 해 (크리스마스 · 생일 같은 해마다 오는 날에 쓴다)

enum LifeSettings {
    /// 0 이면 아직 세어 보지 않았다. 보낸 해만큼 거슬러 올라간 날을 태어난 날로 둔다.
    static let birthdayKey = "lifeBirthday"
    static let expectancyKey = "lifeExpectancy"
    static let defaultExpectancy = 83
    static let defaultAge = 30
    static let defaultBirthday: Date =
        Calendar.current.date(byAdding: .year, value: -defaultAge, to: Date()) ?? Date()

    static func age(birthdayStamp: Double) -> Int {
        guard birthdayStamp != 0 else { return defaultAge }
        return Calendar.current.dateComponents([.year], from: Date(timeIntervalSince1970: birthdayStamp), to: Date()).year ?? defaultAge
    }

    static func birthdayStamp(forAge age: Int) -> Double {
        (Calendar.current.date(byAdding: .year, value: -age, to: Date()) ?? Date()).timeIntervalSince1970
    }
}

/// 얼마나 보냈나요(나이) · 앞으로 얼마나 남았나요. 값은 부르는 쪽이 저장한다.
struct LifeInputForm: View {
    @Binding var pastYears: Int
    @Binding var remainingYears: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            row(String(localized: "얼마나 보냈나요"), hint: String(localized: "지금 내 나이"), value: $pastYears)
            row(String(localized: "앞으로 얼마나 남았나요"), hint: String(localized: "기대 수명까지 남은 해. 짐작이면 충분해요"), value: $remainingYears)
        }
    }

    private func row(_ title: String, hint: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.body, design: .serif).weight(.semibold))
                .foregroundColor(.ink)
            Stepper(value: value, in: 0...120) {
                Text("\(value.wrappedValue)년")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundColor(.ember)
                    .monospacedDigit()
            }
            Text(hint)
                .font(.system(.body, design: .serif))
                .foregroundColor(.inkMuted.opacity(0.7))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.ink.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.ember.opacity(0.12), lineWidth: 1))
        )
    }
}

struct LifeInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(LifeSettings.birthdayKey) private var birthdayStamp: Double = 0
    @AppStorage(LifeSettings.expectancyKey) private var expectancy: Int = LifeSettings.defaultExpectancy
    @State private var pastYears = LifeSettings.defaultAge
    @State private var remainingYears = LifeSettings.defaultExpectancy - LifeSettings.defaultAge

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LifeInputForm(pastYears: $pastYears, remainingYears: $remainingYears)
                    Text("기대 수명은 짐작일 뿐이에요. 숫자보다 다음 한 번을 어떻게 보낼지 생각해 보세요.")
                        .font(.system(.body, design: .serif))
                        .foregroundColor(.inkMuted.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(Color.appBackgroundWarm.ignoresSafeArea())
            .navigationTitle("세어 보기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Label("취소", systemImage: "xmark") }
                        .foregroundColor(.inkMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        birthdayStamp = LifeSettings.birthdayStamp(forAge: pastYears)
                        expectancy = pastYears + remainingYears
                        dismiss()
                    } label: { Label("저장", systemImage: "checkmark") }
                        .foregroundColor(.ember)
                }
            }
            .onAppear {
                pastYears = LifeSettings.age(birthdayStamp: birthdayStamp)
                remainingYears = max(0, expectancy - pastYears)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 페이지

/// 남은 시간 페이지. 무엇을 골라도 세어 보기(보낸 만큼 · 남은 만큼 · 패턴)로 시작해 그림으로 끝난다.
struct RemainingPage: View {
    @Binding var selection: String
    @EnvironmentObject var freeTimeManager: FreeTimeManager
    @AppStorage(LifeSettings.birthdayKey) private var birthdayStamp: Double = 0
    @AppStorage(LifeSettings.expectancyKey) private var expectancy: Int = LifeSettings.defaultExpectancy
    @AppStorage(RemainingItemStore.key) private var itemsData = Data()
    @State private var newDraft = 0
    /// 새로 세어 볼 때 템플릿 대신 빈 세어 보기를 골랐는지
    @State private var blankDraft = false

    private var items: [RemainingItem] { RemainingItemStore.decode(itemsData) }
    private var age: Int { LifeSettings.age(birthdayStamp: birthdayStamp) }
    private var remainingLife: Int { max(0, expectancy - age) }

    var body: some View {
        Group {
            if selection == RemainingKind.list {
                RemainingListView(selection: $selection)
            } else if selection == RemainingKind.new {
                Group {
                    if blankDraft {
                        CountSetupPage(item: .template(pastYears: age, remainingYears: remainingLife), nameEditable: true) {
                            selection = $0.selectionID
                        }
                    } else {
                        LifeTemplatePage(onBlank: { blankDraft = true }, onSave: { selection = $0.selectionID })
                    }
                }
                .id(newDraft)
            } else if selection == RemainingKind.freeTime {
                if let item = items.first(where: \.isFreeTime) {
                    CustomCountPage(item: item, selection: $selection)
                } else {
                    CountSetupPage(item: .freeTimeTemplate(pastYears: age, remainingYears: remainingLife,
                                                           weeklyMinutes: freeTimeManager.weeklyMinutes),
                                   nameEditable: false)
                }
            } else if let moment = LifeMoment(rawValue: selection) {
                if birthdayStamp == 0 {
                    LifeFirstInput(title: moment.remainingTitle)
                } else {
                    LifeCountPage(moment: moment)
                }
            } else if let item = items.first(where: { $0.selectionID == selection }) {
                CustomCountPage(item: item, selection: $selection)
            } else {
                // 지워진 것을 가리키고 있으면 목록으로
                RemainingListView(selection: $selection)
                    .onAppear { selection = RemainingKind.list }
            }
        }
        .onChange(of: selection) { _, s in if s == RemainingKind.new { newDraft += 1; blankDraft = false } }
    }
}

/// 해마다 오는 날을 처음 볼 때 — 보낸 해와 남은 해만 묻는다. 패턴은 이미 정해져 있다 (해마다 한 번 · 주마다 한 번).
private struct LifeFirstInput: View {
    let title: String
    @AppStorage(LifeSettings.birthdayKey) private var birthdayStamp: Double = 0
    @AppStorage(LifeSettings.expectancyKey) private var expectancy: Int = LifeSettings.defaultExpectancy
    @State private var pastYears = LifeSettings.defaultAge
    @State private var remainingYears = LifeSettings.defaultExpectancy - LifeSettings.defaultAge

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("세어 보기")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundColor(.ember.opacity(0.9))
                Text(title)
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.inkMuted.opacity(0.8))
                LifeInputForm(pastYears: $pastYears, remainingYears: $remainingYears)
                Button {
                    birthdayStamp = LifeSettings.birthdayStamp(forAge: pastYears)
                    expectancy = pastYears + remainingYears
                } label: {
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
    }
}

/// 해마다 오는 날 — 크리스마스 · 생일 · 주말 · 보름달
struct LifeCountPage: View {
    let moment: LifeMoment
    @AppStorage(LifeSettings.birthdayKey) private var birthdayStamp: Double = 0
    @AppStorage(LifeSettings.expectancyKey) private var expectancy: Int = LifeSettings.defaultExpectancy

    private var cal: Calendar { Calendar.current }
    private var now: Date { Date() }
    private var birthday: Date { Date(timeIntervalSince1970: birthdayStamp) }
    private var lifeEnd: Date { cal.date(byAdding: .year, value: expectancy, to: birthday) ?? now }
    private var counter: LifeCounter { LifeCounter(birthday: birthday, lifeEnd: lifeEnd) }

    var body: some View {
        let today = cal.startOfDay(for: now)
        let past = counter.count(moment, from: birthday, to: today)
        let remaining = counter.count(moment, from: today, to: lifeEnd)
        let overLife = remaining == 0 && now >= lifeEnd
        CountDetailView(
            title: moment.remainingTitle,
            remainingText: "\(remaining)",
            detail: overLife ? String(localized: "기대 수명을 넘었어요. 이제부터는 모두 덤이에요")
                             : String(localized: "지나온 \(past)번 · \(nextText)"),
            burned: String(localized: "삶의 \(burnedPercent)%가 탔어요"),
            past: past, remaining: remaining, columns: moment.columns,
            onEditItem: nil
        )
    }

    private var burnedPercent: Int {
        let total = lifeEnd.timeIntervalSince(birthday)
        guard total > 0 else { return 100 }
        return min(100, max(0, Int((now.timeIntervalSince(birthday) / total * 100).rounded())))
    }

    private var nextText: String {
        guard let next = counter.next(moment, after: now) else { return "" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: next)).day ?? 0
        return days <= 0 ? String(localized: "오늘이에요") : String(localized: "다음은 \(days)일 뒤")
    }
}

/// 세어 둔 것 — 자유시간이나 직접 만든 것. 구간마다 1년에 쓰는 양이 다르다.
struct CustomCountPage: View {
    let item: RemainingItem
    @Binding var selection: String
    @AppStorage(RemainingItemStore.key) private var itemsData = Data()
    @State private var editing = false

    var body: some View {
        let past = item.past
        let remaining = item.remaining
        let spent = past + remaining > 0 ? Int((Double(past) / Double(past + remaining) * 100).rounded()) : 100
        let elapsed = Int(item.elapsedYears().rounded())
        CountDetailView(
            title: item.name,
            remainingText: item.unit.format(remaining),
            detail: String(localized: "지나온 \(item.unit.format(past))"),
            burned: String(localized: "벌써 \(spent)%를 보냈어요"),
            past: past, remaining: remaining, columns: nil,
            curve: item.phases.count > 1 ? item : nil,
            footerLink: String(localized: "\(elapsed)년 보냄 · \(max(0, Int(item.spanYears.rounded()) - elapsed))년 남음"),
            onFooterLink: { editing = true },
            onEditItem: { editing = true }
        )
        .sheet(isPresented: $editing) {
            RemainingItemEditor(item: item, onDelete: {
                itemsData = RemainingItemStore.remove(item.id, in: itemsData)
                selection = RemainingKind.list
            })
        }
    }
}

/// 남은 양 · 지나온 양 · 점 격자 · 나이 고치기
struct CountDetailView: View {
    let title: String
    let remainingText: String
    let detail: String
    let burned: String
    let past: Int
    let remaining: Int
    /// nil 이면 자리에 맞춰 정한다
    let columns: Int?
    /// 구간마다 1년에 쓰는 양이 다르면 그 곡선을 점 격자 위에 그린다
    var curve: RemainingItem? = nil
    /// 아래 오른쪽 밑줄 글자. nil 이면 "만 N세 · 기대 수명 M세" 로 나이를 고친다.
    var footerLink: String? = nil
    var onFooterLink: (() -> Void)? = nil
    let onEditItem: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.parchmentAnimationPaused) private var animationPaused
    @AppStorage(LifeSettings.birthdayKey) private var birthdayStamp: Double = 0
    @AppStorage(LifeSettings.expectancyKey) private var expectancy: Int = LifeSettings.defaultExpectancy
    @State private var glow = false
    @State private var showInput = false

    private var age: Int { LifeSettings.age(birthdayStamp: birthdayStamp) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            summary
            if let curve {
                CountCurveChart(item: curve)
                    .frame(height: 96)
                    .padding(.top, 12)
            }
            LifeDotGrid(past: past, remaining: remaining, columns: columns, glow: glow)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
            footer
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .onAppear(perform: startGlow)
        .onChange(of: animationPaused) { _, _ in startGlow() }
        .sheet(isPresented: $showInput) { LifeInputSheet() }
    }

    private func startGlow() {
        guard !reduceMotion, !animationPaused else { glow = false; return }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glow = true }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundColor(.ember.opacity(0.9))
                if let onEditItem {
                    Spacer()
                    Button(action: onEditItem) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.body)
                            .foregroundColor(.ember)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.ember.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "고치기"))
                }
            }
            Text(remainingText)
                .font(.system(.largeTitle, design: .serif).weight(.bold))
                .foregroundColor(.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(detail)
                .font(.system(.body, design: .serif))
                .foregroundColor(.inkMuted.opacity(0.8))
        }
        .accessibilityElement(children: .contain)
    }

    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                burnedText
                Spacer()
                ageButton
            }
            VStack(alignment: .leading, spacing: 4) {
                burnedText
                ageButton
            }
        }
        .padding(.bottom, 8)
    }

    private var burnedText: some View {
        Text(burned)
            .font(.system(.body, design: .serif))
            .foregroundColor(.inkMuted.opacity(0.8))
    }

    private var ageButton: some View {
        Button { if let onFooterLink { onFooterLink() } else { showInput = true } } label: {
            Text(footerLink ?? String(localized: "만 \(age)세 · 기대 수명 \(expectancy)세"))
                .font(.system(.body, design: .serif))
                .foregroundColor(.ember.opacity(0.85))
                .underline()
        }
        .buttonStyle(.plain)
        .accessibilityHint(String(localized: "보낸 해와 남은 해 고치기"))
    }
}

// MARK: - 점 격자

/// 지나간 것은 재, 바로 다음은 밝은 불씨, 그 뒤는 옅은 불씨. 수천 개라도 한 번에 그리도록 캔버스로.
/// 주어진 자리 안에 다 들어가게 점 크기를 정한다 — 페이지를 넘기는 가로 쓸기와 겹치지 않게 스크롤하지 않는다.
/// 점이 너무 많으면(시간 단위 등) 점 하나에 여럿을 담는다.
struct LifeDotGrid: View {
    let past: Int
    let remaining: Int
    /// nil 이면 자리 비율에 맞춰 정한다
    let columns: Int?
    var glow: Bool

    static let ashColor = Color.inkMuted.opacity(0.28)
    static let emberColor = Color.ember.opacity(0.55)
    private static let maxDots = 12_000

    var body: some View {
        GeometryReader { geo in
            let rawTotal = past + remaining
            let per = max(1, Int((Double(rawTotal) / Double(Self.maxDots)).rounded(.up)))
            let pastDots = past / per
            let total = pastDots + Int((Double(remaining) / Double(per)).rounded(.up))
            let w = max(geo.size.width, 1), h = max(geo.size.height, 1)
            let cols = columns ?? max(1, Int((Double(total) * Double(w / h)).squareRoot().rounded(.up)))
            let rows = max(1, Int((Double(total) / Double(cols)).rounded(.up)))
            let cell = min(w / CGFloat(cols), h / CGFloat(rows), 40)
            let dot = cell * 0.72
            let inset = (cell - dot) / 2
            let ox = (w - cell * CGFloat(cols)) / 2
            Canvas { ctx, _ in
                for i in 0..<total {
                    let rect = CGRect(x: ox + CGFloat(i % cols) * cell + inset,
                                      y: CGFloat(i / cols) * cell + inset,
                                      width: dot, height: dot)
                    let color = i < pastDots ? Self.ashColor : (i == pastDots ? Color.ember : Self.emberColor)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
            if remaining > 0 {
                // 바로 다음 하나는 숨 쉬듯 빛난다
                Circle()
                    .fill(Color.ember.opacity(glow ? 0.35 : 0.1))
                    .frame(width: max(cell * 1.4, 10), height: max(cell * 1.4, 10))
                    .position(x: ox + (CGFloat(pastDots % cols) + 0.5) * cell,
                              y: (CGFloat(pastDots / cols) + 0.5) * cell)
                    .allowsHitTesting(false)
            }
        }
    }
}
