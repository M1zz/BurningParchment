// ReflectionGraphs.swift
// 분류 그래프 · 재의 분포. ReflectionUrnView.swift 에서 나눴다 — 한 파일이 3천 줄이면 한 줄을 고쳐도 통째로 다시 컴파일된다.

import SwiftUI
import LeeoKit

// MARK: - Classification Graph
// 2D 그래프에 손가락으로 콕 찍어 분류.
// X축: 의지 (좌 없음 → 우 있음), Y축: 시간 (하 없음 → 상 들임).
// 4분면 각각 카테고리 색으로 옅게 칠해 사용자가 어느 영역인지 인지하게.

struct ClassificationGraph: View {
    @Binding var point: CGPoint?
    let onPick: (CGPoint) -> Void

    @State private var lastCellX: Int = -1
    @State private var lastCellY: Int = -1
    @State private var isDragging: Bool = false

    private static let cellsPerAxis: Int = 4  // 4×4 = 16칸

    private func cellIndex(of p: CGPoint) -> (Int, Int) {
        let n = Self.cellsPerAxis
        let cx = min(n - 1, max(0, Int(p.x * CGFloat(n))))
        let cy = min(n - 1, max(0, Int(p.y * CGFloat(n))))
        return (cx, cy)
    }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                ClassificationGraphBackground(size: s)

                if let p = point {
                    pinView
                        .position(x: p.x * s, y: (1 - p.y) * s)
                }
            }
            .frame(width: s, height: s)
            .frame(maxWidth: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = max(0.04, min(0.96, value.location.x / s))
                        let y = max(0.04, min(0.96, 1 - value.location.y / s))
                        let np = CGPoint(x: x, y: y)

                        // 4×4 = 16칸 격자.  셀 경계를 넘을 때마다 짧은 selection 햅틱.
                        let (cx, cy) = cellIndex(of: np)
                        if !isDragging {
                            isDragging = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } else if cx != lastCellX || cy != lastCellY {
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                        lastCellX = cx
                        lastCellY = cy

                        point = np
                        onPick(np)
                    }
                    .onEnded { _ in
                        isDragging = false
                        // 손가락 떼면 soft impact 으로 확정 느낌
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("분류 그래프")
            .accessibilityValue(accessibilityValue)
            .accessibilityHint("두 축에 따라 손가락으로 콕 찍어 분류합니다")
            // 끌어 찍기 대신 네 분면을 이름으로 고른다 (VoiceOver 동작 · 음성 명령)
            .accessibilityActions {
                ForEach(Self.quadrants, id: \.0) { quadrant in
                    Button(quadrant.0.title) {
                        point = quadrant.1
                        onPick(quadrant.1)
                    }
                }
            }
        }
    }

    /// 분면마다 가운데 점. 분류는 applyClassificationPoint 가 점의 위치로 정한다.
    private static let quadrants: [(ReflectionCategory, CGPoint)] = [
        (.forged, CGPoint(x: 0.75, y: 0.75)),
        (.missed, CGPoint(x: 0.75, y: 0.25)),
        (.accept, CGPoint(x: 0.25, y: 0.75)),
        (.scattered, CGPoint(x: 0.25, y: 0.25))
    ]

    private var accessibilityValue: String {
        guard let p = point else { return String(localized: "분류 안 됨") }
        let category = ReflectionCategory.from(intent: p.x > 0.5, spentTime: p.y > 0.5,
                                               drift: p.x < 0.5 && p.y > 0.5 ? .accept : nil)
        return (category ?? .uncategorized).title
    }

    private var pinView: some View {
        ZStack {
            Circle()
                .fill(Color.ember.opacity(0.35))
                .frame(width: 28, height: 28)
                .blur(radius: 4)
            Circle()
                .fill(Color.ink)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.ember, lineWidth: 2.5))
                .shadow(color: .ember.opacity(0.6), radius: 4)
        }
    }
}

