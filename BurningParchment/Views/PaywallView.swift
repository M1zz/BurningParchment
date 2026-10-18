// PaywallView.swift
// 프로 일회성 잠금해제 페이월

import SwiftUI
import StoreKit

/// 페이월이 왜 열렸는지. 막힌 기능을 머리말과 첫 줄로 올려 "지금 무엇이 열리는지"부터 말한다.
enum PaywallReason {
    /// 무료 데드라인 한도에 닿아 하나 더 만들려다 열림
    case deadline
    /// 프로 테마(양피지·불꽃)를 고르려다 열림
    case theme
    /// 조각 카드·포스터를 내보내려다 열림
    case fragmentExport
    /// 회고 책을 PDF 로 내보내려다 열림
    case bookExport
    /// 재의 흐름의 긴 기간 분석을 열려다 열림
    case insights
    /// 불타는 자유시간을 켜려다 열림
    case freeTime

    /// 혜택 목록에서 맨 위로 올릴 항목
    fileprivate var feature: PaywallView.Feature {
        switch self {
        case .deadline:       return .deadline
        case .theme:          return .theme
        case .fragmentExport: return .fragmentExport
        case .bookExport:     return .bookExport
        case .insights:       return .insights
        case .freeTime:       return .freeTime
        }
    }
}

