// FirstLoopGuide.swift
// 처음 쓰는 사람에게 "오늘 밤 할 두 가지" 를 보여 준다 — 한 줄 남기기 · 후 불어 불 끄기.
//
// 이 앱에서 매일 하는 일은 이 둘뿐이다(낮의 양피지는 그 까닭, 쌓인 재는 그 보상).
// 두 가지를 한 번씩 해 보면 다시 뜨지 않는다. 닫아도 다시 뜨지 않는다.

import SwiftUI

struct FirstLoopGuide: View {
    /// 오늘 한 줄을 남겼나
    let wroteToday: Bool
    /// 오늘 밤 불을 껐나
    let blewTonight: Bool
    /// 지금 불을 끌 수 있나(잠들기 30분 전부터)
    let canBlow: Bool
    /// 불을 끌 수 있게 되는 시각
    let blowFrom: Date
    let onWrite: () -> Void
    let onBlow: () -> Void

    static let dismissedKey = "firstLoopGuideDismissed"
    @AppStorage(FirstLoopGuide.dismissedKey) private var dismissed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 한 번이라도 둘 다 해 봤으면 이 안내는 끝이다 — 부르는 쪽이 판단해 넘긴다
    static func isNeeded(everWrote: Bool, everBlew: Bool) -> Bool { !(everWrote && everBlew) }

    var body: some View {
        if !dismissed {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("오늘 밤 할 두 가지")
                        .font(.system(.footnote, design: .serif).weight(.semibold))
                        .foregroundColor(.ember)
                    Spacer()
                    Button {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { dismissed = true }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.inkSoft)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "닫기"))
                }
                step(done: wroteToday, symbol: "square.and.pencil",
                     title: String(localized: "오늘을 한 줄 남기기"),
                     note: String(localized: "남긴 날은 재로 쌓여요"),
                     enabled: true, action: onWrite)
                step(done: blewTonight, symbol: "wind",
                     title: String(localized: "후 불어 불 끄기"),
                     note: canBlow ? String(localized: "지금 끌 수 있어요")
                                   : String(localized: "\(blowFrom.formatted(date: .omitted, time: .shortened))부터 끌 수 있어요"),
                     enabled: canBlow, action: onBlow)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.ink.opacity(0.04)))
            .transition(.opacity)
        }
    }

    private func step(done: Bool, symbol: String, title: String, note: String,
                      enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: done ? "checkmark.circle.fill" : symbol)
                    .foregroundColor(done ? .ember : .ink.opacity(0.7))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(.subheadline, design: .serif).weight(.medium))
                        .foregroundColor(.ink.opacity(done ? 0.45 : 0.9))
                        .strikethrough(done, color: .ink.opacity(0.3))
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.inkSoft)
                }
                Spacer(minLength: 0)
                if !done && enabled {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.ember)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(done || !enabled)
        .accessibilityAddTraits(done ? .isSelected : [])
    }
}
