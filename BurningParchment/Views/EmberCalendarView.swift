// EmberCalendarView.swift
// 잔불 달력. ReflectionUrnView.swift 에서 나눴다 — 한 파일이 3천 줄이면 한 줄을 고쳐도 통째로 다시 컴파일된다.

import SwiftUI
import LeeoKit

// MARK: - Ember Calendar (잔불 달력)
// 한 달 격자에 하루 = 잔불 하나.
// 회고가 있는 날은 그날의 대표 카테고리 색으로 빛나고, 없는 날은 꺼진 재.
// 날을 탭하면 그날의 회고가 아래에 펼쳐짐.

struct EmberCalendarView: View {
    @EnvironmentObject var reflectionManager: ReflectionManager
    let onEdit: (DayReflection) -> Void

    @State private var displayedMonth: Date
    @State private var selectedDay: Date?

    init(onEdit: @escaping (DayReflection) -> Void) {
        self.onEdit = onEdit
        let cal = Calendar.current
        _displayedMonth = State(initialValue: cal.dateInterval(of: .month, for: Date())?.start ?? Date())
        _selectedDay = State(initialValue: cal.startOfDay(for: Date()))
    }

    private var cal: Calendar {
        var c = Calendar.current
        c.locale = Locale.current
        c.firstWeekday = 2  // 월요일 시작
        return c
    }

