// BedtimeHomeWidget.swift
// 홈 화면 양피지 연소 위젯 (일간 / 주간 / 월간 / 연간)

import SwiftUI
import WidgetKit

// MARK: - Period

enum WidgetPeriod: String {
    case daily, weekly, monthly, yearly

    var label: String {
        switch self {
        case .daily:   return "취침까지"
        case .weekly:  return "이번 주"
        case .monthly: return "이번 달"
        case .yearly:  return "올해"
        }
    }

    var fullLabel: String {
        switch self {
        case .daily:   return "취침까지 남은 시간"
        case .weekly:  return "이번 주 남은 시간"
        case .monthly: return "이번 달 남은 시간"
        case .yearly:  return "올해 남은 시간"
        }
    }
}

// MARK: - Entry

struct ParchmentEntry: TimelineEntry {
    let date: Date
    let period: WidgetPeriod
    let progress: Double
    let remainingText: String
    let bedtimeDate: Date?
    let bedtimeString: String
    let isActive: Bool
    let isBeforeWakeTime: Bool
    let remainingSeconds: TimeInterval

    var percentRemaining: Int { Int((1.0 - progress) * 100) }

    var shortTimeString: String {
        let s = Int(remainingSeconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    enum DisplayMode { case burning, sleeping, wakeUpSoon }

    var displayMode: DisplayMode {
        guard period == .daily else { return .burning }
        if isActive { return .burning }
        if isBeforeWakeTime { return remainingSeconds <= 1800 ? .wakeUpSoon : .sleeping }
        return .sleeping
    }
}

// MARK: - Provider

struct ParchmentProvider: TimelineProvider {
    let period: WidgetPeriod
    private let sd = UserDefaults(suiteName: "group.com.burningparchment.app")

    func placeholder(in context: Context) -> ParchmentEntry {
        let rem: TimeInterval = 5 * 3600 + 24 * 60
        return ParchmentEntry(
            date: .now, period: period, progress: 0.35,
            remainingText: period == .daily ? "5h 24m" : "3일 4시간",
            bedtimeDate: nil,
            bedtimeString: "11:00 PM", isActive: true,
            isBeforeWakeTime: false, remainingSeconds: rem
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ParchmentEntry) -> Void) {
        completion(calculate(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ParchmentEntry>) -> Void) {
        let now = Date()
        let refresh: Double = period == .daily ? 3600 : 21600

        var entries: [ParchmentEntry] = []

        // 단일 경로: App Group의 bedtimeHour/bedtimeMinute에서 직접 계산
        // 이전의 shared_bedtimeDate 경로는 타이밍 경쟁으로 불일치 발생 — 제거
        switch period {
        case .daily:
            for i in 0..<120 {
                entries.append(calculate(for: now.addingTimeInterval(Double(i) * 60)))
            }
        default:
            for i in 0..<24 {
                entries.append(calculate(for: now.addingTimeInterval(Double(i) * 3600)))
            }
        }

        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(refresh))))
    }

    private func calculate(for date: Date) -> ParchmentEntry {
        let bedH  = sd?.object(forKey: "bedtimeHour")   as? Int ?? 23
        let bedM  = sd?.object(forKey: "bedtimeMinute") as? Int ?? 0
        let wakeH = sd?.object(forKey: "wakeHour")      as? Int ?? 7
        let wakeM = sd?.object(forKey: "wakeMinute")    as? Int ?? 0

        let h12 = bedH > 12 ? bedH - 12 : (bedH == 0 ? 12 : bedH)
        let ampm = bedH >= 12 ? "PM" : "AM"
        let bedtimeStr = String(format: "%d:%02d %@", h12, bedM, ampm)

        let (dailyProg, remSec, isActive, isBeforeWake, dailyBedDate) = dailyProgress(
            date: date, wakeH: wakeH, wakeM: wakeM, bedH: bedH, bedM: bedM
        )
        let cal = Calendar.current

        var prog: Double = 0
        var remText: String = ""

        switch period {
        case .daily:
            prog = dailyProg
            let h = Int(remSec) / 3600
            let m = (Int(remSec) % 3600) / 60
            remText = h > 0 ? "\(h)h \(m)m" : "\(m)m"

        case .weekly:
            let start = thisMondayMidnight(from: date, cal: cal)
            let end   = nextMondayMidnight(from: date, cal: cal)
            let total = max(end.timeIntervalSince(start), 1)
            let rem   = max(end.timeIntervalSince(date), 0)
            prog = min(max(1.0 - rem / total, 0), 1)
            remText = formatSeconds(rem)

        case .monthly:
            let start = firstOfThisMonth(from: date, cal: cal)
            let end   = firstOfNextMonth(from: date, cal: cal)
            let total = max(end.timeIntervalSince(start), 1)
            let rem   = max(end.timeIntervalSince(date), 0)
            prog = min(max(1.0 - rem / total, 0), 1)
            remText = formatSeconds(rem)

        case .yearly:
            let start = jan1ThisYear(from: date, cal: cal)
            let end   = jan1NextYear(from: date, cal: cal)
            let total = max(end.timeIntervalSince(start), 1)
            let rem   = max(end.timeIntervalSince(date), 0)
            prog = min(max(1.0 - rem / total, 0), 1)
            remText = formatSeconds(rem)
        }

        return ParchmentEntry(
            date: date, period: period, progress: prog,
            remainingText: remText,
            bedtimeDate: (period == .daily && isActive) ? dailyBedDate : nil,
            bedtimeString: bedtimeStr,
            isActive: isActive, isBeforeWakeTime: isBeforeWake, remainingSeconds: remSec
        )
    }

