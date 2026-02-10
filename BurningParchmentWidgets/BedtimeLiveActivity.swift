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
                    VStack(spacing: 4) {
                        Text(timerInterval: Date()...context.state.bedtimeDate, countsDown: true)
                            .font(.system(size: 28, weight: .light, design: .monospaced))
                            .foregroundColor(.orange)
                            .monospacedDigit()

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
                        .padding(.horizontal, 24)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("🔥 \(Int((1.0 - context.state.progress) * 100))% 남음")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("취침 \(context.attributes.bedtimeString)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }

            } compactLeading: {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)

            } compactTrailing: {
                Text(timerInterval: Date()...context.state.bedtimeDate, countsDown: true)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.orange)
                    .monospacedDigit()
                    .frame(width: 52)

            } minimal: {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Lock Screen
    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<BedtimeActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            // 미니 불꽃 아이콘
            Image(systemName: "flame.fill")
                .font(.system(size: 24))
                .foregroundStyle(
                    LinearGradient(colors: [.yellow, .orange, .red], startPoint: .bottom, endPoint: .top)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("취침까지")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange.opacity(0.7))

                Text(timerInterval: Date()...context.state.bedtimeDate, countsDown: true)
                    .font(.system(size: 24, weight: .light, design: .monospaced))
                    .foregroundColor(.white)
                    .monospacedDigit()

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
