// PaywallView.swift
// 세 칸(무료 · Plus · Pro) 페이월 — LeeoKit `LeeoShowcasePaywall`(두번알림 · 클립키보드와 같은 틀).
//
//   Plus | Pro         살 수 있는 칸. 들어온 자리의 칸이 먼저 골라져 있다
//   기능 그림           고른 칸에서 열리는 것(옆으로 넘김). 막힌 기능이 맨 앞
//   연 구독 · 평생       LeeoTermPicker
//   ═ 떠 있는 단추 ═    고른 칸 · 길을 산다
//   스크롤한 아래        지금 상태 · 복원 · 코드 사용 · 구독 고지 · 약관
//
// ⚠️ 상품이 오지 않으면 그 길의 단추는 눌리지 않는다. 다른 상품을 대신 사게 하지 않는다.
// ⚠️ 이미 가진 칸은 고를 수 없다. Pro 면 파는 말 대신 지금 자리를 말한다.

import SwiftUI
import StoreKit
import LeeoKit

/// 페이월이 왜 열렸는지. 막힌 기능을 첫 그림으로 올린다.
enum PaywallReason {
    case deadline, theme, fragmentExport, bookExport, insights, freeTime
    /// 인생의 시간(세어 둔 것)을 더 만들려다 열림
    case count

    var showcaseID: String {
        switch self {
        case .deadline:       return "deadline"
        case .theme:          return "theme"
        case .fragmentExport: return "fragmentExport"
        case .bookExport:     return "bookExport"
        case .insights:       return "insights"
        case .freeTime:       return "freeTime"
        case .count:          return "count"
        }
    }
}

