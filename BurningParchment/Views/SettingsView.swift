// SettingsView.swift
// 설정 — 시간 · 페이지 · 화면 · 양피지와 불꽃 · 프로 · 지원.
// 묶음은 모두 같은 카드(SettingsGroup)와 같은 행(SettingsRow)으로 그린다 (IndicatorSettingsPage.swift).
// 시간은 [완료]를 눌러야 저장되고, 나머지는 고르는 즉시 반영된다.

import SwiftUI
import LeeoKit

struct SettingsView: View {
    @EnvironmentObject var bedtimeManager: BedtimeManager
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    @State private var restoreMessage: String?
    @State private var showThemePaywall = false
    @State private var showOfferCode = false
    @State private var showOnboarding = false
    @State private var showWhatsNew = false
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @AppStorage(ParchmentStyle.storageKey) private var parchmentStyleRaw = ParchmentStyle.classic.rawValue
    @Environment(\.parchmentStyle) private var currentStyle
    @AppStorage(FlameKind.storageKey) private var flameKindRaw = FlameKind.classic.rawValue
    @AppStorage(FlameSize.storageKey) private var flameSizeRaw = FlameSize.small.rawValue
    @Environment(\.flameKind) private var currentFlameKind
    @State private var selBedH: Int = 23
    @State private var selBedM: Int = 0
    @State private var selWakeH: Int = 7
    @State private var selWakeM: Int = 0

    /// 펼쳐 둔 시간 휠 (한 번에 하나)
    private enum TimeField { case wake, bed }
    @State private var expandedTime: TimeField?

