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

/// 남은 시간 페이지에서 무엇을 볼지. 자유시간이 아니면 `LifeMoment` 의 rawValue 다.
enum RemainingKind {
    static let storageKey = "remainingKind"
    static let freeTime = "freeTime"
}

struct RemainingKindPicker: View {
    @Binding var selection: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(id: RemainingKind.freeTime, name: String(localized: "자유시간"), symbol: "hourglass")
                    ForEach(LifeMoment.allCases) { m in
                        chip(id: m.rawValue, name: m.name, symbol: m.symbol)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
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
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(selected ? Color.ember : Color.ink.opacity(0.05)))
        }
        .buttonStyle(.plain)
        .id(id)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - 태어난 날 · 기대 수명

enum LifeSettings {
    /// 0 이면 아직 적지 않았다
    static let birthdayKey = "lifeBirthday"
    static let expectancyKey = "lifeExpectancy"
    static let defaultExpectancy = 83
    static let defaultBirthday: Date =
        Calendar.current.date(from: DateComponents(year: 1990, month: 1, day: 1)) ?? Date()
}

struct LifeInputForm: View {
    @AppStorage(LifeSettings.birthdayKey) private var birthdayStamp: Double = 0
    @AppStorage(LifeSettings.expectancyKey) private var expectancy: Int = LifeSettings.defaultExpectancy

    private var birthday: Binding<Date> {
        Binding(
            get: { birthdayStamp == 0 ? LifeSettings.defaultBirthday : Date(timeIntervalSince1970: birthdayStamp) },
            set: { birthdayStamp = $0.timeIntervalSince1970 }
        )
    }

    private var age: Int {
        Calendar.current.dateComponents([.year], from: birthday.wrappedValue, to: Date()).year ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            DatePicker(selection: birthday, in: ...Date(), displayedComponents: .date) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("태어난 날")
                        .font(.system(.body, design: .serif))
                        .foregroundColor(.ink)
                    Text("만 \(age)세")
                        .font(.system(.body, design: .serif))
                        .foregroundColor(.inkMuted.opacity(0.7))
                }
            }
            .tint(.ember)
            .padding(.vertical, 10)

            Divider().background(Color.ember.opacity(0.12))

            Stepper(value: $expectancy, in: 40...120) {
                HStack {
                    Text("기대 수명")
                        .font(.system(.body, design: .serif))
                        .foregroundColor(.ink)
                    Spacer()
                    Text("\(expectancy)세")
                        .font(.system(.body, design: .serif).weight(.medium))
                        .foregroundColor(.ember)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 10)
        }
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.ink.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.ember.opacity(0.12), lineWidth: 1))
        )
    }
}

private struct LifeInputSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LifeInputForm()
                    Text("기대 수명은 짐작일 뿐이에요. 숫자보다 다음 한 번을 어떻게 보낼지 생각해 보세요.")
                        .font(.system(.body, design: .serif))
                        .foregroundColor(.inkMuted.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(Color.appBackgroundWarm.ignoresSafeArea())
            .navigationTitle("태어난 날 · 기대 수명")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Label("완료", systemImage: "checkmark") }
                        .foregroundColor(.ember)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 페이지