// MARK: - Classification Graph Background
// 4분면 배경 + 축 + 라벨.  입력 그래프(ClassificationGraph)와
// 분포 뷰(ReflectionDistributionView)가 공유.

struct ClassificationGraphBackground: View {
    let size: CGFloat
    /// 사분면 이름을 바탕에 깔지. 점이 많이 찍히는 분포 그래프는 이름표를 점 위에 따로 세우므로 끈다.
    var showsQuadrantLabels = true

    private static let cellsPerAxis: Int = 4

    var body: some View {
        ZStack {
            quadrants
            if showsQuadrantLabels { quadrantLabels }
            axisLines
            axisLabels
        }
    }

    private var quadrants: some View {
        let half = size / 2
        return ZStack {
            // 좌상: accept (의지❌ 시간⭕️) — 황금빛
            Rectangle()
                .fill(Color(red: 0.95, green: 0.78, blue: 0.42).opacity(0.14))
                .frame(width: half, height: half)
                .position(x: half / 2, y: half / 2)

            // 우상: forged (의지⭕️ 시간⭕️) — 따뜻한 주황
            Rectangle()
                .fill(Color(red: 0.92, green: 0.55, blue: 0.25).opacity(0.18))
                .frame(width: half, height: half)
                .position(x: half + half / 2, y: half / 2)

            // 좌하: scattered (의지❌ 시간❌) — 옅은 회색
            Rectangle()
                .fill(Color(red: 0.68, green: 0.66, blue: 0.62).opacity(0.12))
                .frame(width: half, height: half)
                .position(x: half / 2, y: half + half / 2)

            // 우하: missed (의지⭕️ 시간❌) — 옅은 갈색
            Rectangle()
                .fill(Color(red: 0.72, green: 0.62, blue: 0.42).opacity(0.15))
                .frame(width: half, height: half)
                .position(x: half + half / 2, y: half + half / 2)
        }
        .overlay(
            Rectangle()
                .stroke(Color.ember.opacity(0.20), lineWidth: 1)
                .frame(width: size, height: size)
        )
    }

    private var axisLines: some View {
        ZStack {
            // 16칸 격자 — 1/4, 3/4 위치의 옅은 분할선
            Path { p in
                let step = size / CGFloat(Self.cellsPerAxis)
                for i in 1..<Self.cellsPerAxis where i != Self.cellsPerAxis / 2 {
                    let v = step * CGFloat(i)
                    p.move(to: CGPoint(x: v, y: 0))
                    p.addLine(to: CGPoint(x: v, y: size))
                    p.move(to: CGPoint(x: 0, y: v))
                    p.addLine(to: CGPoint(x: size, y: v))
                }
            }
            .stroke(Color.ember.opacity(0.10), style: StrokeStyle(lineWidth: 0.4, dash: [1, 3]))

            // 4분면 주축 — 더 진하게
            Path { p in
                p.move(to: CGPoint(x: size / 2, y: 0))
                p.addLine(to: CGPoint(x: size / 2, y: size))
                p.move(to: CGPoint(x: 0, y: size / 2))
                p.addLine(to: CGPoint(x: size, y: size / 2))
            }
            .stroke(Color.ember.opacity(0.22), style: StrokeStyle(lineWidth: 0.6, dash: [3, 3]))
        }
    }

    private var quadrantLabels: some View {
        ZStack {
            // 우상: forged — 의지⭕️ 시간⭕️
            quadrantLabel(String(localized: "마음먹은 대로 했어"),
                          rgb: (0.92, 0.55, 0.25),
                          at: CGPoint(x: size * 0.74, y: size * 0.32))
            // 좌상: accept — 의지 없이 시간만 들였음
            quadrantLabel(String(localized: "어쩌다 하게 됐어"),
                          rgb: (0.95, 0.78, 0.42),
                          at: CGPoint(x: size * 0.26, y: size * 0.32))
            // 우하: missed — 의지는 있는데 시간을 못 냈음
            quadrantLabel(String(localized: "하려 했는데 못 했어"),
                          rgb: (0.78, 0.66, 0.46),
                          at: CGPoint(x: size * 0.74, y: size * 0.68))
            // 좌하: scattered — 그냥 흘러간 시간
            quadrantLabel(String(localized: "그냥 흘러갔어"),
                          rgb: (0.72, 0.70, 0.66),
                          at: CGPoint(x: size * 0.26, y: size * 0.68))
        }
        .allowsHitTesting(false)
    }

