// BedtimeHomeWidget.swift
// 홈 화면 양피지 연소 썸네일 위젯 (Small / Medium / Large)

import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct BedtimeHomeEntry: TimelineEntry {
    let date: Date
    let progress: Double
    let remainingSeconds: TimeInterval
    let bedtimeString: String
    let isActive: Bool
    let isBeforeWakeTime: Bool

    /// 위젯 표시 상태
    enum DisplayMode {
        case awake          // 기상~취침: 양피지 연소 중
        case sleepingHeart  // 취침~기상30분전: 불타는 하트
        case wakeUpSoon     // 기상30분전~기상: 온전한 양피지
    }

    var displayMode: DisplayMode {
        if isActive { return .awake }
        if isBeforeWakeTime {
            return remainingSeconds <= 1800 ? .wakeUpSoon : .sleepingHeart
        }
        // 취침 직후 (progress == 1.0, isActive false, isBeforeWakeTime false)
        return .sleepingHeart
    }

    var shortTimeString: String {
        let totalSec = Int(remainingSeconds)
        let h = totalSec / 3600
        let m = (totalSec % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    var percentRemaining: Int {
        Int((1.0 - progress) * 100)
    }
}

// MARK: - Timeline Provider

struct BedtimeHomeProvider: TimelineProvider {
    private let sharedDefaults = UserDefaults(suiteName: "group.com.burningparchment.app")

    func placeholder(in context: Context) -> BedtimeHomeEntry {
        BedtimeHomeEntry(
            date: Date(),
            progress: 0.3,
            remainingSeconds: 5 * 3600 + 24 * 60,
            bedtimeString: "11:00 PM",
            isActive: true,
            isBeforeWakeTime: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BedtimeHomeEntry) -> Void) {
        completion(calculateEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BedtimeHomeEntry>) -> Void) {
        let now = Date()
        var entries: [BedtimeHomeEntry] = []
        // 15분 간격으로 25시간치 엔트리 사전 생성 → 최소 15분마다 갱신 보장
        for i in 0..<100 {
            let entryDate = now.addingTimeInterval(Double(i) * 900)
            entries.append(calculateEntry(for: entryDate))
        }
        // 1시간마다 새 타임라인 요청
        let nextRefresh = now.addingTimeInterval(3600)
        let timeline = Timeline(entries: entries, policy: .after(nextRefresh))
        completion(timeline)
    }

    private func calculateEntry(for date: Date) -> BedtimeHomeEntry {
        let sd = sharedDefaults
        let bedH = sd?.integer(forKey: "shared_bedtimeHour") ?? 23
        let bedM = sd?.integer(forKey: "shared_bedtimeMinute") ?? 0
        let wakeH = sd?.integer(forKey: "shared_wakeHour") ?? 7
        let wakeM = sd?.integer(forKey: "shared_wakeMinute") ?? 0

        let h12 = bedH > 12 ? bedH - 12 : (bedH == 0 ? 12 : bedH)
        let ampm = bedH >= 12 ? "PM" : "AM"
        let bedtimeStr = String(format: "%d:%02d %@", h12, bedM, ampm)

        let cal = Calendar.current
        var wakeComps = cal.dateComponents([.year, .month, .day], from: date)
        wakeComps.hour = wakeH; wakeComps.minute = wakeM; wakeComps.second = 0
        guard let todayWake = cal.date(from: wakeComps) else {
            return BedtimeHomeEntry(date: date, progress: 0, remainingSeconds: 0,
                                    bedtimeString: bedtimeStr, isActive: false, isBeforeWakeTime: true)
        }

        if date >= todayWake {
            var bedComps = cal.dateComponents([.year, .month, .day], from: date)
            bedComps.hour = bedH; bedComps.minute = bedM; bedComps.second = 0
            guard var bedDate = cal.date(from: bedComps) else {
                return BedtimeHomeEntry(date: date, progress: 0, remainingSeconds: 0,
                                        bedtimeString: bedtimeStr, isActive: false, isBeforeWakeTime: false)
            }
            if bedDate <= todayWake { bedDate = cal.date(byAdding: .day, value: 1, to: bedDate)! }

            let total = bedDate.timeIntervalSince(todayWake)
            let remaining = bedDate.timeIntervalSince(date)

            if remaining <= 0 {
                return BedtimeHomeEntry(date: date, progress: 1.0, remainingSeconds: 0,
                                        bedtimeString: bedtimeStr, isActive: false, isBeforeWakeTime: false)
            }
            let progress = min(max(1.0 - remaining / total, 0), 1)
            return BedtimeHomeEntry(date: date, progress: progress, remainingSeconds: remaining,
                                    bedtimeString: bedtimeStr, isActive: true, isBeforeWakeTime: false)
        } else {
            let remaining = todayWake.timeIntervalSince(date)
            return BedtimeHomeEntry(date: date, progress: 0, remainingSeconds: remaining,
                                    bedtimeString: bedtimeStr, isActive: false, isBeforeWakeTime: true)
        }
    }
}

// MARK: - Burning Heart View (수면 중 표시)

struct BurningHeartView: View {
    var body: some View {
        Canvas { ctx, size in
            let W = size.width
            let H = size.height
            let cx = W / 2
            let cy = H * 0.45

            let heartSize = min(W, H) * 0.4

            // 하트 경로
            let heartPath = makeHeartPath(cx: cx, cy: cy, size: heartSize)

            // 외곽 glow
            ctx.blendMode = .screen
            ctx.fill(heartPath, with: .color(.orange.opacity(0.3)))

            // 하트 본체 — 불꽃 그라디언트
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

            // 하트 중심 밝은 영역
            let innerSize = heartSize * 0.55
            let innerPath = makeHeartPath(cx: cx, cy: cy + heartSize * 0.05, size: innerSize)
            ctx.blendMode = .screen
            ctx.fill(innerPath, with: .linearGradient(
                Gradient(colors: [
                    Color.yellow.opacity(0.7),
                    Color.orange.opacity(0.2),
                ]),
                startPoint: CGPoint(x: cx, y: cy - innerSize),
                endPoint: CGPoint(x: cx, y: cy + innerSize * 0.6)
            ))

            // 상단 불꽃 이펙트
            ctx.blendMode = .screen
            let flamePath = makeFlameHaloPath(cx: cx, cy: cy - heartSize * 0.5, width: heartSize * 0.6, height: heartSize * 0.5)
            ctx.fill(flamePath, with: .linearGradient(
                Gradient(colors: [
                    Color.yellow.opacity(0.4),
                    Color.orange.opacity(0.15),
                    Color.clear,
                ]),
                startPoint: CGPoint(x: cx, y: cy - heartSize * 1.0),
                endPoint: CGPoint(x: cx, y: cy - heartSize * 0.1)
            ))
        }
    }

    private func makeHeartPath(cx: Double, cy: Double, size: Double) -> Path {
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

    private func makeFlameHaloPath(cx: Double, cy: Double, width: Double, height: Double) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(
            x: cx - width / 2,
            y: cy - height / 2,
            width: width,
            height: height
        ))
        return path
    }
}

// MARK: - Small Widget View

private struct SmallWidgetContent: View {
    let entry: BedtimeHomeEntry

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.68

            VStack(spacing: 6) {
                switch entry.displayMode {
                case .awake:
                    MiniParchmentView(progress: entry.progress)
                        .frame(width: side, height: side)
                    Text(entry.shortTimeString)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange)
                        .monospacedDigit()

                case .sleepingHeart:
                    BurningHeartView()
                        .frame(width: side, height: side)
                    Text("수면 중")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange.opacity(0.7))

                case .wakeUpSoon:
                    MiniParchmentView(progress: 0)
                        .frame(width: side, height: side)
                    Text("기상 \(entry.shortTimeString)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.yellow)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Medium Widget View

private struct MediumWidgetContent: View {
    let entry: BedtimeHomeEntry

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.height * 0.78

            HStack(spacing: 14) {
                switch entry.displayMode {
                case .awake:
                    MiniParchmentView(progress: entry.progress)
                        .frame(width: side, height: side)
                    awakeInfo

                case .sleepingHeart:
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

    private var awakeInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("취침까지")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.orange.opacity(0.7))

            Text(entry.shortTimeString)
                .font(.system(size: 28, weight: .light, design: .monospaced))
                .foregroundColor(.white)
                .monospacedDigit()

            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: geo.size.width * (1.0 - entry.progress), height: 4)
                    }
                }
                .frame(height: 4)

                Text("\(entry.percentRemaining)%")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .frame(width: 32, alignment: .trailing)
            }

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
                .monospacedDigit()

            Text("새로운 하루가 시작돼요")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.7))
        }
    }
}