/// 남은 시간 페이지에서 자유시간이 아닌 것을 골랐을 때 양피지 자리에 서는 화면
struct LifeCountPage: View {
    let moment: LifeMoment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.parchmentAnimationPaused) private var animationPaused
    @AppStorage(LifeSettings.birthdayKey) private var birthdayStamp: Double = 0
    @AppStorage(LifeSettings.expectancyKey) private var expectancy: Int = LifeSettings.defaultExpectancy

    @State private var glow = false
    @State private var showInput = false

    private var cal: Calendar { Calendar.current }
    private var now: Date { Date() }
    private var isSet: Bool { birthdayStamp != 0 }

    private var birthday: Date {
        birthdayStamp == 0 ? LifeSettings.defaultBirthday : Date(timeIntervalSince1970: birthdayStamp)
    }
    private var lifeEnd: Date { cal.date(byAdding: .year, value: expectancy, to: birthday) ?? now }
    private var counter: LifeCounter { LifeCounter(birthday: birthday, lifeEnd: lifeEnd) }
    private var past: Int { counter.count(moment, from: birthday, to: cal.startOfDay(for: now)) }
    private var remaining: Int { counter.count(moment, from: cal.startOfDay(for: now), to: lifeEnd) }
    private var age: Int { cal.dateComponents([.year], from: birthday, to: now).year ?? 0 }

    private var burnedPercent: Int {
        let total = lifeEnd.timeIntervalSince(birthday)
        guard total > 0 else { return 100 }
        return min(100, max(0, Int((now.timeIntervalSince(birthday) / total * 100).rounded())))
    }

    var body: some View {
        Group {
            if isSet {
                counted
            } else {
                firstInput
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .sheet(isPresented: $showInput) { LifeInputSheet() }
    }

    /// 처음에는 무엇을 적으면 무엇이 보이는지부터
    private var firstInput: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(moment.remainingTitle)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundColor(.ember.opacity(0.9))
                Text("태어난 날과 기대 수명을 적으면 앞으로 몇 번 남았는지 세어 볼 수 있어요")
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.inkMuted.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                LifeInputForm()
                Button {
                    // 기본값 그대로여도 이대로 세겠다는 뜻이니 적어 둔다
                    if birthdayStamp == 0 { birthdayStamp = LifeSettings.defaultBirthday.timeIntervalSince1970 }
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
        }
    }

    private var counted: some View {
        VStack(alignment: .leading, spacing: 14) {
            summary
            LifeDotGrid(past: past, remaining: remaining, columns: moment.columns, glow: glow)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
            footer
        }
        .onAppear(perform: startGlow)
        .onChange(of: animationPaused) { _, _ in startGlow() }
    }

    private func startGlow() {
        guard !reduceMotion, !animationPaused else { glow = false; return }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glow = true }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(moment.remainingTitle)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundColor(.ember.opacity(0.9))
            Text("\(remaining)")
                .font(.system(.largeTitle, design: .serif).weight(.bold))
                .foregroundColor(.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
            if remaining == 0 && now >= lifeEnd {
                Text("기대 수명을 넘었어요. 이제부터는 모두 덤이에요")
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.inkMuted.opacity(0.8))
            } else {
                Text("지나온 \(past)번 · \(nextText)")
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.inkMuted.opacity(0.8))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("삶의 \(burnedPercent)%가 탔어요")
                .font(.system(.body, design: .serif))
                .foregroundColor(.inkMuted.opacity(0.8))
            Spacer()
            Button { showInput = true } label: {
                Text("만 \(age)세 · 기대 수명 \(expectancy)세")
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.ember.opacity(0.85))
                    .underline()
            }
            .buttonStyle(.plain)
            .accessibilityHint("태어난 날과 기대 수명 고치기")
        }
        .padding(.bottom, 8)
    }

    private var nextText: String {
        guard let next = counter.next(moment, after: now) else { return "" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: next)).day ?? 0
        return days <= 0 ? String(localized: "오늘이에요") : String(localized: "다음은 \(days)일 뒤")
    }
}

// MARK: - 점 격자

/// 지나간 것은 재, 바로 다음은 밝은 불씨, 그 뒤는 옅은 불씨. 수천 개라도 한 번에 그리도록 캔버스로.
/// 주어진 자리 안에 다 들어가게 점 크기를 정한다 — 페이지를 넘기는 가로 쓸기와 겹치지 않게 스크롤하지 않는다.
struct LifeDotGrid: View {
    let past: Int
    let remaining: Int
    let columns: Int
    var glow: Bool

    static let ashColor = Color.inkMuted.opacity(0.28)
    static let emberColor = Color.ember.opacity(0.55)

    private var total: Int { past + remaining }
    private var rows: Int { max(1, Int((Double(total) / Double(columns)).rounded(.up))) }

    var body: some View {
        GeometryReader { geo in
            let cell = min(geo.size.width / CGFloat(columns), geo.size.height / CGFloat(rows), 40)
            let dot = cell * 0.72
            let inset = (cell - dot) / 2
            let ox = (geo.size.width - cell * CGFloat(columns)) / 2
            Canvas { ctx, _ in
                for i in 0..<total {
                    let rect = CGRect(x: ox + CGFloat(i % columns) * cell + inset,
                                      y: CGFloat(i / columns) * cell + inset,
                                      width: dot, height: dot)
                    let color = i < past ? Self.ashColor : (i == past ? Color.ember : Self.emberColor)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
            if remaining > 0 {
                // 바로 다음 하나는 숨 쉬듯 빛난다
                Circle()
                    .fill(Color.ember.opacity(glow ? 0.35 : 0.1))
                    .frame(width: max(cell * 1.4, 10), height: max(cell * 1.4, 10))
                    .position(x: ox + (CGFloat(past % columns) + 0.5) * cell,
                              y: (CGFloat(past / columns) + 0.5) * cell)
                    .allowsHitTesting(false)
            }
        }
    }
}
