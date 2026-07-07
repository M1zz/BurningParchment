// BedtimeLockScreenWidget.swift
// 잠금 화면(락 스크린) 액세서리 위젯 — 취침까지 남은 시간
// 원형: 남은 비율 게이지, 직사각형: 라이브 카운트다운 + 게이지, 인라인: 한 줄 요약

import SwiftUI
import WidgetKit

// MARK: - Lock Screen View

struct BedtimeLockScreenWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: ParchmentEntry

    var body: some View {
        switch family {
        case .accessoryCircular:  circular
        case .accessoryInline:    inline
        default:                  rectangular
        }
    }

    /// 기상까지 남은 시각 (수면/기상 임박 모드에서 타이머 표시용)
    private var wakeDate: Date {
        entry.date.addingTimeInterval(entry.remainingSeconds)
    }

    // MARK: Circular (원형 게이지)

    @ViewBuilder
    private var circular: some View {
        switch entry.displayMode {
        case .burning:
            Gauge(value: Double(entry.percentRemaining), in: 0...100) {
                Image(systemName: "flame.fill")
            } currentValueLabel: {
                Text("\(entry.percentRemaining)%")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .minimumScaleFactor(0.7)
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()

        case .sleeping:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 16))
                    Text(entry.shortTimeString)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .minimumScaleFactor(0.7)
                }
            }
            .widgetAccentable()

        case .wakeUpSoon:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 14))
                    Text(entry.shortTimeString)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .minimumScaleFactor(0.7)
                }
            }
            .widgetAccentable()
        }
    }

    // MARK: Rectangular (직사각형)

    @ViewBuilder
    private var rectangular: some View {
        switch entry.displayMode {
        case .burning:
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text("취침까지")
                        .font(.system(size: 12, weight: .medium))
                } icon: {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                }
                .widgetAccentable()

                Group {
                    if let bd = entry.bedtimeDate {
                        Text(bd, style: .timer)
                    } else {
                        Text(entry.remainingText)
                    }
                }
                .font(.system(size: 21, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                ProgressView(value: Double(entry.percentRemaining), total: 100)
                    .progressViewStyle(.linear)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .sleeping:
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text("수면 중")
                        .font(.system(size: 12, weight: .medium))
                } icon: {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 11))
                }
                .widgetAccentable()

                Text(wakeDate, style: .timer)
                    .font(.system(size: 21, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("기상까지 남은 시간")
                    .font(.system(size: 11))
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .wakeUpSoon:
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text("곧 기상")
                        .font(.system(size: 12, weight: .medium))
                } icon: {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 11))
                }
                .widgetAccentable()

                Text(wakeDate, style: .timer)
                    .font(.system(size: 21, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("새로운 하루가 시작돼요")
                    .font(.system(size: 11))
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Inline (한 줄)

    @ViewBuilder
    private var inline: some View {
        switch entry.displayMode {
        case .burning:
            if let bd = entry.bedtimeDate {
                Text("🔥 취침까지 \(Text(bd, style: .timer))")
            } else {
                Text("🔥 취침까지 \(entry.remainingText)")
            }
        case .sleeping:
            Text("😴 기상까지 \(entry.shortTimeString)")
        case .wakeUpSoon:
            Text("🌅 곧 기상 · \(entry.shortTimeString)")
        }
    }
}

// MARK: - Clear Background (잠금 화면은 시스템이 배경 처리)

private struct LockScreenBackground: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(for: .widget) { Color.clear }
        } else {
            content
        }
    }
}

// MARK: - Widget Configuration

struct BedtimeLockScreenWidget: Widget {
    let kind = "BedtimeLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParchmentProvider(period: .daily)) { entry in
            BedtimeLockScreenWidgetView(entry: entry)
                .modifier(LockScreenBackground())
        }
        .configurationDisplayName("남은 시간")
        .description("잠금 화면에서 취침까지 남은 시간을 확인해요")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