    private var weekdaySymbols: [String] {
        let symbols = cal.veryShortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private var byDay: [Date: [DayReflection]] {
        Dictionary(grouping: reflectionManager.reflections) { cal.startOfDay(for: $0.date) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            weekdayHeader
            dayGrid
            Divider()
                .background(Color.ember.opacity(0.12))
            selectedDayDetail
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.ink.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.ember.opacity(0.10), lineWidth: 1))
        )
    }

    // MARK: Header

    private var monthTitle: String {
        let f = TimeFormat.formatter("yMMMM")
        return f.string(from: displayedMonth)
    }

    private var canGoNext: Bool {
        guard let next = cal.date(byAdding: .month, value: 1, to: displayedMonth) else { return false }
        return next <= Date()
    }

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "flame")
                    .scaledFont(size: 11)
                    .foregroundColor(.ember.opacity(0.6))
                Text(monthTitle)
                    .scaledFont(size: 14, weight: .semibold, design: .serif)
                    .foregroundColor(.ember.opacity(0.85))
            }

            Spacer()

            HStack(spacing: 4) {
                Button { moveMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .scaledFont(size: 12, weight: .semibold)
                        .foregroundColor(.ember.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.ink.opacity(0.04)))
                }
                .accessibilityLabel("이전 달")

                Button { moveMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .scaledFont(size: 12, weight: .semibold)
                        .foregroundColor(canGoNext ? .ember.opacity(0.7) : .inkMuted.opacity(0.25))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.ink.opacity(0.04)))
                }
                .disabled(!canGoNext)
                .accessibilityLabel("다음 달")
            }
        }
    }

    private func moveMonth(_ delta: Int) {
        guard let next = cal.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        let gen = UISelectionFeedbackGenerator()
        gen.selectionChanged()
        withAnimation(.easeInOut(duration: 0.18)) {
            displayedMonth = next
            // 이동한 달에 오늘이 있으면 오늘을, 아니면 선택 해제
            if cal.isDate(next, equalTo: Date(), toGranularity: .month) {
                selectedDay = cal.startOfDay(for: Date())
            } else {
                selectedDay = nil
            }
        }
    }

    // MARK: Grid

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .scaledFont(size: 10, design: .serif)
                    .foregroundColor(.inkMuted.opacity(0.45))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthDays: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: displayedMonth),
              let dayCount = cal.range(of: .day, in: .month, for: displayedMonth)?.count
        else { return [] }
        let first = interval.start
        let leadingBlanks = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for d in 0..<dayCount {
            result.append(cal.date(byAdding: .day, value: d, to: first))
        }
        return result
    }

    private var dayGrid: some View {
        let grouped = byDay  // 칸마다 회고 전체를 다시 묶지 않게 한 번만 구한다
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day, items: grouped[cal.startOfDay(for: day)] ?? [])
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private func dayCell(_ day: Date, items: [DayReflection]) -> some View {
        let isToday = cal.isDateInToday(day)
        let isSelected = selectedDay.map { cal.isDate($0, inSameDayAs: day) } ?? false
        let isFuture = day > Date() && !isToday

        return Button {
            let gen = UISelectionFeedbackGenerator()
            gen.selectionChanged()
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDay = cal.startOfDay(for: day)
            }
        } label: {
            VStack(spacing: 4) {
                Text("\(cal.component(.day, from: day))")
                    .scaledFont(size: 9, design: .monospaced)
                    .foregroundColor(isToday
                        ? .ember.opacity(0.95)
                        : .inkMuted.opacity(isFuture ? 0.2 : 0.5))

                ZStack {
                    if items.isEmpty {
                        // 꺼진 재
                        Circle()
                            .fill(Color.ink.opacity(isFuture ? 0.03 : 0.10))
                            .frame(width: 6, height: 6)
                    } else {
                        // 잔불 — 대표 카테고리 색으로 빛남, 개수만큼 커짐
                        let color = emberColor(for: items)
                        let size = emberSize(count: items.count)
                        Circle()
                            .fill(color)
                            .frame(width: size, height: size)
                            .shadow(color: color.opacity(0.9), radius: 3)
                            .shadow(color: .ember.opacity(0.5), radius: 6)
                    }
                }
                .frame(height: 12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.ember.opacity(0.10) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isToday ? Color.ember.opacity(0.55)
                        : (isSelected ? Color.ember.opacity(0.30) : Color.clear),
                        lineWidth: 1
                    )
            )
        }
        .disabled(isFuture)
        .accessibilityLabel(dayAccessibilityLabel(day, count: items.count, isToday: isToday))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func emberColor(for items: [DayReflection]) -> Color {
        var counts: [ReflectionCategory: Int] = [:]
        for r in items { counts[r.category, default: 0] += 1 }
        let cat = counts.max { $0.value < $1.value }?.key ?? .uncategorized
        let c = cat.particleColor
        return Color(red: c.0, green: c.1, blue: c.2)
    }

    private func emberSize(count: Int) -> CGFloat {
        switch count {
        case 1:  return 7
        case 2:  return 9
        default: return 11
        }
    }

    private func dayAccessibilityLabel(_ day: Date, count: Int, isToday: Bool) -> String {
        let f = TimeFormat.formatter("Md")
        let base = (isToday ? String(localized: "오늘, ") : "") + f.string(from: day)
        return count > 0 ? String(localized: "\(base), 회고 \(count)개") : String(localized: "\(base), 기록 없음")
    }

    // MARK: Selected Day Detail

    @ViewBuilder
    private var selectedDayDetail: some View {
        if let sel = selectedDay {
            let items = (byDay[sel] ?? []).sorted { $0.createdAt > $1.createdAt }
            VStack(alignment: .leading, spacing: 8) {
                Text(selectedDayTitle(sel))
                    .scaledFont(size: 12, weight: .medium, design: .serif)
                    .foregroundColor(.ember.opacity(0.7))

                if items.isEmpty {
                    Text("이 날의 재는 남아 있지 않아요")
                        .scaledFont(size: 12, design: .serif)
                        .foregroundColor(.inkMuted.opacity(0.45))
                        .padding(.vertical, 4)
                } else {
                    ForEach(items) { item in
                        let period = item.weekPeriod
                        Button { onEdit(item) } label: {
                            ReflectionRow(item: item,
                                          periodLabel: period.title,
                                          muted: !reflectionManager.hasMeaning(period))
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
            }
        } else {
            Text("잔불을 탭하면 그날의 회고가 나와요")
                .scaledFont(size: 11, design: .serif)
                .foregroundColor(.inkMuted.opacity(0.4))
        }
    }

    private func selectedDayTitle(_ day: Date) -> String {
        let f = TimeFormat.formatter("MdE")
        return f.string(from: day)
    }
}