    // (progress, remainingSeconds, isActive, isBeforeWakeTime, bedDate)
    private func dailyProgress(date: Date, wakeH: Int, wakeM: Int, bedH: Int, bedM: Int) -> (Double, TimeInterval, Bool, Bool, Date?) {
        let cal = Calendar.current
        var wc = cal.dateComponents([.year, .month, .day], from: date)
        wc.hour = wakeH; wc.minute = wakeM; wc.second = 0
        guard let todayWake = cal.date(from: wc) else { return (0, 0, false, true, nil) }

        if date >= todayWake {
            var bc = cal.dateComponents([.year, .month, .day], from: date)
            bc.hour = bedH; bc.minute = bedM; bc.second = 0
            guard var bed = cal.date(from: bc) else { return (0, 0, false, false, nil) }
            if bed <= todayWake { bed = cal.date(byAdding: .day, value: 1, to: bed)! }
            let total = bed.timeIntervalSince(todayWake)
            let rem   = bed.timeIntervalSince(date)
            if rem <= 0 { return (1.0, 0, false, false, nil) }
            return (min(max(1.0 - rem / total, 0), 1), rem, true, false, bed)
        } else {
            return (0, todayWake.timeIntervalSince(date), false, true, nil)
        }
    }

    private func formatSeconds(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days  = total / 86400
        let hours = (total % 86400) / 3600
        let mins  = (total % 3600) / 60
        if days > 0  { return "\(days)일 \(hours)시간" }
        if hours > 0 { return "\(hours)시간 \(mins)분" }
        return "\(mins)분"
    }

    // MARK: - Calendar Boundary Helpers

    private func midnight(of date: Date, cal: Calendar) -> Date {
        var c = cal.dateComponents([.year, .month, .day], from: date)
        c.hour = 0; c.minute = 0; c.second = 0
        return cal.date(from: c)!
    }

    private func nextMondayMidnight(from date: Date, cal: Calendar) -> Date {
        let weekday = cal.component(.weekday, from: date)
        let days = weekday == 2 ? 7 : (9 - weekday) % 7
        return cal.date(byAdding: .day, value: days, to: midnight(of: date, cal: cal))!
    }

    private func thisMondayMidnight(from date: Date, cal: Calendar) -> Date {
        let weekday = cal.component(.weekday, from: date)
        let days = weekday == 1 ? 6 : weekday - 2
        return cal.date(byAdding: .day, value: -days, to: midnight(of: date, cal: cal))!
    }

    private func firstOfNextMonth(from date: Date, cal: Calendar) -> Date {
        var c = cal.dateComponents([.year, .month], from: date)
        c.month! += 1; c.day = 1; c.hour = 0; c.minute = 0; c.second = 0
        return cal.date(from: c)!
    }

    private func firstOfThisMonth(from date: Date, cal: Calendar) -> Date {
        var c = cal.dateComponents([.year, .month], from: date)
        c.day = 1; c.hour = 0; c.minute = 0; c.second = 0
        return cal.date(from: c)!
    }

    private func jan1NextYear(from date: Date, cal: Calendar) -> Date {
        var c = DateComponents()
        c.year = cal.component(.year, from: date) + 1
        c.month = 1; c.day = 1; c.hour = 0; c.minute = 0; c.second = 0
        return cal.date(from: c)!
    }

    private func jan1ThisYear(from date: Date, cal: Calendar) -> Date {
        var c = DateComponents()
        c.year = cal.component(.year, from: date)
        c.month = 1; c.day = 1; c.hour = 0; c.minute = 0; c.second = 0
        return cal.date(from: c)!
    }
}

