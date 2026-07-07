// PaywallView.swift
// 프로 일회성 잠금해제 페이월

import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var showError = false

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.06, blue: 0.04).ignoresSafeArea()

            VStack(spacing: 0) {
                closeBar

                ScrollView {
                    VStack(spacing: 24) {
                        header
                        featureList
                        purchaseSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .alert("구매를 완료하지 못했어요", isPresented: $showError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("네트워크 상태를 확인하고 다시 시도해주세요.")
        }
        .onChange(of: storeManager.isPro) { pro in
            if pro { dismiss() }
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
                    .foregroundColor(.gray.opacity(0.7))
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
                            colors: [Color.orange.opacity(0.35), .clear],
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

            Text("불타는 내인생 프로")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(.orange.opacity(0.95))

            Text("하루를 남김없이 담아보세요")
                .font(.system(size: 14, design: .serif))
                .foregroundColor(.gray.opacity(0.65))
        }
        .padding(.top, 8)
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(spacing: 14) {
            featureRow(
                icon: "archivebox.fill",
                title: "항아리 무제한",
                detail: "주제별로 원하는 만큼 재 항아리를 만들어요"
            )
            featureRow(
                icon: "flag.fill",
                title: "데드라인 무제한",
                detail: "여러 목표를 동시에 카운트다운해요"
            )
            featureRow(
                icon: "sparkles",
                title: "앞으로의 프로 기능",
                detail: "새로 추가되는 프로 기능도 모두 포함돼요"
            )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func featureRow(icon: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.orange.opacity(0.85))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundColor(.orange.opacity(0.9))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.6))
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
                Task {
                    let ok = await storeManager.purchasePro()
                    if !ok && !storeManager.isPro { showError = true }
                }
            } label: {
                HStack(spacing: 8) {
                    if storeManager.purchaseInProgress {
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
                                colors: [Color.orange, Color(red: 0.85, green: 0.35, blue: 0.1)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: .orange.opacity(0.3), radius: 12, y: 4)
            }
            .disabled(storeManager.purchaseInProgress)

            Text("한 번 결제로 평생 이용할 수 있어요")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.5))

            Button {
                Task { await storeManager.restorePurchases() }
            } label: {
                Text("구매 복원")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.orange.opacity(0.7))
            }
            .disabled(storeManager.purchaseInProgress)
        }
    }

    private var purchaseButtonTitle: String {
        if let price = storeManager.proProduct?.displayPrice {
            return String(localized: "평생 이용권 · \(price)")
        }
        return String(localized: "평생 이용권 구매")
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreManager())
        .preferredColorScheme(.dark)
}
