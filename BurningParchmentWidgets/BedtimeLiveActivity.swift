// BedtimeLiveActivity.swift
// 다이나믹 아일랜드 & 잠금화면 Live Activity 위젯

import SwiftUI
import WidgetKit
import ActivityKit

struct BedtimeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BedtimeActivityAttributes.self) { context in
            // 잠금 화면 Live Activity
            lockScreenView(context: context)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // ── Expanded ──
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                        
                        Text("취침까지")
                            .font(.system(size: 11))
                            .foregroundColor(.orange.opacity(0.7))
                    }
                    .padding(.leading, 4)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.yellow.opacity(0.6))
                        
                        Text(context.attributes.bedtimeString)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing, 4)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 6) {
                        // 남은 시간
                        Text(context.state.remainingTimeString)
                            .font(.system(size: 32, weight: .light, design: .serif))
                            .foregroundColor(.orange)
                            .monospacedDigit()
                        
                        // 진행 바 (양피지 소진)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        LinearGradient(
                                            colors: [.orange, .red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * context.state.progress, height: 4)
                            }
                        }
                        .frame(height: 4)
                        .padding(.horizontal, 20)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("🔥 양피지 \(Int((1.0 - context.state.progress) * 100))% 남음")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 4)
                }
                
            } compactLeading: {
                // ── Compact Leading (양피지 아이콘) ──
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                
            } compactTrailing: {
                // ── Compact Trailing (남은 시간) ──
                Text(context.state.shortTimeString)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundColor(.orange)
                    .monospacedDigit()
                
            } minimal: {
                // ── Minimal (아이콘만) ──
                Image(systemName: "flame.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - Lock Screen View
    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<BedtimeActivityAttributes>) -> some View {
        HStack(spacing: 16) {
            // 양피지 미니 프리뷰
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.82, green: 0.72, blue: 0.55),
                                Color(red: 0.65, green: 0.52, blue: 0.36),
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 50, height: 65)
                
                // 타는 효과 (위에서부터)
                VStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .frame(height: 65 * context.state.progress)
                    Spacer(minLength: 0)
                }
                .frame(width: 50, height: 65)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // 불꽃 라인
                if context.state.progress > 0 && context.state.progress < 1 {
                    VStack {
                        Spacer()
                            .frame(height: 65 * context.state.progress - 3)
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.yellow, .orange, .red],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 6)
                            .blur(radius: 2)
                        Spacer(minLength: 0)
                    }
                    .frame(width: 50, height: 65)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("취침까지 남은 시간")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange.opacity(0.7))
                
                Text(context.state.remainingTimeString)
                    .font(.system(size: 28, weight: .light, design: .serif))
                    .foregroundColor(.white)
                    .monospacedDigit()
                
                // 진행바
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * context.state.progress, height: 4)
                    }
                }
                .frame(height: 4)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.yellow.opacity(0.6))
                
                Text(context.attributes.bedtimeString)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.8))
    }
}
