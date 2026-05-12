// SettingsView.swift
// 기상시간 + 취침시간 설정

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var bedtimeManager: BedtimeManager
    @Environment(\.dismiss) private var dismiss

    @State private var selBedH: Int = 23
    @State private var selBedM: Int = 0
    @State private var selWakeH: Int = 7
    @State private var selWakeM: Int = 0

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.06, blue: 0.04)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // 헤더
                        VStack(spacing: 10) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.orange.opacity(0.6))

                            Text("시간 설정")
                                .font(.system(size: 22, weight: .semibold, design: .serif))
                                .foregroundColor(.orange.opacity(0.8))

                            Text("기상시간부터 취침시간까지\n양피지가 서서히 타들어갑니다")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 16)

                        // 기상시간 피커
                        timePickerSection(
                            title: "기상 시간",
                            icon: "sunrise.fill",
                            hour: $selWakeH,
                            minute: $selWakeM
                        )

                        // 취침시간 피커
                        timePickerSection(
                            title: "취침 시간",
                            icon: "moon.fill",
                            hour: $selBedH,
                            minute: $selBedM
                        )

                        // 추천 취침 시간
                        VStack(alignment: .leading, spacing: 12) {
                            Text("추천 취침 시간")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray)

                            HStack(spacing: 10) {
                                presetButton(hour: 22, minute: 0, label: "10 PM")
                                presetButton(hour: 22, minute: 30, label: "10:30")
                                presetButton(hour: 23, minute: 0, label: "11 PM")
                                presetButton(hour: 23, minute: 30, label: "11:30")
                            }
                            HStack(spacing: 10) {
                                presetButton(hour: 0, minute: 0, label: "12 AM")
                                presetButton(hour: 0, minute: 30, label: "12:30")
                                presetButton(hour: 1, minute: 0, label: "1 AM")
                            }
                        }
                        .padding(.horizontal, 20)

                        // 안내
                        VStack(spacing: 8) {
                            Label("기상시간부터 자동 카운트다운", systemImage: "flame.fill")
                            Label("다이나믹 아일랜드로 실시간 확인", systemImage: "island.fill")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        bedtimeManager.wakeHour = selWakeH
                        bedtimeManager.wakeMinute = selWakeM
                        bedtimeManager.bedtimeHour = selBedH
                        bedtimeManager.bedtimeMinute = selBedM
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            selBedH = bedtimeManager.bedtimeHour
            selBedM = bedtimeManager.bedtimeMinute
            selWakeH = bedtimeManager.wakeHour
            selWakeM = bedtimeManager.wakeMinute
        }
    }

    // MARK: - Time Picker Section

    private func timePickerSection(title: String, icon: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.orange.opacity(0.6))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange.opacity(0.5))
            }

            HStack(spacing: 0) {
                Picker("시", selection: hour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(hourLabel(h))
                            .foregroundColor(.orange)
                            .tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 140)

                Text(":")
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(.orange.opacity(0.5))

                Picker("분", selection: minute) {
                    ForEach(0..<12, id: \.self) { idx in
                        Text(String(format: "%02d", idx * 5))
                            .foregroundColor(.orange)
                            .tag(idx * 5)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 100)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Preset Button

    private func presetButton(hour: Int, minute: Int, label: String) -> some View {
        Button {
            selBedH = hour
            selBedM = minute
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(
                    selBedH == hour && selBedM == minute ? .black : .orange.opacity(0.7)
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        selBedH == hour && selBedM == minute
                            ? Color.orange : Color.orange.opacity(0.1)
                    )
                )
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let h12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        let ampm = hour >= 12 ? "PM" : "AM"
        return "\(ampm) \(h12)"
    }
}

#Preview {
    SettingsView()
        .environmentObject(BedtimeManager())
}
