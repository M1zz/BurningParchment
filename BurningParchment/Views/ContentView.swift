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
                Text("불타는 내인생")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundColor(.orange.opacity(0.8))
                HStack(spacing: 8) {
                    Label(bedtimeManager.wakeTimeString, systemImage: "sunrise.fill")
                    Text("→")
                    Label(bedtimeManager.bedtimeString, systemImage: "moon.fill")
                }
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
}

#Preview {
    ContentView()
        .environmentObject(BedtimeManager())
}