    private func quadrantLabel(_ text: String,
                               rgb: (Double, Double, Double),
                               at: CGPoint) -> some View {
        Text(text)
            .scaledFont(size: 10, weight: .semibold, design: .serif)
            .foregroundColor(Color(red: rgb.0, green: rgb.1, blue: rgb.2).opacity(0.85))
            .position(at)
    }

    private var axisLabels: some View {
        ZStack {
            Text("시간을 들였다")
                .scaledFont(size: 10, design: .serif)
                .foregroundColor(.inkSoft)
                .position(x: size / 2, y: 12)

            Text("시간을 안 들였다")
                .scaledFont(size: 10, design: .serif)
                .foregroundColor(.inkSoft)
                .position(x: size / 2, y: size - 12)

            Text("의지\n없음")
                .scaledFont(size: 10, design: .serif)
                .foregroundColor(.inkSoft)
                .multilineTextAlignment(.center)
                .position(x: 22, y: size / 2)

            Text("의지\n있음")
                .scaledFont(size: 10, design: .serif)
                .foregroundColor(.inkSoft)
                .multilineTextAlignment(.center)
                .position(x: size - 22, y: size / 2)
        }
    }
}

// MARK: - Reflection Distribution (재의 분포)
// 모아온 회고들을 2D 분류 그래프 위에 점으로 뿌려 분포를 보여줌.
// 좌표가 저장된 회고는 정확한 위치에, 좌표 없는 옛 회고는 해당 사분면 안에
// 결정적(seeded) 지터로 흩어 놓음.

struct ReflectionDistributionView: View {
    @EnvironmentObject var reflectionManager: ReflectionManager

    private enum Scope: String, CaseIterable {
        case all = "전체"
        case recent30 = "최근 30일"

        var title: String {
            switch self {
            case .all: return String(localized: "전체")
            case .recent30: return String(localized: "최근 30일")
            }
        }
    }
    @State private var scope: Scope = .all

