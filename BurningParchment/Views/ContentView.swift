// ContentView.swift
// 메인 화면

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bedtimeManager: BedtimeManager
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                BurningParchmentView()
                    .environmentObject(bedtimeManager)
                bottomInfo
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(bedtimeManager)
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("취침 \(bedtimeManager.bedtimeString)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.orange.opacity(0.7))
                Text("기상 \(bedtimeManager.wakeTimeString)")
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.6))
            }

            Spacer()

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange.opacity(0.6))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Bottom Info
    private var bottomInfo: some View {
        VStack(spacing: 8) {
            if bedtimeManager.isBeforeWakeTime {
                Text("기상시간부터 카운트다운이 시작됩니다")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange.opacity(0.5))
            } else if bedtimeManager.isCountdownActive {
                Button(action: startLiveActivity) {
                    HStack(spacing: 6) {
                        Image(systemName: "island.fill")
                            .font(.system(size: 14))
                        Text("다이나믹 아일랜드에 표시")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                            .overlay(Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 1))
                    )
                }
            } else {
                Text("🌙 좋은 꿈 꾸세요")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.orange.opacity(0.7))
            }
        }
        .padding(.bottom, 16)
    }

    private func startLiveActivity() {
        if #available(iOS 16.2, *) {
            bedtimeManager.startLiveActivity()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(BedtimeManager())
}