struct PaywallView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchaseAction

    /// 열린 까닭. 설정에서 열면 nil.
    var reason: PaywallReason? = nil
    /// 설정에서 화면으로 넘어와 열렸다 — 닫기 단추는 바깥 내비게이션이 맡는다.
    var embedded = false
    /// 처음 골라 둘 칸 (nil 이면 들어온 자리의 칸)
    var start: StoreManager.Plan? = nil

    @State private var chosen: StoreManager.Plan?
    @State private var plusTerm: LeeoPlanTerm = .yearly
    @State private var proTerm: LeeoPlanTerm = .yearly
    @State private var buying: StoreManager.ProductID?
    @State private var errorMessage: String?
    @State private var showNothingToRestore = false
    @State private var showRedeemCode = false

    var body: some View {
        Group {
            if embedded {
                page
            } else {
                NavigationStack {
                    page.toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { dismiss() } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.title3)
                            }
                            .accessibilityLabel("닫기")
                        }
                    }
                }
            }
        }
        .tint(.ember)
        .alert("구매를 완료하지 못했어요",
               isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("복원할 구매가 없어요", isPresented: $showNothingToRestore) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("이 Apple 계정으로 산 기록을 찾지 못했어요. 구매할 때 쓴 계정으로 로그인했는지 확인해주세요.")
        }
        .task {
            await storeManager.loadProduct()
            // 페이월이 열리는 순간이 "이미 샀는데 왜 또" 를 잡을 마지막 기회다
            await storeManager.refresh()
        }
        .onAppear { BurningFunnel.paywallSeen.reach() }
        .onChange(of: storeManager.plan) { old, new in
            guard new > old else { return }
            BurningFunnel.purchased.reach()
            if !embedded { dismiss() }
        }
    }

    private var page: some View {
        LeeoShowcasePaywall(showcases: showcases) {
            if purchasable.count > 1 { planSwitch }
        } plans: {
            plans
        } button: {
            if let plan = selected {
                let product = offer(plan, term(plan).wrappedValue)
                LeeoPrimaryButton(title: buyTitle(plan),
                                  isWorking: buying == product && storeManager.purchaseInProgress) {
                    Task { await purchase(product) }
                }
                .disabled(storeManager.purchaseInProgress || storeManager.product(product) == nil)
            }
        } details: {
            VStack(spacing: 20) {
                if storeManager.isFounder {
                    Text("먼저 써 주신 분이라 인생의 시간은 개수 제한 없이 세어요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                restoreRow
                legal
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 칸

    /// 살 수 있는 칸 — 이미 가진 칸과 그 아래 칸은 빠진다.
    private var purchasable: [StoreManager.Plan] { [.plus, .pro].filter { $0 > storeManager.plan } }

    /// 들어온 자리의 칸. 세어 둔 것을 더 만들려던 Plus 사람은 Pro 를, 나머지는 Plus 를 먼저 본다.
    private var focus: StoreManager.Plan {
        reason == .count && storeManager.hasPlus ? .pro : .plus
    }

    private var selected: StoreManager.Plan? {
        if let pick = chosen ?? start, purchasable.contains(pick) { return pick }
        if purchasable.contains(focus) { return focus }
        return purchasable.first
    }

    private func term(_ plan: StoreManager.Plan) -> Binding<LeeoPlanTerm> {
        plan == .plus ? $plusTerm : $proTerm
    }

    private func offer(_ plan: StoreManager.Plan, _ term: LeeoPlanTerm) -> StoreManager.ProductID {
        switch (plan, term) {
        case (.plus, .yearly):   return .plusYearly
        case (.plus, .lifetime): return .plus
        case (_, .yearly):       return .proYearly
        case (_, .lifetime):     return .pro
        }
    }

    private func buyTitle(_ plan: StoreManager.Plan) -> String {
        plan == .plus ? String(localized: "Plus 시작하기") : String(localized: "Pro 시작하기")
    }

    private var planSwitch: some View {
        HStack(spacing: 4) {
            ForEach(purchasable, id: \.self) { plan in
                let isOn = plan == selected
                Button {
                    withAnimation(.snappy(duration: 0.25)) { chosen = plan }
                } label: {
                    Text(verbatim: plan == .plus ? "Plus" : "Pro")
                        .font(.body.weight(.bold))
                        .foregroundStyle(isOn ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if isOn {
                                Capsule().fill(Color(uiColor: .systemBackground))
                                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
    }

    @ViewBuilder
    private var plans: some View {
        if let plan = selected {
            LeeoTermPicker(term: term(plan),
                           yearly: storeManager.product(offer(plan, .yearly)),
                           lifetime: storeManager.product(offer(plan, .lifetime)))
        } else {
            Text("모든 기능이 열려 있어요. 고마워요")
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 그림 장

    /// 고른 칸에서 열리는 것만. 막힌 기능이 맨 앞. 다 가진 사람에게는 전부.
    private var showcases: [LeeoShowcase] {
        let plus = [
            LeeoShowcase(id: "freeTime", title: String(localized: "불타는 자유시간"),
                         detail: String(localized: "일주일 중 나만의 시간이 지날 때만 양피지가 타요"), art: { FreeTimeArt() }),
            LeeoShowcase(id: "theme", title: String(localized: "양피지·불꽃 테마"),
                         detail: String(localized: "달빛 한지·청자·노을 빛깔, 들불·숯불·불티로 양피지가 타요"), art: { ThemeArt() }),
            LeeoShowcase(id: "fragmentExport", title: String(localized: "조각 카드·포스터"),
                         detail: String(localized: "모은 조각을 카드와 포스터 이미지로 공유해요"), art: { FragmentExportArt() }),
            LeeoShowcase(id: "bookExport", title: String(localized: "회고 책 PDF"),
                         detail: String(localized: "회고를 날짜별 페이지의 PDF 로 묶어요"), art: { BookExportArt() }),
            LeeoShowcase(id: "insights", title: String(localized: "한 해의 재 흐름"),
                         detail: String(localized: "지난 12개월의 재를 달마다 나눠 보여줘요"), art: { InsightsArt() }),
            LeeoShowcase(id: "deadline", title: String(localized: "데드라인 무제한"),
                         detail: String(localized: "여러 목표를 동시에 카운트다운해요"), art: { DeadlineArt() }),
            LeeoShowcase(id: "count", title: String(localized: "인생의 시간 3개"),
                         detail: String(localized: "부모님, 아이, 여행처럼 세 가지 시간을 함께 세어요"), art: { CountThreeArt() }),
        ]
        let pro = [
            LeeoShowcase(id: "count", title: String(localized: "인생의 시간 무제한"),
                         detail: String(localized: "세어 보고 싶은 시간을 몇 개든 세어요"), art: { CountUnlimitedArt() }),
            LeeoShowcase(id: "plusAll", title: String(localized: "Plus 기능 전부"),
                         detail: String(localized: "테마, 조각 카드, 회고 책 PDF, 한 해의 재, 데드라인 무제한"), art: { PlusAllArt() }),
            LeeoShowcase(id: "future", title: String(localized: "앞으로의 Pro 기능"),
                         detail: String(localized: "새로 생기는 Pro 기능도 모두 포함돼요"), systemImage: "sparkles", tint: .ember),
        ]
        var pages: [LeeoShowcase]
        switch selected {
        case .plus?: pages = plus
        case .pro?:  pages = storeManager.hasPlus ? pro : pro + plus.filter { $0.id != "count" }
        default:     pages = pro + plus.filter { $0.id != "count" }
        }
        if let lead = reason?.showcaseID, let i = pages.firstIndex(where: { $0.id == lead }) {
            pages.insert(pages.remove(at: i), at: 0)
        }
        return pages
    }

    // MARK: - 아래

    private var restoreRow: some View {
        HStack(spacing: 24) {
            Button("구매 복원") { Task { await restore() } }
                .disabled(storeManager.purchaseInProgress)
            // 선물 · 할인으로 받은 App Store 코드를 앱 안에서 바로 쓴다. 시트가 닫히면 권한을 다시 읽는다.
            if !storeManager.isPro {
                Button(LeeoGiftText.redeemEntry) { showRedeemCode = true }
            }
        }
        .font(.subheadline)
        .offerCodeRedemption(isPresented: $showRedeemCode) { _ in
            Task { await storeManager.refresh() }
        }
    }

    private var legal: some View {
        VStack(spacing: 8) {
            Text("평생은 한 번만 결제해요. 연 구독은 갱신일 24시간 전까지 해지하지 않으면 자동으로 갱신되고, App Store 계정 설정에서 관리할 수 있어요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                Link("이용약관 (EULA)",
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("개인정보처리방침", destination: Self.privacyURL)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - 동작

    private func purchase(_ id: StoreManager.ProductID) async {
        buying = id
        defer { buying = nil }
        let ok = await storeManager.purchase(id) { try await purchaseAction($0) }
        // 결제 시트를 닫은 건 실패가 아니다 — 오류 문장이 있을 때만 알린다
        if !ok, let message = storeManager.lastError { errorMessage = message }
    }

    private func restore() async {
        let restored = await storeManager.restorePurchases()
        guard !restored else { return }
        if let message = storeManager.lastError {
            errorMessage = message
        } else {
            showNothingToRestore = true
        }
    }

    /// 개인정보처리방침은 지원 언어마다 페이지가 있다. 한국어 · 일본어가 아니면 영어 페이지로.
    private static var privacyURL: URL {
        let language = Locale.preferredLanguages.first ?? "en"
        if language.hasPrefix("ko") { return BurningParchmentSpec.legal.privacyURL }
        let folder = language.hasPrefix("ja") ? "ja" : "en"
        return URL(string: "https://m1zz.github.io/BurningParchment/\(folder)/privacy.html")
            ?? BurningParchmentSpec.legal.privacyURL
    }
}

#Preview {
    PaywallView(reason: .count)
        .environmentObject(StoreManager())
}
