// IndicatorSettingsPage.swift
// 설정 ▸ 페이지 ▸ 페이지 표시 모양.
// 메인 설정이 한 화면에 다 펼쳐 놓지 않도록 도형·심볼 고르기는 이 하위 페이지에 둔다.

import SwiftUI

struct IndicatorSettingsPage: View {
    @EnvironmentObject var bedtimeManager: BedtimeManager

    static let symbolOptions: [(name: String, label: String)] = [
        ("circle.fill",   String(localized: "원")),
        ("flame.fill",    String(localized: "불꽃")),
        ("star.fill",     String(localized: "별")),
        ("heart.fill",    String(localized: "하트")),
        ("moon.fill",     String(localized: "달")),
        ("sun.max.fill",  String(localized: "해")),
        ("bolt.fill",     String(localized: "번개")),
        ("leaf.fill",     String(localized: "잎")),
        ("drop.fill",     String(localized: "방울")),
        ("sparkle",       String(localized: "반짝")),
    ]

    private var isSymbolMode: Bool { !bedtimeManager.indicatorSymbol.isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsGroup {
                    SettingsRow(icon: "eye", title: String(localized: "페이지 표시")) {
                        Toggle("", isOn: $bedtimeManager.indicatorVisible)
                            .labelsHidden()
                            .tint(.ember)
                    }
                }

                SettingsGroup(title: String(localized: "모양")) {
                    VStack(spacing: 14) {
                        Picker("", selection: Binding(
                            get: { isSymbolMode },
                            set: { symbol in
                                if symbol {
                                    if bedtimeManager.indicatorSymbol.isEmpty {
                                        bedtimeManager.indicatorSymbol = Self.symbolOptions[0].name
                                    }
                                } else {
                                    bedtimeManager.indicatorSymbol = ""
                                }
                            })) {
                            Text("도형").tag(false)
                            Text("심볼").tag(true)
                        }
                        .pickerStyle(.segmented)

                        if isSymbolMode { symbolGrid } else { shapeGrid }
                    }
                    .padding(14)
                }
                .opacity(bedtimeManager.indicatorVisible ? 1 : 0.35)
                .disabled(!bedtimeManager.indicatorVisible)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.appBackgroundWarm.ignoresSafeArea())
        .navigationTitle("페이지 표시")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var shapeGrid: some View {
        HStack(spacing: 8) {
            ForEach(IndicatorShape.allCases) { shape in
                choice(isSelected: bedtimeManager.indicatorShape == shape, label: shape.label) {
                    Self.preview(for: shape).frame(height: 20)
                } action: {
                    bedtimeManager.indicatorShape = shape
                }
            }
        }
    }

    private var symbolGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
            ForEach(Self.symbolOptions, id: \.name) { opt in
                let isSelected = bedtimeManager.indicatorSymbol == opt.name
                choice(isSelected: isSelected, label: opt.label) {
                    Image(systemName: opt.name)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .ember : .inkMuted.opacity(0.5))
                        .frame(height: 20)
                } action: {
                    bedtimeManager.indicatorSymbol = opt.name
                }
            }
        }
    }

    private func choice<Content: View>(isSelected: Bool, label: String,
                                       @ViewBuilder content: () -> Content,
                                       action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                content()
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .ember : .inkMuted.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.ember.opacity(0.12) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.ember.opacity(0.45) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// 도형 미리보기 — 설정 첫 화면의 행에서도 지금 모양을 보여 주는 데 쓴다
    @ViewBuilder
    static func preview(for shape: IndicatorShape) -> some View {
        let on = Color.ember, off = Color.inkMuted.opacity(0.3)
        switch shape {
        case .dot:
            HStack(spacing: 4) {
                Circle().fill(on).frame(width: 8, height: 8)
                Circle().fill(off).frame(width: 6, height: 6)
                Circle().fill(off).frame(width: 6, height: 6)
            }
        case .pill:
            HStack(spacing: 4) {
                Capsule().fill(on).frame(width: 18, height: 7)
                Circle().fill(off).frame(width: 7, height: 7)
                Circle().fill(off).frame(width: 7, height: 7)
            }
        case .line:
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 2).fill(on).frame(width: 16, height: 3)
                RoundedRectangle(cornerRadius: 2).fill(off).frame(width: 6, height: 3)
                RoundedRectangle(cornerRadius: 2).fill(off).frame(width: 6, height: 3)
            }
        case .bar:
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 3).fill(on).frame(width: 12, height: 5)
                RoundedRectangle(cornerRadius: 3).fill(off).frame(width: 12, height: 5)
                RoundedRectangle(cornerRadius: 3).fill(off).frame(width: 12, height: 5)
            }
        }
    }
}

// MARK: - 설정 공통 부품
// 모든 묶음이 같은 카드·같은 행 모양을 쓴다. 주황은 아이콘과 고른 값에만 쓴다.

struct SettingsGroup<Content: View>: View {
    var title: String? = nil
    var badge: String? = nil
    var footer: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.inkMuted.opacity(0.75))
                    if let badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.onEmber)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.ember.opacity(0.85)))
                    }
                }
                .padding(.leading, 6)
                .accessibilityAddTraits(.isHeader)
            }

            VStack(spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.ink.opacity(0.045)))

            if let footer {
                Text(footer)
                    .font(.system(size: 12))
                    .foregroundColor(.inkMuted.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }
        }
    }
}

/// 아이콘 · 제목 · (오른쪽 값이나 스위치). 행 사이 구분선은 SettingsDivider.
struct SettingsRow<Trailing: View>: View {
    let icon: String
    let title: String
    @ViewBuilder var trailing: Trailing
    @ScaledMetric private var fontSize: CGFloat = 15

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: fontSize - 1))
                .foregroundColor(.ember.opacity(0.75))
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: fontSize))
                .foregroundColor(.ink.opacity(0.88))
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(icon: String, title: String) {
        self.init(icon: icon, title: title) { EmptyView() }
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider().background(Color.ink.opacity(0.06)).padding(.leading, 48)
    }
}

/// 다음 화면으로 넘어가거나 밖으로 나가는 행의 꼬리
struct SettingsChevron: View {
    var external = false
    var body: some View {
        Image(systemName: external ? "arrow.up.right" : "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.inkMuted.opacity(0.4))
    }
}

/// LeeoKit 지원 행(Label)을 SettingsRow 와 같은 아이콘 칸·색으로 맞춘다
struct SettingsLabelStyle: LabelStyle {
    @ScaledMetric private var fontSize: CGFloat = 15

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
                .font(.system(size: fontSize - 1))
                .foregroundStyle(Color.ember.opacity(0.75))
                .frame(width: 22)
            configuration.title
                .font(.system(size: fontSize))
                .foregroundStyle(Color.ink.opacity(0.88))
        }
    }
}