// MARK: - Burning Heart View

struct BurningHeartView: View {
    var body: some View {
        Canvas { ctx, size in
            let W = size.width
            let H = size.height
            let cx = W / 2
            let cy = H * 0.45
            let heartSize = min(W, H) * 0.4

            let heartPath = makeHeart(cx: cx, cy: cy, size: heartSize)

            ctx.blendMode = .screen
            ctx.fill(heartPath, with: .color(.orange.opacity(0.3)))

            ctx.blendMode = .normal
            ctx.fill(heartPath, with: .linearGradient(
                Gradient(colors: [
                    Color(red: 1.0, green: 0.6, blue: 0.1),
                    Color(red: 1.0, green: 0.3, blue: 0.05),
                    Color(red: 0.8, green: 0.15, blue: 0.0),
                ]),
                startPoint: CGPoint(x: cx, y: cy - heartSize),
                endPoint: CGPoint(x: cx, y: cy + heartSize * 0.8)
            ))

            let innerSize = heartSize * 0.55
            let innerPath = makeHeart(cx: cx, cy: cy + heartSize * 0.05, size: innerSize)
            ctx.blendMode = .screen
            ctx.fill(innerPath, with: .linearGradient(
                Gradient(colors: [Color.yellow.opacity(0.7), Color.orange.opacity(0.2)]),
                startPoint: CGPoint(x: cx, y: cy - innerSize),
                endPoint: CGPoint(x: cx, y: cy + innerSize * 0.6)
            ))
        }
    }

    private func makeHeart(cx: Double, cy: Double, size: Double) -> Path {
        var path = Path()
        let w = size
        let h = size * 0.9
        path.move(to: CGPoint(x: cx, y: cy + h * 0.7))
        path.addCurve(
            to: CGPoint(x: cx - w, y: cy - h * 0.1),
            control1: CGPoint(x: cx - w * 0.2, y: cy + h * 0.4),
            control2: CGPoint(x: cx - w * 1.1, y: cy + h * 0.2)
        )
        path.addCurve(
            to: CGPoint(x: cx, y: cy - h * 0.3),
            control1: CGPoint(x: cx - w * 0.9, y: cy - h * 0.6),
            control2: CGPoint(x: cx - w * 0.2, y: cy - h * 0.5)
        )
        path.addCurve(
            to: CGPoint(x: cx + w, y: cy - h * 0.1),
            control1: CGPoint(x: cx + w * 0.2, y: cy - h * 0.5),
            control2: CGPoint(x: cx + w * 0.9, y: cy - h * 0.6)
        )
        path.addCurve(
            to: CGPoint(x: cx, y: cy + h * 0.7),
            control1: CGPoint(x: cx + w * 1.1, y: cy + h * 0.2),
            control2: CGPoint(x: cx + w * 0.2, y: cy + h * 0.4)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Small Widget Content

private struct SmallWidgetContent: View {
    let entry: ParchmentEntry

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.55
            VStack(spacing: 6) {
                switch entry.displayMode {
                case .burning:
                    MiniParchmentView(progress: entry.progress)
                        .frame(width: side, height: side)
                    Text(entry.remainingText)
                        .font(.system(size: 19, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if entry.period != .daily {
                        Text(entry.period.label)
                            .font(.system(size: 10))
                            .foregroundColor(.gray.opacity(0.6))
                    }

                case .sleeping:
                    BurningHeartView()
                        .frame(width: side, height: side)
                    Text("수면 중")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.orange.opacity(0.7))

                case .wakeUpSoon:
                    MiniParchmentView(progress: 0)
                        .frame(width: side, height: side)
                    Text("기상 \(entry.shortTimeString)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.yellow)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Medium Widget Content

private struct MediumWidgetContent: View {
    let entry: ParchmentEntry

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.height * 0.78
            HStack(spacing: 14) {
                switch entry.displayMode {
                case .burning:
                    MiniParchmentView(progress: entry.progress)
                        .frame(width: side, height: side)
                    burningInfo

                case .sleeping:
                    BurningHeartView()
                        .frame(width: side, height: side)
                    sleepInfo

                case .wakeUpSoon:
                    MiniParchmentView(progress: 0)
                        .frame(width: side, height: side)
                    wakeUpInfo
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var burningInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.period.fullLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.orange.opacity(0.7))

            Text(entry.remainingText)
                .font(.system(
                    size: entry.period == .daily ? 28 : 20,
                    weight: .light,
                    design: entry.period == .daily ? .monospaced : .serif
                ))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            progressBar

            if entry.period == .daily {
                HStack(spacing: 4) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow.opacity(0.6))
                    Text(entry.bedtimeString)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * (1.0 - entry.progress), height: 4)
                }
            }
            .frame(height: 4)
            Text("\(entry.percentRemaining)%")
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .frame(width: 32, alignment: .trailing)
        }
    }

    private var sleepInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("수면 중")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.orange)
            Text("좋은 꿈 꾸세요")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.7))
            HStack(spacing: 4) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow.opacity(0.6))
                Text("기상까지 \(entry.shortTimeString)")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
    }

    private var wakeUpInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("곧 기상")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.yellow)
            Text(entry.shortTimeString)
                .font(.system(size: 28, weight: .light, design: .monospaced))
                .foregroundColor(.white)
            Text("새로운 하루가 시작돼요")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.7))
        }
    }
}