struct PaywallView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchaseAction

    /// 열린 까닭. 설정에서 직접 열면 nil.
    var reason: PaywallReason? = nil

    @State private var errorMessage: String?
    @State private var showNothingToRestore = false

    var body: some View {
        ZStack {
            Color.appBackgroundWarm.ignoresSafeArea()

            VStack(spacing: 0) {
                closeBar

                ScrollView {
                    VStack(spacing: 24) {
                        header
                        featureList
                        purchaseSection
                        legalSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .alert("구매를 완료하지 못했어요",
               isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("복원할 구매가 없어요", isPresented: $showNothingToRestore) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("이 Apple 계정으로 프로를 산 기록을 찾지 못했어요. 구매할 때 쓴 계정으로 로그인했는지 확인해주세요.")
        }
        .task { await storeManager.loadProduct() }
        .onAppear { BurningFunnel.paywallSeen.reach() }
        .onChange(of: storeManager.isPro) { _, pro in
            if pro {
                BurningFunnel.purchased.reach()
                dismiss()
            }
        }
    }

    // MARK: - Close

    private var closeBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.inkMuted.opacity(0.7))
                    .frame(width: 38, height: 38)
            }
            .accessibilityLabel("닫기")
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.ember.opacity(0.35), .clear],
                            center: .center, startRadius: 4, endRadius: 60
                        )
                    )
                    .frame(width: 110, height: 110)
                Image(systemName: "flame.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange, Color(red: 0.9, green: 0.25, blue: 0.05)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }

            Text(headline)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(.ember.opacity(0.95))
                .multilineTextAlignment(.center)

            Text(subheadline)
                .font(.system(size: 14, design: .serif))
                .foregroundColor(.inkMuted.opacity(0.65))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var headline: String {
        switch reason {
        case .deadline:       return String(localized: "데드라인을 더 세우려면")
        case .theme:          return String(localized: "다른 빛깔로 태워 보세요")
        case .fragmentExport: return String(localized: "모은 조각을 꺼내 보세요")
        case .bookExport:     return String(localized: "회고 책을 손에 쥐어 보세요")
        case .insights:       return String(localized: "한 해의 재를 한눈에")
        case .freeTime:       return String(localized: "나만의 시간만 태워 보세요")
        case nil:       return String(localized: "불타는 내인생 프로")
        }
    }

    private var subheadline: String {
        switch reason {
        case .deadline:
            return String(localized: "무료로는 데드라인을 \(StoreManager.freeDeadlineLimit)개까지 둘 수 있어요. 프로로 여러 목표를 함께 세어보세요.")
        case .theme:
            return String(localized: "달빛 한지, 청자, 노을. 양피지와 불꽃의 빛깔을 바꿔요.")
        case .fragmentExport:
            return String(localized: "불을 끄고 남긴 조각을 카드와 포스터로 만들어 간직해요.")
        case .bookExport:
            return String(localized: "적어 온 회고를 PDF 한 권으로 묶어 보관하고 인쇄해요.")
        case .insights:
            return String(localized: "지난 열두 달 동안 시간이 어디로 흘렀는지 달마다 보여 드려요.")
        case .freeTime:
            return String(localized: "잠과 일을 뺀 진짜 내 시간을 골라 두면, 그 시간이 지나갈 때만 이번 주 양피지가 타요.")
        case nil:
            return String(localized: "하루를 남김없이 담아보세요")
        }
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(spacing: 14) {
            ForEach(orderedFeatures, id: \.self) { feature in
                featureRow(icon: feature.icon, title: feature.title, detail: feature.detail)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.ink.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.ember.opacity(0.12), lineWidth: 1)
                )
        )
    }

    enum Feature: CaseIterable {
        case freeTime, theme, fragmentExport, bookExport, insights, deadline, future

        var icon: String {
            switch self {
            case .freeTime:       return "hourglass"
            case .theme:          return "paintpalette.fill"
            case .fragmentExport: return "square.and.arrow.up.fill"
            case .bookExport:     return "book.closed.fill"
            case .insights:       return "chart.bar.fill"
            case .deadline:       return "flag.fill"
            case .future:         return "sparkles"
            }
        }

        var title: LocalizedStringKey {
            switch self {
            case .freeTime:       return "불타는 자유시간"
            case .theme:          return "양피지·불꽃 테마"
            case .fragmentExport: return "조각 카드·포스터"
            case .bookExport:     return "회고 책 PDF"
            case .insights:       return "한 해의 재 흐름"
            case .deadline:       return "데드라인 무제한"
            case .future:         return "앞으로의 프로 기능"
            }
        }

        var detail: LocalizedStringKey {
            switch self {
            case .freeTime:       return "일주일 중 나만의 시간이 지날 때만 양피지가 타요"
            case .theme:          return "달빛 한지·청자·노을 빛깔, 들불·숯불·불티로 양피지가 타요"
            case .fragmentExport: return "모은 조각을 카드와 포스터 이미지로 공유해요"
            case .bookExport:     return "회고를 날짜별 페이지의 PDF 로 묶어요"
            case .insights:       return "지난 12개월의 재를 달마다 나눠 보여줘요"
            case .deadline:       return "여러 목표를 동시에 카운트다운해요"
            case .future:         return "새로 추가되는 프로 기능도 모두 포함돼요"
            }
        }
    }

    /// 열린 까닭의 기능을 맨 위로.
    private var orderedFeatures: [Feature] {
        guard let first = reason?.feature else { return Feature.allCases }
        return [first] + Feature.allCases.filter { $0 != first }
    }

    private func featureRow(icon: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.ember.opacity(0.85))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundColor(.ember.opacity(0.9))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.inkMuted.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Purchase

    private var purchaseSection: some View {
        VStack(spacing: 14) {
            Button {
                Task { await purchase() }
            } label: {
                HStack(spacing: 8) {
                    if storeManager.purchaseInProgress || (storeManager.proProduct == nil && storeManager.isLoadingProduct) {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(purchaseButtonTitle)
                            .font(.system(size: 17, weight: .semibold, design: .serif))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.ember, Color(red: 0.85, green: 0.35, blue: 0.1)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: .ember.opacity(0.3), radius: 12, y: 4)
            }
            .disabled(storeManager.purchaseInProgress || storeManager.isLoadingProduct)

            Text("구독이 아니에요. 한 번 결제로 평생 이용할 수 있어요")
                .font(.system(size: 11))
                .foregroundColor(.inkMuted.opacity(0.5))

            Button {
                Task { await restore() }
            } label: {
                Text("구매 복원")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.ember.opacity(0.7))
            }
            .disabled(storeManager.purchaseInProgress)
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        HStack(spacing: 8) {
            Link("이용약관 (EULA)",
                 destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            Text("·")
            Link("개인정보처리방침", destination: Self.privacyURL)
        }
        .font(.system(size: 11))
        .foregroundColor(.inkMuted.opacity(0.5))
        .tint(.inkMuted.opacity(0.5))
    }

    private var purchaseButtonTitle: String {
        if let price = storeManager.proProduct?.displayPrice {
            return String(localized: "평생 이용권 · \(price)")
        }
        // 가격을 못 받아 온 채로 "구매"를 내밀지 않는다 — 누르면 다시 불러온다.
        return String(localized: "가격 다시 불러오기")
    }

    // MARK: - Actions

    private func purchase() async {
        guard storeManager.proProduct != nil else {
            await storeManager.loadProduct()
            if storeManager.proProduct == nil {
                errorMessage = storeManager.lastError ?? String(localized: "네트워크 상태를 확인하고 다시 시도해주세요.")
            }
            return
        }
        let ok = await storeManager.purchasePro { try await purchaseAction($0) }
        // 사용자가 결제 시트를 닫은 건 실패가 아니다 — lastError 가 없으면 조용히 둔다.
        if !ok, !storeManager.isPro, let message = storeManager.lastError {
            errorMessage = message
        }
    }

    private func restore() async {
        let restored = await storeManager.restorePurchases()
        guard !restored else { return }   // 열렸으면 onChange 가 닫는다
        if let message = storeManager.lastError {
            errorMessage = message
        } else {
            showNothingToRestore = true
        }
    }

    /// 개인정보처리방침은 지원 언어마다 페이지가 있다. 한국어·일본어가 아니면 영어 페이지로.
    private static var privacyURL: URL {
        let language = Locale.preferredLanguages.first ?? "en"
        if language.hasPrefix("ko") { return BurningParchmentSpec.legal.privacyURL }
        let folder = language.hasPrefix("ja") ? "ja" : "en"
        return URL(string: "https://m1zz.github.io/BurningParchment/\(folder)/privacy.html")
            ?? BurningParchmentSpec.legal.privacyURL
    }
}

#Preview {
    PaywallView(reason: .deadline)
        .environmentObject(StoreManager())
        .preferredColorScheme(.dark)
}
