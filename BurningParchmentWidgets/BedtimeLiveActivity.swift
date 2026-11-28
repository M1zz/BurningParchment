// BedtimeLiveActivity.swift
// 다이나믹 아일랜드 & 잠금화면 Live Activity

import SwiftUI
import WidgetKit
import ActivityKit

struct BedtimeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BedtimeActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // ── Expanded ──
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 12) {
                        if context.state.showMiniParchment {
                            MiniParchmentView(progress: context.state.progress)
                                .frame(width: 52, height: 64)
                        } else {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.orange)
                                .frame(width: 52, height: 64)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Self.remaining(context)
                                .font(.system(size: 22, weight: .light))
                                .foregroundColor(.orange)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)

                            Text("🔥 \(Int((1.0 - context.state.progress) * 100))% 남음")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Spacer()
                        Text("취침 \(context.attributes.bedtimeString)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }

            } compactLeading: {
                if context.state.showMiniParchment {
                    MiniParchmentView(progress: context.state.progress)
                        .frame(width: 18, height: 22)
                } else {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }

            } compactTrailing: {
                Self.remaining(context)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: 64)

            } minimal: {
                if context.state.showMiniParchment {
                    MiniParchmentView(progress: context.state.progress)
                        .frame(width: 16, height: 20)
                } else {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
        }
    }

    /// 취침까지 남은 시간을 '1시간 23분' 처럼 쓴다. 타이머(.timer)는 '1:23:41' 같은 시계 숫자로 나와
    /// 시각으로 읽혔다. 취침이 지나면(앱이 활동을 끝내기 전 사이, staleDate 가 지난 뒤) 거꾸로 세지 않고 '수면 중'.
    @ViewBuilder
    private static func remaining(_ context: ActivityViewContext<BedtimeActivityAttributes>) -> some View {
        if context.isStale || context.state.bedtimeDate <= .now {
            Text("수면 중")
        } else {
            Text(context.state.bedtimeDate, style: .relative)
        }
    }

    // MARK: - Lock Screen
    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<BedtimeActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            // 미니 양피지 연소 시각화
            if context.state.showMiniParchment {
                MiniParchmentView(progress: context.state.progress)
                    .frame(width: 40, height: 52)
            } else {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                    .frame(width: 40, height: 52)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("취침까지")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange.opacity(0.7))

                Self.remaining(context)
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: geo.size.width * (1.0 - context.state.progress), height: 3)
                    }
                }
                .frame(height: 3)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow.opacity(0.6))
                Text(context.attributes.bedtimeString)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.8))
    }
}
