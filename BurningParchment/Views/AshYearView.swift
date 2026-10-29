// AshYearView.swift
// 재의 흐름 ▸ 한 해의 재 (프로).
//
// 지난 열두 달(이번 달 포함)의 재를 달마다 종류별로 쌓아 보여 주고, 한 해를 몇 줄로 요약한다.
// 프로가 아니면 같은 카드를 흐리게 보여 주고 그 위에 여는 버튼을 둔다 — 자기 기록으로 미리 본다.

import SwiftUI
import Charts

struct AshYearView: View {
    @EnvironmentObject var reflectionManager: ReflectionManager
    @EnvironmentObject var storeManager: StoreManager
    @State private var showPaywall = false

    /// 차트에 쌓는 종류 (아래부터). 분류 안 된 옛 재는 빼고 센다.
    private static let stacked: [ReflectionCategory] = [.forged, .accept, .stop, .missed, .scattered]

    private struct MonthBucket: Identifiable {
        let start: Date
        let counts: [ReflectionCategory: Int]
        var id: Date { start }
        var total: Int { counts.values.reduce(0, +) }
    }

    private struct Bar: Identifiable {
        let month: Date
        let category: ReflectionCategory
        let count: Int
        var id: String { "\(month.timeIntervalSince1970)-\(category.rawValue)" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            ZStack {
                content
                    .blur(radius: storeManager.isPro ? 0 : 6)
                    .allowsHitTesting(storeManager.isPro)
                    .accessibilityHidden(!storeManager.isPro)
                if !storeManager.isPro { lockOverlay }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.ink.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.ember.opacity(0.10), lineWidth: 1))
        )
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .insights)
                .environmentObject(storeManager)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("한 해의 재")
                    .scaledFont(size: 15, weight: .semibold, design: .serif)
                    .foregroundColor(.ember.opacity(0.9))
                Text("지난 12개월, 달마다 어디로 흘렀나")
                    .scaledFont(size: 11, design: .serif)
                    .foregroundColor(.inkMuted.opacity(0.5))
            }
            Spacer()
            if !storeManager.isPro {
                Text("프로")
                    .scaledFont(size: 10, weight: .semibold)
                    .foregroundColor(.onEmber)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.ember.opacity(0.8)))
            }
        }
    }

    // MARK: Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            chart
                .frame(height: 180)
            legend
            Divider().background(Color.ember.opacity(0.12))
            highlights
        }
    }

    private var chart: some View {
        Chart(bars) { bar in
            BarMark(
                x: .value("달", bar.month, unit: .month),
                y: .value("재", bar.count)
            )
            .foregroundStyle(by: .value("종류", bar.category.shortLabel))
        }
        .chartForegroundStyleScale(
            domain: Self.stacked.map(\.shortLabel),
            range: Self.stacked.map(color(for:))
        )
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { value in
                AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                    .foregroundStyle(Color.inkMuted.opacity(0.6))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Color.ink.opacity(0.06))
                AxisValueLabel().foregroundStyle(Color.inkMuted.opacity(0.5))
            }
        }
        .accessibilityLabel("지난 12개월 달별 재")
        .accessibilityValue(accessibilitySummary)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(Self.stacked, id: \.self) { cat in
                HStack(spacing: 4) {
                    Circle().fill(color(for: cat)).frame(width: 7, height: 7)
                    Text(cat.shortLabel)
                        .scaledFont(size: 10)
                        .foregroundColor(.inkMuted.opacity(0.65))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: 10) {
            highlightRow(icon: "calendar",
                         title: String(localized: "기록한 날"),
                         value: String(localized: "\(recordedDays)일"))
            highlightRow(icon: "link",
                         title: String(localized: "가장 길게 이어 쓴 날"),
                         value: String(localized: "\(longestStreak)일"))
            if let busiest {
                highlightRow(icon: "archivebox",
                             title: String(localized: "재가 가장 많이 쌓인 달"),
                             value: monthName(busiest.start) + " · " + String(localized: "재 \(busiest.total)톨"))
            }
            if let forgedBest {
                highlightRow(icon: "hammer",
                             title: String(localized: "마음먹은 대로 가장 많이 한 달"),
                             value: monthName(forgedBest.start) + " · " + String(localized: "\(forgedBest.counts[.forged] ?? 0)번"))
            }
        }
    }

    private func highlightRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .scaledFont(size: 12)
                .foregroundColor(.ember.opacity(0.7))
                .frame(width: 18)
            Text(title)
                .scaledFont(size: 13, design: .serif)
                .foregroundColor(.inkMuted.opacity(0.75))
            Spacer()
            Text(value)
                .scaledFont(size: 13, weight: .medium, design: .serif)
                .foregroundColor(.ink.opacity(0.85))
        }
        .accessibilityElement(children: .combine)
    }

    private var lockOverlay: some View {
        Button { showPaywall = true } label: {
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .scaledFont(size: 18)
                Text("프로에서 한 해의 흐름을 열어요")
                    .scaledFont(size: 14, weight: .medium, design: .serif)
            }
            .foregroundColor(.ember)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.appBackgroundWarm.opacity(0.92))
                    .shadow(color: .appShadow.opacity(0.3), radius: 10, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Data

    private var cal: Calendar { Calendar.current }

    /// 이번 달을 마지막으로 하는 12개월
    private var months: [MonthBucket] {
        guard let thisMonth = cal.dateInterval(of: .month, for: Date())?.start else { return [] }
        let starts = (0..<12).reversed().compactMap { cal.date(byAdding: .month, value: -$0, to: thisMonth) }
        guard let first = starts.first else { return [] }
        var table: [Date: [ReflectionCategory: Int]] = [:]
        for r in reflectionManager.reflections where r.date >= first && Self.stacked.contains(r.category) {
            guard let m = cal.dateInterval(of: .month, for: r.date)?.start else { continue }
            table[m, default: [:]][r.category, default: 0] += 1
        }
        return starts.map { MonthBucket(start: $0, counts: table[$0] ?? [:]) }
    }

    private var bars: [Bar] {
        months.flatMap { m in
            Self.stacked.map { Bar(month: m.start, category: $0, count: m.counts[$0] ?? 0) }
        }
    }

    /// 지난 12개월 안에서 회고를 남긴 날짜들
    private var recordedDaySet: Set<Date> {
        guard let first = months.first?.start else { return [] }
        return Set(reflectionManager.reflections.filter { $0.date >= first }.map { cal.startOfDay(for: $0.date) })
    }

    private var recordedDays: Int { recordedDaySet.count }

    private var longestStreak: Int {
        let days = recordedDaySet.sorted()
        var best = 0, run = 0
        var previous: Date?
        for d in days {
            if let p = previous, cal.dateComponents([.day], from: p, to: d).day == 1 {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = d
        }
        return best
    }

    private var busiest: MonthBucket? {
        months.filter { $0.total > 0 }.max { $0.total < $1.total }
    }

    private var forgedBest: MonthBucket? {
        months.filter { ($0.counts[.forged] ?? 0) > 0 }.max { ($0.counts[.forged] ?? 0) < ($1.counts[.forged] ?? 0) }
    }

    private func color(for cat: ReflectionCategory) -> Color {
        let c = cat.particleColor
        return Color(red: c.0, green: c.1, blue: c.2)
    }

    private func monthName(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("yMMM")
        return f.string(from: date)
    }

    private var accessibilitySummary: String {
        months.filter { $0.total > 0 }
            .map { monthName($0.start) + " " + String(localized: "재 \($0.total)톨") }
            .joined(separator: ", ")
    }
}
