// FragmentBackView.swift
// 식은 조각을 뒤집어 뒷면에 한 줄을 적는다. 아침 확인과 모은 조각 화면이 함께 쓴다.

import SwiftUI

// MARK: - Flip Card

/// 앞면은 타다 만 조각, 뒷면은 그 조각의 뒤집힌 모습과 적어 둔 한 줄.
struct FragmentFlipCard: View {
    let fragment: ParchmentFragment
    @Binding var showsBack: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            FragmentScrapView(fragment: fragment)
                .opacity(showsBack ? 0 : 1)

            backFace
                .opacity(showsBack ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(showsBack ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.6, dampingFraction: 0.8),
                   value: showsBack)
        .contentShape(Rectangle())
        .onTapGesture { showsBack.toggle() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsBack ? String(localized: "조각의 뒷면") : String(localized: "조각의 앞면"))
        .accessibilityValue(fragment.isBackWritten ? fragment.phrase : String(localized: "아직 비어 있어요"))
        .accessibilityHint("두 번 탭하면 조각을 뒤집습니다")
        .accessibilityAddTraits(.isButton)
    }

    /// 뒤집으면 모양도 좌우가 바뀐다
    private var backFace: some View {
        ZStack {
            FragmentScrapView(fragment: fragment)
                .scaleEffect(x: -1, y: 1)
                .saturation(0.6)
                .brightness(0.04)

            Text(fragment.isBackWritten ? fragment.phrase : String(localized: "아직 비어 있어요"))
                .font(.system(.body, design: .serif))
                .foregroundColor(Color(red: 0.25, green: 0.16, blue: 0.08)
                    .opacity(fragment.isBackWritten ? 0.95 : 0.5))
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.90, green: 0.83, blue: 0.68).opacity(0.92))
                )
                .padding(24)
        }
    }
}

// MARK: - Back Editor

/// 뒷면에 적을 한 줄. 비워 두고 저장하면 추천 글귀가 적힌다.
struct FragmentBackEditor: View {
    let fragment: ParchmentFragment
    var onSaved: () -> Void = {}

    @EnvironmentObject var fragmentManager: FragmentManager
    @State private var phrase = ""
    @State private var suggestion = FragmentPhrase.random()
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("뒷면에 남길 한 줄")
                .font(.system(.body, design: .serif).weight(.medium))
                .foregroundColor(.inkMuted)

            TextField(suggestion, text: $phrase, axis: .vertical)
                .font(.system(.body, design: .serif))
                .foregroundColor(.ink)
                .lineLimit(1...3)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { focused = false }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.ink.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.ember.opacity(0.25), lineWidth: 1))
                )

            Button {
                suggestion = FragmentPhrase.random(excluding: suggestion)
            } label: {
                Label("다른 글귀 보기", systemImage: "arrow.triangle.2.circlepath")
                    .font(.body.weight(.medium))
                    .foregroundColor(.ember.opacity(0.85))
            }

            Text("비워 두면 흐리게 보이는 글귀가 적혀요")
                .font(.body)
                .foregroundColor(.inkMuted.opacity(0.7))

            Button(action: save) {
                Text("뒷면에 적기")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.onEmber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.ember))
            }
            .padding(.top, 4)
        }
        .onAppear {
            if fragment.isBackWritten { phrase = fragment.phrase }
        }
    }

    private func save() {
        let written = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        fragmentManager.setPhrase(written.isEmpty ? suggestion : written, for: fragment.id)
        focused = false
        onSaved()
    }
}