    @AppStorage(AppTheme.storageKey) private var appThemeRaw = AppTheme.system.rawValue
    @AppStorage(SleepHealth.connectedKey) private var sleepHealthConnected = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ScaledMetric private var rowFontSize: CGFloat = 15

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    timeGroup
                    pageGroup
                    liveActivityGroup
                    if NightManager.isEnabled && SleepHealth.isAvailable { sleepRecordGroup }
                    appearanceGroup
                    flameSizeGroup
                    parchmentGroup
                    proGroup
                    supportGroup
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.appBackgroundWarm.ignoresSafeArea())
            .navigationTitle("설정")
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
                    .foregroundColor(.ember)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.inkMuted)
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
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeManager)
        }
        .sheet(isPresented: $showThemePaywall) {
            PaywallView(reason: .theme)
                .environmentObject(storeManager)
        }
        .offerCodeRedemption(isPresented: $showOfferCode) { result in
            // 코드가 받아지면 거래 리스너(LeeoStore)가 프로를 연다. 실패만 알린다.
            if case .failure(let error) = result {
                AppLog.lifecycle.error("프로모션 코드 사용 실패: \(error.localizedDescription, privacy: .public)")
                restoreMessage = String(localized: "코드를 사용하지 못했어요. 잠시 뒤 다시 시도해 주세요.")
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            BurningOnboardingView { showOnboarding = false }
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView { showWhatsNew = false }
                .presentationDragIndicator(.visible)
        }
        .alert("구매 복원",
               isPresented: Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
    }

    // MARK: - 시간

    private var timeGroup: some View {
        SettingsGroup(title: String(localized: "시간"),
                      footer: String(localized: "기상 시간부터 취침 시간까지 양피지가 서서히 타들어가요")) {
            timeRow(.wake, icon: "sunrise", title: String(localized: "기상 시간"), hour: $selWakeH, minute: $selWakeM)
            SettingsDivider()
            timeRow(.bed, icon: "moon", title: String(localized: "취침 시간"), hour: $selBedH, minute: $selBedM)
            if expandedTime == .bed { bedPresets }
        }
    }

    private func timeRow(_ field: TimeField, icon: String, title: String,
                         hour: Binding<Int>, minute: Binding<Int>) -> some View {
        let open = expandedTime == field
        return VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy) { expandedTime = open ? nil : field }
            } label: {
                SettingsRow(icon: icon, title: title) {
                    Text(TimeFormat.short(hour: hour.wrappedValue, minute: minute.wrappedValue))
                        .font(.system(size: rowFontSize, weight: .medium).monospacedDigit())
                        .foregroundColor(open ? .onEmber : .ember)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(open ? Color.ember : Color.ember.opacity(0.12)))
                }
            }
            .buttonStyle(.plain)
            .accessibilityValue(TimeFormat.short(hour: hour.wrappedValue, minute: minute.wrappedValue))
            .accessibilityHint(open ? Text("탭하여 닫기") : Text("탭하여 시간 바꾸기"))

            if open { timeWheel(hour: hour, minute: minute) }
        }
    }

    private func timeWheel(hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 0) {
            Picker("시", selection: hour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(TimeFormat.hourLabel(h)).tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 140)

            Text(":")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.inkMuted.opacity(0.6))

            Picker("분", selection: minute) {
                ForEach(0..<12, id: \.self) { idx in
                    Text(String(format: "%02d", idx * 5)).tag(idx * 5)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 100)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .clipped()
    }

    /// 취침 시간을 펼쳤을 때만 보이는 추천 시각
    private var bedPresets: some View {
        let presets: [(Int, Int)] = [(22, 0), (22, 30), (23, 0), (23, 30), (0, 0), (0, 30), (1, 0)]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presets.indices, id: \.self) { i in
                    presetButton(hour: presets[i].0, minute: presets[i].1)
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 12)
    }

    private func presetButton(hour: Int, minute: Int) -> some View {
        let isSelected = selBedH == hour && selBedM == minute
        let h12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        let ampm = hour >= 12 ? String(localized: "오후") : String(localized: "오전")
        let minStr = minute > 0 ? String(localized: " \(minute)분") : ""
        return Button {
            selBedH = hour
            selBedM = minute
        } label: {
            Text(TimeFormat.short(hour: hour, minute: minute))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .onEmber : .ember.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(isSelected ? Color.ember : Color.ember.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("취침 시간 \(ampm) \(h12)시\(minStr)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - 페이지

    private let standardPeriods: [PeriodType] = [.day, .week, .freeTime, .month, .year]

    private var pageGroup: some View {
        let visibleCount = standardPeriods.filter { !bedtimeManager.hiddenPeriods.contains($0.rawValue) }.count
        return SettingsGroup(title: String(localized: "페이지"),
                             footer: String(localized: "자유시간은 페이지 표시에서 모래시계로 보여요. 데드라인은 추가하면 저절로 나타나요")) {
            ForEach(standardPeriods) { period in
                let isVisible = !bedtimeManager.hiddenPeriods.contains(period.rawValue)
                SettingsRow(icon: periodIcon(period), title: period.displayName) {
                    Toggle("", isOn: Binding(
                        get: { isVisible },
                        set: { newValue in
                            if newValue {
                                bedtimeManager.hiddenPeriods.remove(period.rawValue)
                            } else if visibleCount > 1 {
                                bedtimeManager.hiddenPeriods.insert(period.rawValue)
                            }
                        }))
                    .labelsHidden()
                    .tint(.ember)
                }
                SettingsDivider()
            }

            NavigationLink {
                IndicatorSettingsPage()
                    .environmentObject(bedtimeManager)
            } label: {
                SettingsRow(icon: "ellipsis", title: String(localized: "페이지 표시 모양")) {
                    indicatorSummary
                    SettingsChevron()
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func periodIcon(_ period: PeriodType) -> String {
        switch period {
        case .day:      return "sun.max"
        case .week:     return "calendar"
        case .freeTime: return "hourglass"
        case .month:    return "calendar.circle"
        case .year:     return "leaf"
        case .deadline: return "flag"
        }
    }

    @ViewBuilder
    private var indicatorSummary: some View {
        if !bedtimeManager.indicatorVisible {
            Text("끔")
                .font(.system(size: 14))
                .foregroundColor(.inkMuted.opacity(0.6))
        } else if !bedtimeManager.indicatorSymbol.isEmpty {
            Image(systemName: bedtimeManager.indicatorSymbol)
                .font(.system(size: 12))
                .foregroundColor(.ember)
        } else {
            IndicatorSettingsPage.preview(for: bedtimeManager.indicatorShape)
        }
    }

    // MARK: - 수면 기록 (건강 앱)
    // 취침 이후 타는 내일의 양피지는 아침에 잠든 시각이 확인된 만큼만 그을린다.
    // 건강 앱을 연결하면 그 확인을 묻지 않고 기록으로 한다.

    private var sleepRecordGroup: some View {
        SettingsGroup(title: String(localized: "수면 기록"),
                      footer: sleepHealthConnected
                        ? String(localized: "연결을 끊으려면 iOS 설정 ▸ 건강 ▸ 데이터 접근 및 기기에서 바꿀 수 있어요. 수면 기록은 읽기만 하고 기기 밖으로 보내지 않아요")
                        : String(localized: "연결하면 아침마다 잠든 시각을 묻지 않고, 기록된 시각으로 내일의 양피지를 되돌려요. 수면 기록은 읽기만 하고 기기 밖으로 보내지 않아요")) {
            if sleepHealthConnected {
                SettingsRow(icon: "bed.double", title: String(localized: "건강 앱 수면 기록")) {
                    Label("연결됨", systemImage: "checkmark.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.ember)
                }
            } else {
                Button {
                    Task { sleepHealthConnected = await SleepHealth.connect() }
                } label: {
                    SettingsRow(icon: "bed.double", title: String(localized: "건강 앱 수면 기록 연결하기")) {
                        SettingsChevron()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 화면

    private var appearanceGroup: some View {
        SettingsGroup(title: String(localized: "화면 테마"),
                      footer: String(localized: "시스템 설정을 고르면 기기의 다크 모드를 그대로 따라갑니다")) {
            Picker("화면 테마", selection: $appThemeRaw) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.label).tag(theme.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)
        }
    }

    // MARK: - 다이나믹 아일랜드

    private var liveActivityGroup: some View {
        SettingsGroup(title: String(localized: "다이나믹 아일랜드"),
                      footer: String(localized: "잠들기 전을 고르면 취침 1시간 전부터 잠금화면과 다이나믹 아일랜드에 남은 시간이 보여요. 다이나믹 아일랜드를 누르면 앱이 열려요")) {
            SettingsRow(icon: "capsule", title: String(localized: "다이나믹 아일랜드")) {
                Toggle("", isOn: Binding(
                    get: { bedtimeManager.liveActivityMode != .off },
                    set: { bedtimeManager.liveActivityMode = $0 ? .beforeBed : .off }))
                .labelsHidden()
                .tint(.ember)
            }
            if bedtimeManager.liveActivityMode != .off {
                SettingsDivider()
                Picker("다이나믹 아일랜드", selection: $bedtimeManager.liveActivityMode) {
                    ForEach(LiveActivityMode.allCases.filter { $0 != .off }) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(12)
            }
        }
    }

    // MARK: - 불꽃 크기

    private var flameSizeGroup: some View {
        SettingsGroup(title: String(localized: "불꽃 크기"),
                      footer: String(localized: "양피지를 태우는 불꽃이 솟는 높이예요")) {
            Picker("불꽃 크기", selection: $flameSizeRaw) {
                ForEach(FlameSize.allCases) { size in
                    Text(size.label).tag(size.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)
        }
    }

    // MARK: - 양피지와 불꽃 (프로)

    private var parchmentGroup: some View {
        SettingsGroup(title: String(localized: "양피지와 불꽃"),
                      badge: storeManager.isPro ? nil : String(localized: "프로"),
                      footer: String(localized: "빛깔은 종이 색과 불꽃 색을, 불꽃 종류는 어떤 불로 탈지를 정해요. 둘은 따로 고를 수 있어요")) {
            VStack(alignment: .leading, spacing: 10) {
                subheading(String(localized: "빛깔"))
                HStack(spacing: 8) {
                    ForEach(ParchmentStyle.allCases) { style in
                        styleTile(style)
                    }
                }
            }
            .padding(14)

            Divider().background(Color.ink.opacity(0.06))

            VStack(alignment: .leading, spacing: 4) {
                subheading(String(localized: "불꽃 종류"))
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                FlameKindPicker(current: currentFlameKind, style: currentStyle, isPro: storeManager.isPro) { kind in
                    if kind.isPro && !storeManager.isPro {
                        showThemePaywall = true
                    } else {
                        flameKindRaw = kind.rawValue
                    }
                }
                .padding(.bottom, 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func subheading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.inkMuted.opacity(0.7))
    }

    private func styleTile(_ style: ParchmentStyle) -> some View {
        let isSelected = currentStyle == style
        let locked = style.isPro && !storeManager.isPro
        return Button {
            if locked {
                showThemePaywall = true
            } else {
                parchmentStyleRaw = style.rawValue
            }
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(style.paperGradient)
                    .frame(height: 44)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(LinearGradient(colors: [.yellow, .orange, .red],
                                                            startPoint: .top, endPoint: .bottom))
                            .flameTint(style)
                            .padding(5)
                    }
                    .overlay(alignment: .topLeading) {
                        if locked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.black.opacity(0.45))
                                .padding(5)
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.ember : Color.clear, lineWidth: 2))
                    .overlay(alignment: .topTrailing) {
                        // 색을 구별하기 어려우면 테두리 색만으로는 고른 것을 알 수 없다 — 표시를 더한다
                        if isSelected && differentiateWithoutColor {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.onEmber, Color.ember)
                                .padding(4)
                                .accessibilityHidden(true)
                        }
                    }
                Text(style.label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .ember : .inkMuted.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.label)
        .accessibilityValue(locked ? String(localized: "프로에서 열려요") : "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - 프로

    private var proGroup: some View {
        SettingsGroup(title: String(localized: "프로"),
                      footer: storeManager.isPro ? nil
                        : String(localized: "불타는 자유시간, 빛깔과 불꽃 종류, 조각 카드, 회고 책 PDF, 한 해의 재 흐름, 데드라인 무제한을 이용해보세요.")) {
            if storeManager.isPro {
                SettingsRow(icon: "checkmark.seal", title: String(localized: "프로 이용 중이에요. 감사합니다 🔥"))
            } else {
                Button { showPaywall = true } label: {
                    SettingsRow(icon: "sparkles", title: String(localized: "프로로 업그레이드")) {
                        SettingsChevron()
                    }
                }
                .buttonStyle(.plain)

                SettingsDivider()

                Button {
                    Task {
                        let restored = await storeManager.restorePurchases()
                        if !restored {
                            restoreMessage = storeManager.lastError
                                ?? String(localized: "이 Apple 계정으로 프로를 산 기록을 찾지 못했어요. 구매할 때 쓴 계정으로 로그인했는지 확인해주세요.")
                        }
                    }
                } label: {
                    SettingsRow(icon: "arrow.clockwise", title: String(localized: "구매 복원")) {
                        if storeManager.purchaseInProgress { ProgressView() }
                    }
                }
                .buttonStyle(.plain)
                .disabled(storeManager.purchaseInProgress)

                SettingsDivider()

                Button { showOfferCode = true } label: {
                    SettingsRow(icon: "ticket", title: String(localized: "프로모션 코드 사용")) {
                        SettingsChevron()
                    }
                }
                .buttonStyle(.plain)
            }

            // 프로 선물하기 · 선물 코드 넣기 — 프로 카드 안, 맨 아래 (→ GiftRows).
            if let gift = storeManager.gift {
                GiftRows(gift: gift, isPro: storeManager.isPro)
            }

            // 개발자 응원하기(팁) — 선물 바로 아래. 판매 중인 팁이 있어야 선다(문구는 LeeoKit 카탈로그).
            // 아래 지원 카드의 LeeoKit 행과 같은 모양을 입힌다.
            if let tipJar = storeManager.tipJar {
                LeeoTipJarLink<BurningParchmentSpec>(tipJar: tipJar)
                    .labelStyle(SettingsLabelStyle())
                    .font(.system(size: rowFontSize))
                    .foregroundStyle(Color.inkMuted.opacity(0.8))
                    .tint(.ember)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .contentShape(Rectangle())
                    .overlay(alignment: .top) { SettingsDivider() }
            }
        }
    }

    // MARK: - 지원 (문의 · 피드백 · 리뷰 · 정책 · 버전)

    private var supportGroup: some View {
        SettingsGroup(title: String(localized: "지원"),
                      footer: String(localized: "버그 제보와 기능 제안을 환영합니다.")) {
            contactRow(title: String(localized: "이메일로 문의하기"), icon: "envelope", url: "mailto:leeo@kakao.com")
            SettingsDivider()
            contactRow(title: String(localized: "인스타그램 DM (@lee25_ios)"), icon: "paperplane",
                       url: "https://instagram.com/lee25_ios")
            SettingsDivider()
            Button { showWhatsNew = true } label: {
                SettingsRow(icon: "sparkles", title: String(localized: "새로 생긴 것")) {
                    SettingsChevron()
                }
            }
            .buttonStyle(.plain)
            SettingsDivider()
            Button { showOnboarding = true } label: {
                SettingsRow(icon: "questionmark.circle", title: String(localized: "처음 안내 다시 보기")) {
                    SettingsChevron()
                }
            }
            .buttonStyle(.plain)
            SettingsDivider()
            // 앞으로 만들 것 — 원본은 BurningParchmentRoadmap.swift.
            NavigationLink {
                RoadmapScreen()
            } label: {
                SettingsRow(icon: "map", title: LeeoRoadmapText.entry) {
                    SettingsChevron()
                }
            }
            .buttonStyle(.plain)

            // 같은 개발자가 만든 다른 앱 — 목록과 소개 글은 LeeoKit(LeeoFamilyCatalog)에 있다
            LeeoFamilySettingsRow<BurningParchmentSpec>()
                .labelStyle(SettingsLabelStyle())
                .font(.system(size: rowFontSize))
                .foregroundStyle(Color.inkMuted.opacity(0.8))
                .tint(.ember)
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .contentShape(Rectangle())
                .overlay(alignment: .top) { SettingsDivider() }

            // LeeoKit 의 행들(피드백·리뷰·정책 링크·버전)은 Form 용이라 테두리가 없다.
            // 행마다 같은 높이와 위쪽 구분선을 입혀 위의 행들과 맞춘다.
            LeeoSupportSection<BurningParchmentSpec>()
                .labelStyle(SettingsLabelStyle())
                .font(.system(size: rowFontSize))
                .foregroundStyle(Color.inkMuted.opacity(0.8))
                .tint(.ember)
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .contentShape(Rectangle())
                .overlay(alignment: .top) { SettingsDivider() }
        }
    }

    @ViewBuilder
    private func contactRow(title: String, icon: String, url: String) -> some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                SettingsRow(icon: icon, title: title) {
                    SettingsChevron(external: true)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 선물

/// 설정 ▸ 프로 카드의 **선물** 줄.
///
/// - 보내기: 프로를 다른 사람에게 보낸다(보내는 사람은 소모성 선물 상품을 산다).
/// - 받기: 받은 코드를 넣는다. 받는 사람은 프로(`StoreManager.proProductID`)를 산 것과 같아진다.
///
/// ⚠️ 상품이 App Store 에서 와야 줄이 선다(`isAvailable`). App Store Connect 에 상품을 만들기 전에
///    이 빌드가 나가도 눌러도 안 되는 줄은 보이지 않는다. 단, 이미 결제했거나 주고받은 선물이 있는
///    사람에게는 늘 보인다 — 상품을 못 불러온 날에도 코드를 다시 보거나 문의까지 갈 길이 있어야 한다.
/// ⚠️ 문구는 LeeoKit 카탈로그(`LeeoGiftText`)에 있다 — 24개 언어가 이미 들어 있다.
/// ⚠️ 엔진(`LeeoGiftStore`)은 따로 관찰해야 한다. 상품은 앱이 뜬 뒤에 오는데 `StoreManager` 는
///    그 변화를 알리지 않는다.
private struct GiftRows: View {
    @ObservedObject var gift: LeeoGiftStore
    let isPro: Bool
    @State private var showSupport = false

    var body: some View {
        if gift.isAvailable || gift.pendingCount > 0 || !gift.sentGifts.isEmpty || gift.redeemed != nil {
            // 카드 안의 다른 줄과 같은 간격(0)으로 쌓는다.
            VStack(spacing: 0) {
                SettingsDivider()
                NavigationLink {
                    // 선물이 안 되면 결제 번호·코드를 붙여 문의하게 한다 — 막힌 사람을 놓치지 않게.
                    LeeoGiftView<BurningParchmentSpec>(gift: gift, showsRedeemLink: false,
                                                       onContactSupport: { showSupport = true })
                } label: {
                    SettingsRow(icon: "gift.fill", title: LeeoGiftText.sendEntry) {
                        SettingsChevron()
                    }
                }
                .buttonStyle(.plain)
                // 이미 프로인 사람은 받을 것이 없다 — 받은 적이 있으면 그 기록을 볼 수 있게만 남긴다.
                if !isPro || gift.redeemed != nil {
                    SettingsDivider()
                    NavigationLink {
                        LeeoGiftRedeemView<BurningParchmentSpec>(gift: gift,
                                                                 onContactSupport: { showSupport = true })
                    } label: {
                        SettingsRow(icon: "giftcard", title: LeeoGiftText.redeemEntry) {
                            SettingsChevron()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showSupport) {
                NavigationStack {
                    LeeoFeedbackView<BurningParchmentSpec>(initialType: .bug, extraInfo: gift.supportLines,
                                                           initialCategory: .purchase)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(BedtimeManager())
        .environmentObject(StoreManager())
}