// MARK: - Large Widget Content

private struct LargeWidgetContent: View {
    let entry: ParchmentEntry

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width * 0.52
            VStack(spacing: 12) {
                switch entry.displayMode {
                case .burning:
                    MiniParchmentView(progress: entry.progress)
                        .frame(width: side, height: side)
                    burningInfo

                case .sleeping:
                    BurningHeartView()
                        .frame(width: side, height: side)
                    sleepInfo

                case .wakeUpSoon:
                    MiniParchmentView(progress: 0)
                        .frame(width: side, height: side)
                    wakeUpInfo
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 16)
        }
    }

    private var burningInfo: some View {
        VStack(spacing: 8) {
            Text(entry.period.fullLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.orange.opacity(0.7))

            Text(entry.remainingText)
                .font(.system(
                    size: entry.period == .daily ? 36 : 26,
                    weight: .light,
                    design: entry.period == .daily ? .monospaced : .serif
                ))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * (1.0 - entry.progress), height: 6)
                    }
                }
                .frame(height: 6)
                Text("\(entry.percentRemaining)%")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 24)

            if entry.period == .daily {
                HStack(spacing: 6) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow.opacity(0.6))
                    Text("취침 \(entry.bedtimeString)")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
        }
    }

    private var sleepInfo: some View {
        VStack(spacing: 10) {
            Text("수면 중")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.orange)
            Text("좋은 꿈 꾸세요")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
            HStack(spacing: 6) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow.opacity(0.6))
                Text("기상까지 \(entry.shortTimeString)")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
        }
    }

    private var wakeUpInfo: some View {
        VStack(spacing: 8) {
            Text("곧 기상")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.yellow)
            Text(entry.shortTimeString)
                .font(.system(size: 36, weight: .light, design: .monospaced))
                .foregroundColor(.white)
            Text("새로운 하루가 시작돼요")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
        }
    }
}

// MARK: - Unified Widget View

struct BedtimeHomeWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: ParchmentEntry

    var body: some View {
        switch family {
        case .systemMedium: MediumWidgetContent(entry: entry)
        case .systemLarge:  LargeWidgetContent(entry: entry)
        default:            SmallWidgetContent(entry: entry)
        }
    }
}

// MARK: - Widget Background Modifier

private struct WidgetBackground: ViewModifier {
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

// MARK: - Widget Configurations

struct BedtimeHomeWidget: Widget {
    let kind = "BedtimeHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParchmentProvider(period: .daily)) { entry in
            BedtimeHomeWidgetView(entry: entry)
                .modifier(WidgetBackground())
        }
        .configurationDisplayName("일간 양피지")
        .description("오늘 취침까지 남은 시간")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WeeklyParchmentWidget: Widget {
    let kind = "WeeklyParchmentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParchmentProvider(period: .weekly)) { entry in
            BedtimeHomeWidgetView(entry: entry)
                .modifier(WidgetBackground())
        }
        .configurationDisplayName("주간 양피지")
        .description("이번 주 남은 시간")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MonthlyParchmentWidget: Widget {
    let kind = "MonthlyParchmentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParchmentProvider(period: .monthly)) { entry in
            BedtimeHomeWidgetView(entry: entry)
                .modifier(WidgetBackground())
        }
        .configurationDisplayName("월간 양피지")
        .description("이번 달 남은 시간")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct YearlyParchmentWidget: Widget {
    let kind = "YearlyParchmentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParchmentProvider(period: .yearly)) { entry in
            BedtimeHomeWidgetView(entry: entry)
                .modifier(WidgetBackground())
        }
        .configurationDisplayName("연간 양피지")
        .description("올해 남은 시간")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
