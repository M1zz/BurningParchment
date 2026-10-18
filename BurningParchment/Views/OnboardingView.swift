// OnboardingView.swift
// 처음 연 사람에게 이 앱이 무엇을 하는지 세 장으로 보여 준다.
// 건너뛸 수 있고, 설정 ▸ 지원 ▸ '처음 안내 다시 보기' 에서 언제든 다시 본다.

import SwiftUI

struct BurningOnboardingView: View {
    /// 끝까지 보거나 건너뛰면 불린다
    let onFinish: () -> Void

    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 64

    private struct Page: Identifiable {
        let id: Int
        let symbol: String
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
    }

    private let pages: [Page] = [
        Page(id: 0, symbol: "flame",
             title: "남은 시간이 눈앞에서 타들어가요",
             detail: "일어난 순간부터 잠들 시각까지 양피지가 천천히 타요. 옆으로 밀면 이번 주, 이번 달, 올해도 볼 수 있어요."),
        Page(id: 1, symbol: "wind",
             title: "잠들기 30분 전, 후 불어 끄세요",
             detail: "마이크에 대고 후 불면 불이 꺼지고 남은 조각을 모아 둬요. 입김의 세기만 확인하고 소리는 녹음하지 않아요."),
        Page(id: 2, symbol: "scroll",
             title: "하루는 재로 남아요",
             detail: "오늘 한 일을 한 줄로 남기면 그 주의 재 항아리에 쌓여요. 기상과 취침 시간은 설정에서 바꿀 수 있어요."),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            Color.appBackgroundWarm.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if !isLast {
                        Button("건너뛰기") { onFinish() }
                            .foregroundColor(.inkMuted)
                            .padding(.horizontal, 20)
                            .frame(minHeight: 44)
                            .accessibilityInputLabels([Text("건너뛰기"), Text("닫기")])
                    }
                }
                .frame(height: 52)

                TabView(selection: $page) {
                    ForEach(pages) { item in
                        pageView(item).tag(item.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    if isLast {
                        onFinish()
                    } else {
                        withAnimation(reduceMotion ? nil : .easeInOut) { page += 1 }
                    }
                } label: {
                    Text(isLast ? "시작하기" : "다음")
                        .font(.headline)
                        .foregroundColor(.onEmber)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(Color.ember))
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .accessibilityIdentifier("onboarding.next")
            }
        }
    }

    private func pageView(_ item: Page) -> some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: typeSize.isAccessibilitySize ? 12 : 60)
                Image(systemName: item.symbol)
                    .font(.system(size: symbolSize, weight: .light))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange, .red],
                                                    startPoint: .top, endPoint: .bottom))
                    .accessibilityHidden(true)
                Text(item.title)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundColor(.ember)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(item.detail)
                    .font(.body)
                    .foregroundColor(.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

#Preview {
    BurningOnboardingView {}
}
