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

    @ScaledMetric private var headerIconSize: CGFloat = 44
    @ScaledMetric private var sectionIconSize: CGFloat = 14
    @ScaledMetric private var rowFontSize: CGFloat = 15
    @ScaledMetric private var captionFontSize: CGFloat = 11

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

                        // 탭 표시 설정
                        tabVisibilitySection

                        // 인디케이터 설정
                        indicatorSection

                        // 개발자 문의
                        developerContactSection

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
                        bedtimeManager.updateSettings(
                            wakeHour: selWakeH, wakeMinute: selWakeM,
                            bedHour: selBedH, bedMinute: selBedM
                        )
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
        .dynamicTypeSize(.small...(.accessibility2))
        .onAppear {
            selBedH = bedtimeManager.bedtimeHour
            selBedM = bedtimeManager.bedtimeMinute
            selWakeH = bedtimeManager.wakeHour
            selWakeM = bedtimeManager.wakeMinute
        }
    }

    // MARK: - Tab Visibility Section

    private let standardPeriods: [PeriodType] = [.day, .week, .month, .year]

    private var tabVisibilitySection: some View {
        let visibleCount = standardPeriods.filter { !bedtimeManager.hiddenPeriods.contains($0.rawValue) }.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2")
                    .foregroundColor(.orange.opacity(0.6))
                Text("탭 표시")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange.opacity(0.5))
            }

            VStack(spacing: 0) {
                ForEach(standardPeriods) { period in
                    let isVisible = !bedtimeManager.hiddenPeriods.contains(period.rawValue)

                    HStack {
                        Text(period.rawValue)
                            .font(.system(size: 15, design: .serif))
                            .foregroundColor(isVisible ? .orange.opacity(0.85) : .gray.opacity(0.4))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { isVisible },
                            set: { newValue in
                                if newValue {
                                    bedtimeManager.hiddenPeriods.remove(period.rawValue)
                                } else if visibleCount > 1 {
                                    bedtimeManager.hiddenPeriods.insert(period.rawValue)
                                }
                            }
                        ))
                        .tint(.orange)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if period != standardPeriods.last {
                        Divider().background(Color.orange.opacity(0.08))
                            .padding(.leading, 14)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.1), lineWidth: 1))
            )

            Text("데드라인 탭은 데드라인 추가 시 자동으로 표시됩니다")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.4))
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Indicator Section

    private let symbolOptions: [(name: String, label: String)] = [
        ("circle.fill",   "원"),
        ("flame.fill",    "불꽃"),
        ("star.fill",     "별"),
        ("heart.fill",    "하트"),
        ("moon.fill",     "달"),
        ("sun.max.fill",  "해"),
        ("bolt.fill",     "번개"),
        ("leaf.fill",     "잎"),
        ("drop.fill",     "방울"),
        ("sparkle",       "반짝"),
    ]

    private var isSymbolMode: Bool { !bedtimeManager.indicatorSymbol.isEmpty }

    private var indicatorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "circle.grid.3x3")
                    .foregroundColor(.orange.opacity(0.6))
                Text("페이지 인디케이터")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange.opacity(0.5))
            }

            VStack(spacing: 0) {
                // 표시 여부
                HStack {
                    Text("표시")
                        .font(.system(size: 15, design: .serif))
                        .foregroundColor(bedtimeManager.indicatorVisible ? .orange.opacity(0.85) : .gray.opacity(0.4))
                    Spacer()
                    Toggle("", isOn: $bedtimeManager.indicatorVisible)
                        .tint(.orange)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Divider().background(Color.orange.opacity(0.08)).padding(.leading, 14)

                // 모드 선택 (도형 / 심볼)
                HStack(spacing: 0) {
                    modeTab(title: "도형", isSelected: !isSymbolMode) {
                        bedtimeManager.indicatorSymbol = ""
                    }
                    modeTab(title: "심볼", isSelected: isSymbolMode) {
                        if bedtimeManager.indicatorSymbol.isEmpty {
                            bedtimeManager.indicatorSymbol = symbolOptions[0].name
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)
                .opacity(bedtimeManager.indicatorVisible ? 1 : 0.3)
                .disabled(!bedtimeManager.indicatorVisible)

                if isSymbolMode {
                    // SF 심볼 그리드
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                        ForEach(symbolOptions, id: \.name) { opt in
                            let isSelected = bedtimeManager.indicatorSymbol == opt.name
                            Button {
                                bedtimeManager.indicatorSymbol = opt.name
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: opt.name)
                                        .font(.system(size: 20))
                                        .foregroundColor(isSelected ? .orange : .gray.opacity(0.45))
                                    Text(opt.label)
                                        .font(.system(size: 10))
                                        .foregroundColor(isSelected ? .orange : .gray.opacity(0.4))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isSelected ? Color.orange.opacity(0.12) : Color.white.opacity(0.03))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(isSelected ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .opacity(bedtimeManager.indicatorVisible ? 1 : 0.3)
                    .disabled(!bedtimeManager.indicatorVisible)
                } else {
                    // 도형 선택
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            ForEach(IndicatorShape.allCases) { shape in
                                Button {
                                    bedtimeManager.indicatorShape = shape
                                } label: {
                                    VStack(spacing: 8) {
                                        indicatorPreview(for: shape)
                                            .frame(height: 14)
                                        Text(shape.label)
                                            .font(.system(size: 11))
                                            .foregroundColor(
                                                bedtimeManager.indicatorShape == shape
                                                    ? .orange : .gray.opacity(0.4)
                                            )
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                bedtimeManager.indicatorShape == shape
                                                    ? Color.orange.opacity(0.12)
                                                    : Color.white.opacity(0.03)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(
                                                        bedtimeManager.indicatorShape == shape
                                                            ? Color.orange.opacity(0.4) : Color.clear,
                                                        lineWidth: 1
                                                    )
                                            )
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                        .opacity(bedtimeManager.indicatorVisible ? 1 : 0.3)
                        .disabled(!bedtimeManager.indicatorVisible)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.1), lineWidth: 1))
            )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 개발자 문의

    private var developerContactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "envelope")
                    .foregroundColor(.orange.opacity(0.6))
                Text("개발자에게 문의")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange.opacity(0.5))
            }

            VStack(spacing: 0) {
                contactRow(
                    title: "이메일로 문의하기",
                    icon: "envelope",
                    url: "mailto:leeo@kakao.com"
                )

                Divider().background(Color.orange.opacity(0.08))
                    .padding(.leading, 14)

                contactRow(
                    title: "인스타그램 DM (@lee25_ios)",
                    icon: "paperplane",
                    url: "https://instagram.com/lee25_ios"
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.1), lineWidth: 1))
            )

            Text("버그 제보와 기능 제안을 환영합니다.")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.4))
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func contactRow(title: String, icon: String, url: String) -> some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: sectionIconSize))
                        .foregroundColor(.orange.opacity(0.6))
                    Text(title)
                        .font(.system(size: rowFontSize, design: .serif))
                        .foregroundColor(.orange.opacity(0.85))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.4))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
    }

    private func modeTab(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .orange : .gray.opacity(0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isSelected ? Color.orange.opacity(0.12) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(isSelected ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                )
        }
    }

    @ViewBuilder
    private func indicatorPreview(for shape: IndicatorShape) -> some View {
        switch shape {
        case .dot:
            HStack(spacing: 4) {
                Circle().fill(Color.orange).frame(width: 8, height: 8)
                Circle().fill(Color.gray.opacity(0.3)).frame(width: 6, height: 6)
                Circle().fill(Color.gray.opacity(0.3)).frame(width: 6, height: 6)
            }
        case .pill:
            HStack(spacing: 4) {
                Capsule().fill(Color.orange).frame(width: 18, height: 7)
                Circle().fill(Color.gray.opacity(0.3)).frame(width: 7, height: 7)
                Circle().fill(Color.gray.opacity(0.3)).frame(width: 7, height: 7)
            }
        case .line:
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 2).fill(Color.orange).frame(width: 16, height: 3)
                RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.25)).frame(width: 6, height: 3)
                RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.25)).frame(width: 6, height: 3)
            }
        case .bar:
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 3).fill(Color.orange).frame(width: 12, height: 5)
                RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.25)).frame(width: 12, height: 5)
                RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.25)).frame(width: 12, height: 5)
            }
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
        let isSelected = selBedH == hour && selBedM == minute
        let h12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        let ampm = hour >= 12 ? "오후" : "오전"
        let minStr = minute > 0 ? " \(minute)분" : ""
        return Button {
            selBedH = hour
            selBedM = minute
        } label: {
            Text(label)
                .font(.system(size: captionFontSize, weight: .medium))
                .foregroundColor(isSelected ? .black : .orange.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Color.orange : Color.orange.opacity(0.1))
                )
        }
        .accessibilityLabel("취침 시간 \(ampm) \(h12)시\(minStr)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "선택됨" : "탭하여 선택")
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
