// DeadlineWidget.swift
// 데드라인 홈 화면 위젯

import SwiftUI
import WidgetKit

// MARK: - Entry

struct DeadlineEntry: TimelineEntry {
    let date: Date
    let title: String
    let emoji: String
    let progress: Double
    let remainingText: String
    let targetDateString: String
    let isExpired: Bool
    let hasDeadline: Bool

    var percentRemaining: Int { Int((1.0 - progress) * 100) }
}

// MARK: - Provider

struct DeadlineProvider: TimelineProvider {
    private let sd = UserDefaults(suiteName: "group.com.burningparchment.app")

    func placeholder(in context: Context) -> DeadlineEntry {
        DeadlineEntry(
            date: .now, title: String(localized: "프로젝트 제출"), emoji: "🎯",
            progress: 0.55, remainingText: String(localized: "3일 4시간"),
            targetDateString: String(localized: "2025.12.31 (수) 23:59"),
            isExpired: false, hasDeadline: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DeadlineEntry) -> Void) {
        completion(makeEntry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeadlineEntry>) -> Void) {
        let now = Date()

        // 남은 시간에 따라 갱신 단위 결정
        let nextRemaining: TimeInterval = {
            guard
                let data = sd?.data(forKey: "shared_deadlines"),
                let deadlines = try? JSONDecoder().decode([Deadline].self, from: data),
                let d = deadlines.filter({ !$0.isExpired(at: now) })
                                 .sorted(by: { $0.targetDate < $1.targetDate })
                                 .first
            else { return .infinity }
            return d.targetDate.timeIntervalSince(now)
        }()

        let interval: TimeInterval
        let count: Int
        if nextRemaining <= 86400 {
            // 1일 미만: 1분 단위로 정밀 갱신
            interval = 60
            count = min(Int(nextRemaining / 60) + 5, 120)
        } else {
            // 1일 초과: 1시간 단위
            interval = 3600
            count = 8
        }

        var entries: [DeadlineEntry] = []
        for i in 0..<max(count, 1) {
            entries.append(makeEntry(for: now.addingTimeInterval(Double(i) * interval)))
        }
        let refreshDate = entries.last?.date ?? now.addingTimeInterval(interval)
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    private func makeEntry(for date: Date) -> DeadlineEntry {
        guard
            let data      = sd?.data(forKey: "shared_deadlines"),
            let deadlines = try? JSONDecoder().decode([Deadline].self, from: data),
            let d         = deadlines.filter({ !$0.isExpired(at: date) })
                                     .sorted(by: { $0.targetDate < $1.targetDate })
                                     .first
        else {
            return DeadlineEntry(date: date, title: "", emoji: "🎯", progress: 0,
                                 remainingText: "", targetDateString: "",
                                 isExpired: false, hasDeadline: false)
        }

        let rem   = max(d.targetDate.timeIntervalSince(date), 0)
        let prog  = d.progress(at: date)
        return DeadlineEntry(
            date: date, title: d.title, emoji: d.emoji,
            progress: prog, remainingText: formatSeconds(rem),
            targetDateString: d.targetDateString,
            isExpired: rem <= 0, hasDeadline: true
        )
    }

    private func formatSeconds(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days  = total / 86400
        let hours = (total % 86400) / 3600
        let mins  = (total % 3600) / 60
        let secs  = total % 60
        if days > 0  { return String(localized: "\(days)일 \(hours)시간") }
        if hours > 0 { return String(localized: "\(hours)시간 \(mins)분") }
        if mins > 0  { return String(localized: "\(mins)분 \(secs)초") }
        return String(localized: "\(secs)초")
    }
}

// MARK: - Views

struct DeadlineWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: DeadlineEntry

    var body: some View {
        Group {
            if !entry.hasDeadline {
                noDeadlineView
            } else if family == .systemSmall {
                smallView
            } else {
                mediumView
            }
        }
    }

    private var noDeadlineView: some View {
        VStack(spacing: 10) {
            Image(systemName: "flag.fill")
                .font(.system(size: 26))
                .foregroundColor(.orange.opacity(0.25))
            Text("데드라인 없음")
                .font(.system(size: 12, design: .serif))
                .foregroundColor(.gray.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var smallView: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.55
            VStack(spacing: 4) {
                Text(entry.emoji)
                    .font(.system(size: 18))

                MiniParchmentView(progress: entry.progress)
                    .frame(width: side, height: side)

                Text(entry.remainingText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(entry.title)
                    .font(.system(size: 9, design: .serif))
                    .foregroundColor(.gray.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var mediumView: some View {
        GeometryReader { geo in
            let side = geo.size.height * 0.78
            HStack(spacing: 14) {
                MiniParchmentView(progress: entry.progress)
                    .frame(width: side, height: side)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 5) {
                        Text(entry.emoji).font(.system(size: 16))
                        Text(entry.title)
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .foregroundColor(.orange.opacity(0.9))
                            .lineLimit(1)
                    }

                    if entry.isExpired {
                        Text("마감 완료 🏁")
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundColor(.gray.opacity(0.6))
                    } else {
                        Text(entry.remainingText)
                            .font(.system(size: 20, weight: .light, design: .serif))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

                    progressBar

                    Text(entry.targetDateString)
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.45))
                        .lineLimit(1)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private var progressBar: some View {
        HStack(spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.25))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * (1.0 - entry.progress), height: 4)
                }
            }
            .frame(height: 4)
            Text("\(entry.percentRemaining)%")
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .frame(width: 28, alignment: .trailing)
        }
    }
}

// MARK: - Widget Background (local copy)

private struct DeadlineBG: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(for: .widget) {
                Color(red: 0.08, green: 0.06, blue: 0.04)
            }
        } else {
            ZStack {
                Color(red: 0.08, green: 0.06, blue: 0.04)
                content
            }
        }
    }
}

// MARK: - Widget Configuration

struct DeadlineWidget: Widget {
    let kind = "DeadlineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DeadlineProvider()) { entry in
            DeadlineWidgetView(entry: entry)
                .modifier(DeadlineBG())
        }
        .configurationDisplayName("데드라인 양피지")
        .description("다음 마감까지 남은 시간")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
