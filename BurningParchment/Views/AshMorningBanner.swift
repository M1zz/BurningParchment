// AshMorningBanner.swift
// 지나간 하루가 어떻게 됐는지 아침에 한 번 알려 준다.
//
// 한 줄 남긴 날은 재로 쌓이고, 남기지 않은 날(앱에 오지 않은 날도)은 재가 되어 바람에 날아간다.
// 날아간 날은 매번이 아니라 가끔(사흘에 한 번까지)만 보여 준다 — 탓하려는 게 아니라 알아차리게 하려고.
// 날아간 날은 정리한 것으로 친다. 재 항아리가 그 날들을 다시 묻지 않는다.
// 쌓인 날은 처음 몇 번만 알려 준다 — 습관이 붙을 때까지.

import SwiftUI

/// 아침에 보여 줄 어제 이야기
enum AshMorning: Equatable {
    /// 어제 한 줄이 재로 쌓였다
    case kept
    /// 남기지 않은 날들이 날아갔다 — start ... end (그 끝은 어제)
    case blown(start: Date, end: Date, days: Int)

    static let firstSeenKey = "ashFirstSeenDay"
    static let lastBlownShownKey = "ashBlownShownDay"
    static let keptShownCountKey = "ashKeptShownCount"
    static let lastShownKey = "ashMorningShownDay"
    static let blownEveryDays = 3
    static let keptShownLimit = 3

    /// 무엇을 보여 줄지. 하루에 한 번만 묻는다(그날 이미 보였으면 nil).
    static func decide(reflectionDays: [Date], sweptUntil: Date?, firstSeen: Date,
                       lastShown: Date?, lastBlownShown: Date?, keptShownCount: Int,
                       now: Date, calendar cal: Calendar = .current) -> AshMorning? {
        let today = cal.startOfDay(for: now)
        if let lastShown, cal.startOfDay(for: lastShown) >= today { return nil }
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today) else { return nil }
        let days = Set(reflectionDays.map { cal.startOfDay(for: $0) })

        if days.contains(yesterday) {
            return keptShownCount < keptShownLimit ? .kept : nil
        }

        // 마지막으로 재가 담긴 날 · 정리한 날 · 처음 연 날의 전날 중 가장 늦은 날 다음부터 어제까지
        var anchors = days.filter { $0 < today }
        if let sweptUntil { anchors.insert(cal.startOfDay(for: sweptUntil)) }
        if let beforeFirst = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: firstSeen)) {
            anchors.insert(beforeFirst)
        }
        guard let anchor = anchors.max(),
              let start = cal.date(byAdding: .day, value: 1, to: anchor), start <= yesterday else { return nil }
        if let lastBlownShown,
           let since = cal.dateComponents([.day], from: cal.startOfDay(for: lastBlownShown), to: today).day,
           since < blownEveryDays { return nil }
        let count = (cal.dateComponents([.day], from: start, to: yesterday).day ?? 0) + 1
        return .blown(start: start, end: yesterday, days: count)
    }
}

struct AshMorningBanner: View {
    /// 지금 양피지가 다른 화면에 가려져 있는지 — 가려져 있으면 띄우지 않는다
    let covered: Bool
    let onOpenUrn: () -> Void

    @EnvironmentObject var reflectionManager: ReflectionManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AshMorning.firstSeenKey) private var firstSeen: Double = 0
    @AppStorage(AshMorning.lastShownKey) private var lastShown: Double = 0
    @AppStorage(AshMorning.lastBlownShownKey) private var lastBlownShown: Double = 0
    @AppStorage(AshMorning.keptShownCountKey) private var keptShownCount = 0

    @State private var shown: AshMorning?
    @State private var blow: Double = 0

    var body: some View {
        // Group 은 비어 있으면 그려지지 않아 onAppear 가 불리지 않는다 — 늘 서 있는 상자에 담는다
        VStack(spacing: 0) {
            if let shown {
                card(shown)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear(perform: evaluate)
        .onChange(of: covered) { _, _ in evaluate() }
    }

    @ViewBuilder
    private func card(_ m: AshMorning) -> some View {
        switch m {
        case .kept:
            Button {
                onOpenUrn()
                hide()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.ember)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("어제가 재로 쌓였어요")
                            .font(.system(.footnote, design: .serif).weight(.semibold))
                            .foregroundColor(.ember)
                        Text("재 항아리에서 볼 수 있어요")
                            .font(.caption2)
                            .foregroundColor(.inkMuted.opacity(0.7))
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.ember.opacity(0.6))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Capsule().fill(Color.ink.opacity(0.05)))
            }
            .buttonStyle(.plain)
        case .blown(let start, _, let days):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "wind")
                        .foregroundColor(.inkMuted.opacity(0.7))
                    Text(days == 1 ? String(localized: "어제는 재가 되어 바람에 날아갔어요")
                                   : String(localized: "지난 \(days)일은 재가 되어 바람에 날아갔어요"))
                        .font(.system(.footnote, design: .serif).weight(.semibold))
                        .foregroundColor(.ink.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                AshPile(seed: start.timeIntervalSinceReferenceDate, count: min(days * 14, 160), blow: blow)
                    .frame(height: 26)
                    .accessibilityHidden(true)
                Text("한 줄 남긴 날만 항아리에 담겨요")
                    .font(.caption2)
                    .foregroundColor(.inkMuted.opacity(0.6))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.ink.opacity(0.04)))
            .onTapGesture(perform: hide)
            .accessibilityElement(children: .combine)
        }
    }

    private func evaluate() {
        guard shown == nil, !covered else { return }
        let now = Date()
        if firstSeen == 0 { firstSeen = Calendar.current.startOfDay(for: now).timeIntervalSince1970 }
        guard let m = AshMorning.decide(
            reflectionDays: reflectionManager.reflections.map(\.date),
            sweptUntil: reflectionManager.ashSweptUntil,
            firstSeen: Date(timeIntervalSince1970: firstSeen),
            lastShown: lastShown == 0 ? nil : Date(timeIntervalSince1970: lastShown),
            lastBlownShown: lastBlownShown == 0 ? nil : Date(timeIntervalSince1970: lastBlownShown),
            keptShownCount: keptShownCount,
            now: now) else { return }

        lastShown = now.timeIntervalSince1970
        switch m {
        case .kept:
            keptShownCount += 1
        case .blown(_, let end, _):
            lastBlownShown = now.timeIntervalSince1970
            // 날아간 날은 정리한 것으로 — 재 항아리가 다시 묻지 않는다
            reflectionManager.sweepAsh(through: end)
        }
        blow = 0
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) { shown = m }
        if case .blown = m, !reduceMotion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeIn(duration: 1.6)) { blow = 1 }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) { hide() }
    }

    private func hide() {
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.3)) { shown = nil }
    }
}