    private struct PlotPoint {
        let point: CGPoint
        let category: ReflectionCategory
        let isDerived: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if plotted.isEmpty {
                Text("아직 분류된 재가 없어요. 회고를 쓸 때 그래프에 콕 찍어보세요.")
                    .scaledFont(size: 12, design: .serif)
                    .foregroundColor(.inkSoft)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                graph
                    .frame(height: 250)
                caption
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.ink.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.ember.opacity(0.10), lineWidth: 1))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("재의 분포")
        .accessibilityValue(accessibilitySummary)
    }

    // MARK: Data

    private var scopedReflections: [DayReflection] {
        switch scope {
        case .all:
            return reflectionManager.reflections
        case .recent30:
            guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else {
                return reflectionManager.reflections
            }
            return reflectionManager.reflections.filter { $0.date >= cutoff }
        }
    }

    private var plotted: [PlotPoint] {
        scopedReflections.compactMap { r in
            if let p = r.classificationPoint {
                return PlotPoint(point: p, category: r.category, isDerived: false)
            }
            // 좌표 없는 옛 회고 — 카테고리 사분면 안에 seeded 지터로 배치
            guard let range = Self.quadrantRange(for: r.category) else { return nil }
            var rng = SeededRNG(seed: UInt64(truncatingIfNeeded: r.id.uuidString.hashValue))
            let x = CGFloat.random(in: range.x, using: &rng)
            let y = CGFloat.random(in: range.y, using: &rng)
            return PlotPoint(point: CGPoint(x: x, y: y), category: r.category, isDerived: true)
        }
    }

    private static func quadrantRange(for cat: ReflectionCategory)
        -> (x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>)? {
        switch cat {
        case .forged:       return (0.56...0.90, 0.56...0.90)
        case .missed:       return (0.56...0.90, 0.10...0.44)
        case .accept, .stop: return (0.10...0.44, 0.56...0.90)
        case .scattered:    return (0.10...0.44, 0.10...0.44)
        case .uncategorized: return nil
        }
    }

    /// 사분면별 개수 — (좌상 accept, 우상 forged, 좌하 scattered, 우하 missed)
    private var quadrantCounts: (tl: Int, tr: Int, bl: Int, br: Int) {
        var tl = 0, tr = 0, bl = 0, br = 0
        for p in plotted {
            let right = p.point.x > 0.5
            let top = p.point.y > 0.5
            switch (right, top) {
            case (false, true):  tl += 1
            case (true, true):   tr += 1
            case (false, false): bl += 1
            case (true, false):  br += 1
            }
        }
        return (tl, tr, bl, br)
    }

    private var centroid: CGPoint? {
        guard plotted.count >= 3 else { return nil }
        let sx = plotted.reduce(0.0) { $0 + $1.point.x }
        let sy = plotted.reduce(0.0) { $0 + $1.point.y }
        let n = CGFloat(plotted.count)
        return CGPoint(x: sx / n, y: sy / n)
    }

    private var derivedCount: Int {
        plotted.filter(\.isDerived).count
    }

    // MARK: Header

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "chart.dots.scatter")
                    .scaledFont(size: 11)
                    .foregroundColor(.ember)
                Text("재의 분포")
                    .scaledFont(size: 14, weight: .semibold, design: .serif)
                    .foregroundColor(.ember.opacity(0.85))
            }

            Spacer()

            HStack(spacing: 6) {
                ForEach(Scope.allCases, id: \.rawValue) { s in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { scope = s }
                    } label: {
                        Text(s.title)
                            .scaledFont(size: 11, weight: scope == s ? .semibold : .regular)
                            .foregroundColor(scope == s ? .ember : .inkSoft)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background(
                                Capsule()
                                    .fill(scope == s ? Color.ember.opacity(0.14) : Color.ink.opacity(0.04))
                                    .overlay(Capsule().stroke(
                                        scope == s ? Color.ember.opacity(0.40) : Color.clear,
                                        lineWidth: 1))
                            )
                    }
                }
            }
        }
    }

    // MARK: Graph

    private var graph: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                ClassificationGraphBackground(size: s, showsQuadrantLabels: false)
                dotCanvas(size: s)
                quadrantPercentages(size: s)

                if let c = centroid {
                    centroidMarker
                        .position(x: c.x * s, y: (1 - c.y) * s)
                }
            }
            .frame(width: s, height: s)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func dotCanvas(size: CGFloat) -> some View {
        Canvas { ctx, _ in
            for item in plotted {
                let x = item.point.x * size
                let y = (1 - item.point.y) * size
                let rgb = item.category.particleColor
                let color = Color(red: rgb.0, green: rgb.1, blue: rgb.2)
                let r: CGFloat = 3.0

                // 글로우
                ctx.opacity = (item.isDerived ? 0.40 : 0.85) * 0.35
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - r * 2.2, y: y - r * 2.2,
                                           width: r * 4.4, height: r * 4.4)),
                    with: .color(color)
                )
                // 코어
                ctx.opacity = item.isDerived ? 0.40 : 0.85
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .color(color)
                )
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }

    /// 사분면마다 이름 · 퍼센트를 한 장의 이름표로 점 위에 세운다 — 점이 빽빽해도 글자가 묻히지 않는다.
    private func quadrantPercentages(size: CGFloat) -> some View {
        let counts = quadrantCounts
        let total = max(1, plotted.count)
        func pct(_ n: Int) -> String { "\(Int(round(Double(n) / Double(total) * 100)))%" }

        return ZStack {
            quadrantTag(String(localized: "어쩌다 하게 됐어"), pct(counts.tl), rgb: (0.95, 0.78, 0.42),
                        at: CGPoint(x: size * 0.26, y: size * 0.27))
            quadrantTag(String(localized: "마음먹은 대로 했어"), pct(counts.tr), rgb: (0.92, 0.55, 0.25),
                        at: CGPoint(x: size * 0.74, y: size * 0.27))
            quadrantTag(String(localized: "그냥 흘러갔어"), pct(counts.bl), rgb: (0.72, 0.70, 0.66),
                        at: CGPoint(x: size * 0.26, y: size * 0.73))
            quadrantTag(String(localized: "하려 했는데 못 했어"), pct(counts.br), rgb: (0.78, 0.66, 0.46),
                        at: CGPoint(x: size * 0.74, y: size * 0.73))
        }
        .allowsHitTesting(false)
    }

    /// 사분면 빛깔은 작은 점으로만 보이고, 글자는 바탕색 이름표 위에 짙은 잉크로 쓴다.
    private func quadrantTag(_ name: String, _ percent: String,
                             rgb: (Double, Double, Double), at: CGPoint) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(red: rgb.0, green: rgb.1, blue: rgb.2))
                    .frame(width: 6, height: 6)
                Text(name)
                    .scaledFont(size: 10, weight: .semibold, design: .serif)
                    .foregroundColor(.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(percent)
                .scaledFont(size: 15, weight: .bold, design: .serif)
                .foregroundColor(.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.appBackgroundWarm.opacity(0.88)))
        .position(at)
    }

    private var centroidMarker: some View {
        ZStack {
            Circle()
                .stroke(Color.ink.opacity(0.7), lineWidth: 1.2)
                .frame(width: 11, height: 11)
            Path { p in
                p.move(to: CGPoint(x: 5.5, y: -3))
                p.addLine(to: CGPoint(x: 5.5, y: 2))
                p.move(to: CGPoint(x: 5.5, y: 9))
                p.addLine(to: CGPoint(x: 5.5, y: 14))
                p.move(to: CGPoint(x: -3, y: 5.5))
                p.addLine(to: CGPoint(x: 2, y: 5.5))
                p.move(to: CGPoint(x: 9, y: 5.5))
                p.addLine(to: CGPoint(x: 14, y: 5.5))
            }
            .stroke(Color.ink.opacity(0.5), lineWidth: 1)
            .frame(width: 11, height: 11)
        }
    }

    // MARK: Caption

    private var caption: some View {
        HStack(spacing: 4) {
            Text("재 \(plotted.count)개 기준")
            if derivedCount > 0 {
                Text("· 좌표 없는 옛 회고 \(derivedCount)개는 사분면 안에 흩어 표시")
            }
            if centroid != nil {
                Text("· ⊕ 무게중심")
            }
        }
        .scaledFont(size: 10, design: .serif)
        .foregroundColor(.inkSoft)
    }

    private var accessibilitySummary: String {
        let counts = quadrantCounts
        let total = max(1, plotted.count)
        func pct(_ n: Int) -> Int { Int(round(Double(n) / Double(total) * 100)) }
        return String(localized: "회고 \(plotted.count)개. 마음먹은 대로 했어 \(pct(counts.tr))퍼센트, 어쩌다 하게 됐어 \(pct(counts.tl))퍼센트, 하려 했는데 못 했어 \(pct(counts.br))퍼센트, 그냥 흘러갔어 \(pct(counts.bl))퍼센트")
    }
}

#Preview {
    ReflectionUrnView()
        .environmentObject(ReflectionManager())
        .environmentObject(StoreManager())
        .preferredColorScheme(.dark)
}