// MARK: - Large Widget View

private struct LargeWidgetContent: View {
    let entry: BedtimeHomeEntry

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width * 0.52

            VStack(spacing: 12) {
                switch entry.displayMode {
                case .awake:
                    MiniParchmentView(progress: entry.progress)
                        .frame(width: side, height: side)
                    awakeInfo

                case .sleepingHeart:
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

    private var awakeInfo: some View {
        VStack(spacing: 8) {
            Text("취침까지")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.orange.opacity(0.7))

            Text(entry.shortTimeString)
                .font(.system(size: 36, weight: .light, design: .monospaced))
                .foregroundColor(.white)
                .monospacedDigit()

            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                            )
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
                .monospacedDigit()

            Text("새로운 하루가 시작돼요")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
        }
    }
}

// MARK: - Unified Widget View

struct BedtimeHomeWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: BedtimeHomeEntry

    @ViewBuilder
    var content: some View {
        switch family {
        case .systemMedium:
            MediumWidgetContent(entry: entry)
        case .systemLarge:
            LargeWidgetContent(entry: entry)
        default:
            SmallWidgetContent(entry: entry)
        }
    }

    var body: some View {
        content
    }
}

// MARK: - Widget Configuration

struct BedtimeHomeWidget: Widget {
    let kind = "BedtimeHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BedtimeHomeProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                BedtimeHomeWidgetView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color(red: 0.08, green: 0.06, blue: 0.04)
                    }
            } else {
                ZStack {
                    Color(red: 0.08, green: 0.06, blue: 0.04)
                    BedtimeHomeWidgetView(entry: entry)
                }
            }
        }
        .configurationDisplayName("양피지")
        .description("오늘 남은 시간")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
