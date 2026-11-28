// ParchmentOverview.swift
// 한눈에 보기 — 한 장씩 넘기지 않고 모든 양피지가 얼마나 탔는지 세로로 늘어놓는다.
// 한 줄을 누르면 그 양피지의 큰 화면으로 돌아간다.

import SwiftUI

/// 메인 화면을 큰 양피지로 볼지, 모두 한눈에 볼지. 고른 것을 기억한다.
enum MainLayout {
    static let storageKey = "mainShowsOverview"
}

struct ParchmentOverview: View {
    let periods: [PeriodType]
    let title: (PeriodType) -> String
    let onSelect: (PeriodType) -> Void

    @EnvironmentObject var bedtimeManager: BedtimeManager
    @EnvironmentObject var deadlineManager: DeadlineManager

    var body: some View {
        // 주 · 달 · 해의 남은 시간은 시계에서 바로 계산하므로 1초마다 다시 읽는다
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(periods) { period in
                        Button { onSelect(period) } label: { row(period) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
    }

    private func row(_ period: PeriodType) -> some View {
        let info = info(for: period)
        return HStack(spacing: 14) {
            Group {
                if let progress = info.progress {
                    MiniParchmentView(progress: progress)
                } else {
                    Image(systemName: "hourglass")
                        .scaledFont(size: 22, weight: .semibold)
                        .foregroundColor(.ember.opacity(0.8))
                }
            }
            .frame(width: 44, height: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text(info.name)
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(.ember.opacity(0.9))
                    .lineLimit(1)
                Text(info.detail)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 8)

            if let progress = info.progress {
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundColor(.ember.opacity(0.75))
            }
            Image(systemName: "chevron.forward")
                .scaledFont(size: 11, weight: .semibold)
                .foregroundColor(.inkMuted.opacity(0.5))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.appBackgroundWarm)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.ember.opacity(0.15), lineWidth: 1))
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("탭하면 크게 봅니다")
    }

    /// 한 줄에 쓸 이름 · 남은 시간 · 탄 비율. 남은 시간 페이지는 양피지가 아니라 세어 보기라 비율이 없다.
    private func info(for period: PeriodType) -> (name: String, detail: String, progress: Double?) {
        switch period {
        case .freeTime:
            return (title(period), String(localized: "자유시간 · 세어 본 날"), nil)
        case .deadline:
            guard let deadline = deadlineManager.deadlines.first(where: { !$0.isExpired() }) else {
                return (title(period), "", nil)
            }
            return (deadline.title, deadline.remainingString(), deadline.progress())
        default:
            return (title(period), bedtimeManager.remainingString(for: period), bedtimeManager.progress(for: period))
        }
    }
}
