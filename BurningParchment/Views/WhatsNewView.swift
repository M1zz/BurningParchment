// WhatsNewView.swift
// 업데이트 뒤 처음 열 때 한 번 뜨는 "새로 생긴 것". 설정 ▸ 지원에서 다시 볼 수 있다.
//
// ⚠️ 처음 받은 사람에게는 뜨지 않는다 — 그 사람은 안내(BurningOnboardingView)가 맞이한다 (LaunchAudience).
// ⚠️ 내용을 바꿀 때 `WhatsNewContent.version` 도 같이 올린다. 안 올리면 이미 본 것으로 기록된
//    사람은 새 안내를 한 번도 못 본다.

import SwiftUI

enum WhatsNewContent {
    /// 이 안내가 소개하는 버전. 관계없는 버전 올림에서는 다시 뜨지 않도록 앱 버전이 아니라 내용 기준으로 고정한다.
    static let version = "1.2.1"
}

struct WhatsNewView: View {
    let onClose: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 54

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 26) {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: symbolSize, weight: .light))
                            .foregroundColor(.ember)
                            .padding(.top, 28)
                            .accessibilityHidden(true)
                        Text("새로 생긴 것")
                            .font(.system(.title, design: .serif).weight(.bold))
                            .foregroundColor(.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("버전 \(WhatsNewContent.version)")
                            .font(.subheadline)
                            .foregroundColor(.inkMuted)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        row("character.bubble",
                            title: "일본어로도 쓸 수 있어요",
                            detail: "기기 언어가 일본어면 화면과 위젯이 모두 일본어로 보여요.")
                        row("textformat.size",
                            title: "큰 글씨와 대비 증가에 맞췄어요",
                            detail: "글자를 아주 키워도 설정이 잘리지 않고, 대비 증가를 켜면 글자와 불씨가 더 진해져요.")
                        row("hand.draw",
                            title: "처음 쓰는 분을 위한 안내",
                            detail: "옆으로 밀어 기간을 바꾸는 법 같은 숨은 기능을 알맞은 때에 알려 드려요.")
                        row("map",
                            title: "앞으로 만들 기능을 미리 보세요",
                            detail: "설정 ▸ 지원에서 다음에 나올 기능을 보고 바라는 기능을 보낼 수 있어요.")
                        row("ticket",
                            title: "프로모션 코드를 쓸 수 있어요",
                            detail: "받은 코드가 있다면 설정 ▸ 프로에서 넣어 주세요.")
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
            }

            Button(action: onClose) {
                Text("좋아요")
                    .font(.headline)
                    .foregroundColor(.onEmber)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Capsule().fill(Color.ember))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .accessibilityIdentifier("whatsNew.close")
        }
        .background(Color.appBackgroundWarm.ignoresSafeArea())
    }

    private func row(_ symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundColor(.ember)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundColor(.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WhatsNewView {}
}
