// OnboardingView.swift
// 처음 연 사람에게 이 앱에서 하는 일 세 가지(낮에 보기 · 밤에 끄기 · 재 모으기)를 세 장으로 보여 준다.
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

    // 낮에 보고, 밤에 끄고, 쌓인 것을 본다 — 이 앱에서 하는 일은 이 셋이다.
    private let pages: [Page] = [
        Page(id: 0, symbol: "flame",
             title: "오늘이라는 종이가 타요",
             detail: "일어난 순간부터 잠들 시각까지 양피지가 천천히 타요. 남은 만큼을 보면 지금 할 일이 보여요."),
        Page(id: 1, symbol: "wind",
             title: "밤에는 후 불어 불을 꺼요",
             detail: "잠들기 30분 전, 마이크에 대고 후 불면 불이 꺼져요. 입김의 세기만 확인하고 소리는 녹음하지 않아요."),
        Page(id: 2, symbol: "scroll",
             title: "한 줄 남긴 날은 재로 쌓여요",
             detail: "오늘을 한 줄로 남기면 재 항아리에 쌓여요. 남기지 않은 날은 바람에 날아가요."),
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
