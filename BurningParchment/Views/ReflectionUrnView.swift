// ReflectionUrnView.swift
// 사용자가 직접 만드는 여러 항아리. 한 항아리 안에 4종 카테고리의 재 입자가 섞여 쌓임.

import SwiftUI

// MARK: - Urn Shape

struct UrnShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let neckW = w * 0.42
        let neckH = h * 0.12
        let lipW  = w * 0.55
        let lipH  = h * 0.06
        let bodyTopY = neckH + lipH
        let bodyMidY = h * 0.55
        let baseW = w * 0.50
        let baseY = h - h * 0.04

        p.move(to: CGPoint(x: (w - lipW) / 2, y: 0))
        p.addLine(to: CGPoint(x: (w + lipW) / 2, y: 0))
        p.addLine(to: CGPoint(x: (w + lipW) / 2, y: lipH))
        p.addLine(to: CGPoint(x: (w + neckW) / 2, y: bodyTopY))
        p.addCurve(
            to: CGPoint(x: (w + baseW) / 2, y: baseY),
            control1: CGPoint(x: w * 1.05, y: bodyTopY + (bodyMidY - bodyTopY) * 0.4),
            control2: CGPoint(x: w * 0.95, y: bodyMidY + (baseY - bodyMidY) * 0.7)
        )
        p.addLine(to: CGPoint(x: (w + baseW) / 2, y: h))
        p.addLine(to: CGPoint(x: (w - baseW) / 2, y: h))
        p.addLine(to: CGPoint(x: (w - baseW) / 2, y: baseY))
        p.addCurve(
            to: CGPoint(x: (w - neckW) / 2, y: bodyTopY),
            control1: CGPoint(x: w * 0.05, y: bodyMidY + (baseY - bodyMidY) * 0.7),
            control2: CGPoint(x: -w * 0.05, y: bodyTopY + (bodyMidY - bodyTopY) * 0.4)
        )
        p.addLine(to: CGPoint(x: (w - lipW) / 2, y: lipH))
        p.closeSubpath()
        return p
    }
}

struct UrnInteriorShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let lipH  = h * 0.06
        let neckH = h * 0.12
        let bodyTopY = neckH + lipH
        let bodyMidY = h * 0.55
        let baseW = w * 0.46
        let baseY = h - h * 0.06
        let neckInsetW = w * 0.34

        p.move(to: CGPoint(x: (w - neckInsetW) / 2, y: bodyTopY))
        p.addLine(to: CGPoint(x: (w + neckInsetW) / 2, y: bodyTopY))
        p.addCurve(
            to: CGPoint(x: (w + baseW) / 2, y: baseY),
            control1: CGPoint(x: w * 0.98, y: bodyMidY * 0.95),
            control2: CGPoint(x: w * 0.90, y: bodyMidY * 1.4)
        )
        p.addLine(to: CGPoint(x: (w - baseW) / 2, y: baseY))
        p.addCurve(
            to: CGPoint(x: (w - neckInsetW) / 2, y: bodyTopY),
            control1: CGPoint(x: w * 0.10, y: bodyMidY * 1.4),
            control2: CGPoint(x: w * 0.02, y: bodyMidY * 0.95)
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - Urn Engraving Shape
// 채움 비율에 따라 단계적으로 드러나는 선각 문양.
// 각 단계는 이전 단계를 포함 — 항아리를 "완성해가는" 느낌.

struct UrnEngravingShape: Shape {
    let fillLevel: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height

        // 단계 1 (≥ 5%): 하단부 가로선 한 줄 — 가장 먼저 드러남
        if fillLevel >= 0.05 {
            let y = h * 0.72
            p.move(to: CGPoint(x: w * 0.22, y: y))
            p.addLine(to: CGPoint(x: w * 0.78, y: y))
        }

        // 단계 2 (≥ 30%): 가로선 + 작은 마름모 3개
        if fillLevel >= 0.30 {
            let y = h * 0.62
            p.move(to: CGPoint(x: w * 0.24, y: y))
            p.addLine(to: CGPoint(x: w * 0.76, y: y))

            let diaY = h * 0.67
            for cx in [w * 0.32, w * 0.50, w * 0.68] {
                let s: CGFloat = 3.5
                p.move(to: CGPoint(x: cx, y: diaY - s))
                p.addLine(to: CGPoint(x: cx + s, y: diaY))
                p.addLine(to: CGPoint(x: cx, y: diaY + s))
                p.addLine(to: CGPoint(x: cx - s, y: diaY))
                p.closeSubpath()
            }
        }

        // 단계 3 (≥ 55%): 식물 덩굴 같은 곡선 (몸체 중간)
        if fillLevel >= 0.55 {
            // 왼쪽 덩굴
            p.move(to: CGPoint(x: w * 0.24, y: h * 0.50))
            p.addQuadCurve(
                to: CGPoint(x: w * 0.48, y: h * 0.44),
                control: CGPoint(x: w * 0.30, y: h * 0.42)
            )
            // 작은 잎
            p.move(to: CGPoint(x: w * 0.36, y: h * 0.45))
            p.addQuadCurve(
                to: CGPoint(x: w * 0.40, y: h * 0.40),
                control: CGPoint(x: w * 0.34, y: h * 0.40)
            )
            // 오른쪽 덩굴
            p.move(to: CGPoint(x: w * 0.76, y: h * 0.50))
            p.addQuadCurve(
                to: CGPoint(x: w * 0.52, y: h * 0.44),
                control: CGPoint(x: w * 0.70, y: h * 0.42)
            )
            // 작은 잎
            p.move(to: CGPoint(x: w * 0.64, y: h * 0.45))
            p.addQuadCurve(
                to: CGPoint(x: w * 0.60, y: h * 0.40),
                control: CGPoint(x: w * 0.66, y: h * 0.40)
            )
        }

        // 단계 4 (≥ 85%): 어깨/입구 띠 — 항아리 전체를 감싸는 마감 문양
        if fillLevel >= 0.85 {
            // 어깨 띠 (목 아래)
            let topY = h * 0.32
            p.move(to: CGPoint(x: w * 0.26, y: topY))
            p.addLine(to: CGPoint(x: w * 0.74, y: topY))
            // 작은 점 장식
            for cx in [w * 0.30, w * 0.50, w * 0.70] {
                p.addEllipse(in: CGRect(x: cx - 1.5, y: topY + 4, width: 3, height: 3))
            }
            // 바닥 마감선
            let baseY = h * 0.82
            p.move(to: CGPoint(x: w * 0.28, y: baseY))
            p.addLine(to: CGPoint(x: w * 0.72, y: baseY))
        }

        return p
    }
}

// MARK: - Seeded RNG

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xDEADBEEF : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Mixed-Ash Urn Visual

/// 4색 입자가 섞여 쌓이는 항아리.  카테고리별 개수에 비례해 입자 수가 결정됨.
struct MixedAshUrnVisual: View {
    let urn: Urn
    let fillLevel: Double
    let counts: [ReflectionCategory: Int]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // 항아리 본체
                UrnShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.32, green: 0.22, blue: 0.16),
                                Color(red: 0.20, green: 0.14, blue: 0.10),
                                Color(red: 0.14, green: 0.10, blue: 0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(UrnShape().stroke(Color.orange.opacity(0.3), lineWidth: 1))
                    .shadow(color: .orange.opacity(0.15), radius: 12)

                // 재 (안쪽 클립)
                ashLayer(in: size)
                    .clipShape(UrnInteriorShape())

                // 선각 문양 — 채울수록 진해지고 확장됨, 항아리 본체 위에만 보이게 클립
                UrnEngravingShape(fillLevel: fillLevel)
                    .stroke(
                        Color(red: 0.98, green: 0.72, blue: 0.32)
                            .opacity(0.20 + 0.55 * min(fillLevel, 1.0)),
                        style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(
                        color: Color.orange.opacity(fillLevel >= 0.85 ? 0.45 : 0.0),
                        radius: fillLevel >= 0.85 ? 3 : 0
                    )
                    .clipShape(UrnShape())
                    .allowsHitTesting(false)

                // 입구 빛
                UrnShape()
                    .stroke(Color.orange.opacity(0.55), lineWidth: 0.8)
                    .blur(radius: 0.5)
                    .mask(
                        Rectangle()
                            .frame(width: size.width, height: size.height * 0.08)
                            .offset(y: -size.height * 0.46)
                    )
            }
        }
    }

    @ViewBuilder
    private func ashLayer(in size: CGSize) -> some View {
        let interiorTop: CGFloat = size.height * 0.18
        let interiorBottom: CGFloat = size.height * 0.94
        let interiorHeight = interiorBottom - interiorTop
        let ashTopY = interiorBottom - interiorHeight * CGFloat(max(0.04, fillLevel))

        ZStack {
            // 빈 안쪽
            Rectangle().fill(Color.black.opacity(0.55))

            // 재 베이스 (어두운 회갈색 — 입자들이 그 위에 올라감)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.30, green: 0.22, blue: 0.16),
                            Color(red: 0.18, green: 0.12, blue: 0.08)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(height: interiorBottom - ashTopY)
                .offset(y: (ashTopY + interiorBottom) / 2 - size.height / 2)

            // 4색 입자 — 카테고리별 개수에 비례 (바닥에 쌓임)
            Canvas { ctx, cSize in
                let baseSeed = UInt64(truncatingIfNeeded: urn.id.uuidString.hashValue)
                var rng = SeededRNG(seed: baseSeed == 0 ? 0xDEADBEEF : baseSeed)

                let settledOrder: [ReflectionCategory] = [.forged, .accept, .missed, .stop, .uncategorized]
                for cat in settledOrder {
                    let count = counts[cat] ?? 0
                    guard count > 0 else { continue }
                    let particles = min(count * 4, 60)
                    let rgb = cat.particleColor
                    for _ in 0..<particles {
                        let x = CGFloat.random(in: 0...cSize.width, using: &rng)
                        let yRel = CGFloat.random(in: 0...1, using: &rng)
                        let y = ashTopY + (interiorBottom - ashTopY) * yRel
                        let r = CGFloat.random(in: 0.7...1.8, using: &rng)
                        let alpha = Double.random(in: 0.45...0.95, using: &rng)
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                            with: .color(Color(red: rgb.0, green: rgb.1, blue: rgb.2).opacity(alpha))
                        )
                    }
                }

                // scattered — 회색 먼지.  쌓이지 않고 항아리 상단 빈 공간에 가볍게 떠다님.
                let scatteredCount = counts[.scattered] ?? 0
                if scatteredCount > 0 {
                    let dust = min(scatteredCount * 3, 40)
                    let rgb = ReflectionCategory.scattered.particleColor
                    // 떠다니는 영역: 입구 근처(interiorTop) ~ ashTopY 사이 + 약간 위로 겹침
                    let dustTop = interiorTop + 4
                    let dustBottom = max(dustTop + 8, ashTopY - 2)
                    for _ in 0..<dust {
                        let x = CGFloat.random(in: 0...cSize.width, using: &rng)
                        let yRel = CGFloat.random(in: 0...1, using: &rng)
                        // 위쪽일수록 밀도가 약간 낮아지게
                        let y = dustTop + (dustBottom - dustTop) * yRel
                        let r = CGFloat.random(in: 0.5...1.2, using: &rng)
                        let alpha = Double.random(in: 0.18...0.40, using: &rng)
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                            with: .color(Color(red: rgb.0, green: rgb.1, blue: rgb.2).opacity(alpha))
                        )
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Header Mini Button

struct AshUrnButton: View {
    @EnvironmentObject var reflectionManager: ReflectionManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                if let urn = reflectionManager.urns.first {
                    MixedAshUrnVisual(
                        urn: urn,
                        fillLevel: reflectionManager.fillLevel(for: urn),
                        counts: reflectionManager.categoryCounts(for: urn)
                    )
                    .frame(width: 22, height: 24)
                } else {
                    Image(systemName: "archivebox")
                        .font(.system(size: 17))
                        .foregroundColor(.orange.opacity(0.5))
                        .frame(width: 22, height: 24)
                }

                if reflectionManager.urns.count > 1 {
                    Text("\(reflectionManager.urns.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.orange))
                        .offset(x: 6, y: -2)
                }
            }
        }
        .accessibilityLabel("재 항아리")
        .accessibilityValue("항아리 \(reflectionManager.urns.count)개, 회고 \(reflectionManager.totalReflectionCount)개")
        .accessibilityHint("탭하여 항아리 관리")
    }
}

// MARK: - Main View

struct ReflectionUrnView: View {
    @EnvironmentObject var reflectionManager: ReflectionManager
    @Environment(\.dismiss) private var dismiss

    var autoOpenInput: Bool = false

    @State private var showInput = false
    @State private var selectedUrn: Urn? = nil
    @State private var editing: DayReflection? = nil
    @State private var showAddUrn = false
    @State private var autoOpenTriggered = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.06, blue: 0.04).ignoresSafeArea()

            if reflectionManager.urns.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        urnGrid
                        recentList
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }

            floatingActions
        }
        .navigationTitle("재 항아리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    NavigationLink {
                        ReflectionBookView()
                            .environmentObject(reflectionManager)
                    } label: {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.orange)
                    }
                    .accessibilityLabel("회고 책으로 보기")

                    Button {
                        showAddUrn = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 17))
                                .foregroundColor(.orange)
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                                .background(Circle().fill(Color(red: 0.08, green: 0.06, blue: 0.04)))
                                .offset(x: 4, y: -4)
                        }
                    }
                    .accessibilityLabel("새 항아리 만들기")
                }
            }
        }
        .sheet(isPresented: $showInput) {
            ReflectionInputView(existing: nil)
                .environmentObject(reflectionManager)
        }
        .sheet(item: $editing) { item in
            ReflectionInputView(existing: item)
                .environmentObject(reflectionManager)
        }
        .sheet(item: $selectedUrn) { urn in
            UrnDetailView(urn: urn) { ref in editing = ref }
                .environmentObject(reflectionManager)
        }
        .sheet(isPresented: $showAddUrn) {
            UrnEditView(editing: nil)
                .environmentObject(reflectionManager)
        }
        .onAppear {
            guard autoOpenInput, !autoOpenTriggered, !reflectionManager.urns.isEmpty else { return }
            autoOpenTriggered = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showInput = true
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox")
                .font(.system(size: 56))
                .foregroundColor(.orange.opacity(0.25))
            Text("아직 항아리가 없어요")
                .font(.system(size: 17, weight: .medium, design: .serif))
                .foregroundColor(.gray.opacity(0.55))
            Text("첫 항아리부터 만들어보세요.\n주제나 영역으로 이름을 지으면 좋아요.")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.4))
                .multilineTextAlignment(.center)

            Button {
                showAddUrn = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("첫 항아리 만들기")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.orange)
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .background(
                    Capsule().fill(Color.orange.opacity(0.15))
                        .overlay(Capsule().stroke(Color.orange.opacity(0.35), lineWidth: 1))
                )
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Grid

    private var urnGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(reflectionManager.urns) { urn in
                urnCell(urn)
                    .onTapGesture { selectedUrn = urn }
                    .dropDestination(for: String.self) { items, _ in
                        // 드래그된 회고 ID(들)를 이 항아리로 이동
                        var moved = false
                        for idStr in items {
                            guard let uuid = UUID(uuidString: idStr),
                                  var ref = reflectionManager.reflections.first(where: { $0.id == uuid })
                            else { continue }
                            ref.urnId = urn.id
                            reflectionManager.update(ref)
                            moved = true
                        }
                        if moved {
                            let gen = UINotificationFeedbackGenerator()
                            gen.notificationOccurred(.success)
                        }
                        return moved
                    } isTargeted: { _ in }
                    .contextMenu {
                        Button {
                            selectedUrn = urn
                        } label: {
                            Label("열기", systemImage: "arrow.up.right.square")
                        }
                        Button(role: .destructive) {
                            reflectionManager.deleteUrn(id: urn.id)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
            }
        }
        .padding(.horizontal, 16)
    }

    private func urnCell(_ urn: Urn) -> some View {
        let count = reflectionManager.reflections(in: urn).count
        return VStack(spacing: 8) {
            MixedAshUrnVisual(
                urn: urn,
                fillLevel: reflectionManager.fillLevel(for: urn),
                counts: reflectionManager.categoryCounts(for: urn)
            )
            .frame(width: 100, height: 110)

            HStack(spacing: 4) {
                Text(urn.emoji)
                    .font(.system(size: 13))
                Text(urn.name)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundColor(.orange.opacity(0.88))
                    .lineLimit(1)
            }
            Text("\(count)개")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.orange.opacity(0.10), lineWidth: 1))
        )
    }

    // MARK: - Recent

    @ViewBuilder
    private var recentList: some View {
        let recent = Array(reflectionManager.reflections.prefix(6))
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("최근")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.horizontal, 16)

                VStack(spacing: 8) {
                    ForEach(recent) { item in
                        ReflectionRow(item: item,
                                      urn: reflectionManager.urns.first(where: { $0.id == item.urnId }))
                            .draggable(item.id.uuidString) {
                                ReflectionRow(
                                    item: item,
                                    urn: reflectionManager.urns.first(where: { $0.id == item.urnId })
                                )
                                .opacity(0.85)
                                .frame(maxWidth: 280)
                            }
                            .onTapGesture { editing = item }
                            .contextMenu {
                                Button(role: .destructive) {
                                    reflectionManager.delete(id: item.id)
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)

                Text("회고를 항아리로 끌어다 옮길 수 있어요")
                    .font(.system(size: 10, design: .serif))
                    .foregroundColor(.gray.opacity(0.4))
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Floating Action

    private var floatingActions: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if !reflectionManager.urns.isEmpty {
                    Button { showInput = true } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [Color.orange, Color(red: 0.85, green: 0.40, blue: 0.20)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ))
                            )
                            .shadow(color: .orange.opacity(0.35), radius: 14, y: 4)
                    }
                    .padding(.trailing, 22)
                    .padding(.bottom, 22)
                    .accessibilityLabel("새 회고 적기")
                }
            }
        }
    }
}

// MARK: - Reflection Row

struct ReflectionRow: View {
    let item: DayReflection
    let urn: Urn?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(rowDotColor)
                .frame(width: 7, height: 7)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.text)
                    .font(.system(size: 14, design: .serif))
                    .foregroundColor(.orange.opacity(0.88))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    if let urn {
                        Text("\(urn.emoji) \(urn.name)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange.opacity(0.65))
                    }
                    if item.category != .uncategorized {
                        Text(item.category.shortLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(rowDotColor)
                    }
                    Text(item.dateString)
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.45))
                    if let kw = item.keyword, !kw.isEmpty {
                        Text("#\(kw)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange.opacity(0.7))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(Capsule().fill(Color.orange.opacity(0.10)))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
        )
    }

    private var rowDotColor: Color {
        let c = item.category.particleColor
        return Color(red: c.0, green: c.1, blue: c.2)
    }
}

// MARK: - Urn Detail

struct UrnDetailView: View {
    @EnvironmentObject var reflectionManager: ReflectionManager
    @Environment(\.dismiss) private var dismiss
    let urn: Urn
    var onEdit: (DayReflection) -> Void

    @State private var showEditUrn = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.06, blue: 0.04).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        MixedAshUrnVisual(
                            urn: urn,
                            fillLevel: reflectionManager.fillLevel(for: urn),
                            counts: reflectionManager.categoryCounts(for: urn)
                        )
                        .frame(width: 180, height: 200)
                        .padding(.top, 8)

                        countsBreakdown

                        let items = reflectionManager.reflections(in: urn)
                        if items.isEmpty {
                            Text("아직 비어 있어요.")
                                .font(.system(size: 13))
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.top, 12)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(items) { item in
                                    ReflectionRow(item: item, urn: urn)
                                        .onTapGesture {
                                            dismiss()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                onEdit(item)
                                            }
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                reflectionManager.delete(id: item.id)
                                            } label: {
                                                Label("삭제", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("\(urn.emoji) \(urn.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") { dismiss() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showEditUrn = true
                        } label: {
                            Label("이름 변경", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            reflectionManager.deleteUrn(id: urn.id)
                            dismiss()
                        } label: {
                            Label("항아리 삭제", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditUrn) {
            UrnEditView(editing: urn)
                .environmentObject(reflectionManager)
        }
    }

    private var countsBreakdown: some View {
        let counts = reflectionManager.categoryCounts(for: urn)
        return HStack(spacing: 8) {
            ForEach([ReflectionCategory.forged, .missed, .stop, .accept, .scattered], id: \.self) { cat in
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color(red: cat.particleColor.0, green: cat.particleColor.1, blue: cat.particleColor.2))
                        .frame(width: 10, height: 10)
                    Text("\(counts[cat] ?? 0)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.orange.opacity(0.85))
                    Text(cat.shortLabel)
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.55))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.025))
                )
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Urn Edit

struct UrnEditView: View {
    @EnvironmentObject var reflectionManager: ReflectionManager
    @Environment(\.dismiss) private var dismiss

    let editing: Urn?

    @State private var name: String = ""
    @State private var emoji: String = "🏺"
    @FocusState private var focused: Bool

    private let emojis = ["🏺", "🔥", "🌱", "💪", "📚", "💼", "❤️", "🎯", "🏃", "✍️", "🧘", "🎨", "🎵", "💡", "🌙", "⭐️"]

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.06, blue: 0.04).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(editing == nil ? "새 항아리" : "항아리 수정")
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                            .foregroundColor(.orange.opacity(0.9))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("이모지")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray.opacity(0.6))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(emojis, id: \.self) { e in
                                        Button { emoji = e } label: {
                                            Text(e)
                                                .font(.system(size: 24))
                                                .padding(8)
                                                .background(
                                                    Circle().fill(emoji == e
                                                        ? Color.orange.opacity(0.2)
                                                        : Color.white.opacity(0.05))
                                                )
                                                .overlay(
                                                    Circle().stroke(emoji == e
                                                        ? Color.orange.opacity(0.5)
                                                        : Color.clear, lineWidth: 2)
                                                )
                                        }
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("이름")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray.opacity(0.6))
                            TextField("예: 운동, 관계, 올해의 도전", text: $name)
                                .font(.system(size: 16))
                                .foregroundColor(.orange.opacity(0.9))
                                .focused($focused)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.04))
                                        .overlay(RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.orange.opacity(0.15), lineWidth: 1))
                                )
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editing == nil ? "만들기" : "저장") { save() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(canSave ? .orange : .gray)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear {
            if let e = editing {
                name = e.name
                emoji = e.emoji
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                focused = true
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if var e = editing {
            e.name = trimmed
            e.emoji = emoji
            reflectionManager.updateUrn(e)
        } else {
            reflectionManager.createUrn(name: trimmed, emoji: emoji)
        }
        dismiss()
    }
}

// MARK: - Input View

struct ReflectionInputView: View {
    @EnvironmentObject var reflectionManager: ReflectionManager
    @Environment(\.dismiss) private var dismiss

    let existing: DayReflection?

    @State private var text: String = ""
    @State private var keyword: String = ""
    @State private var tomorrowIntent: String = ""
    @State private var date: Date = Date()
    @State private var selectedUrnId: UUID? = nil
    @State private var hasIntent: Bool? = nil
    @State private var spentTime: Bool? = nil
    @State private var driftFeeling: DriftFeeling? = nil
    @State private var currentStep: InputStep = .text
    @State private var sheetDetent: PresentationDetent = .height(460)
    @State private var savedReflectionId: UUID? = nil
    @State private var saveStatus: SaveStatus = .idle
    @State private var saveWorkItem: DispatchWorkItem? = nil
    @State private var classificationPoint: CGPoint? = nil
    @FocusState private var focusedField: FocusField?

    private enum SaveStatus { case idle, scheduled, saved }
    private enum InputStep: Int, CaseIterable { case text = 0, category, tomorrow }
    private enum FocusField: Hashable { case body, keepAlive, tomorrow }

    private func focusField(for step: InputStep) -> FocusField {
        switch step {
        case .text: return .body
        case .category: return .keepAlive
        case .tomorrow: return .tomorrow
        }
    }

    @State private var showCreateUrn = false

    private let suggestions = ["성장", "감사", "도전", "휴식", "배움", "관계", "실수", "기쁨"]

    init(existing: DayReflection?) {
        self.existing = existing
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.08, green: 0.06, blue: 0.04).ignoresSafeArea()

            // 키보드를 step 사이에 끊김 없이 같은 자리에 잡아두기 위한 invisible 필드.
            // step 2(분류 그래프)에서는 사용자 입력 영역이 없지만 이 필드가 활성이라 키보드 유지.
            TextField("keep-alive", text: .constant(""))
                .focused($focusedField, equals: .keepAlive)
                .frame(width: 1, height: 1)
                .opacity(0.001)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                chromeBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        stepContent
                            .padding(.horizontal, 22)
                            .padding(.top, 4)
                            .id(currentStep)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))

                        HStack {
                            if currentStep == .tomorrow {
                                newEntryButton
                                Spacer()
                                closeButton
                            } else {
                                Spacer()
                                nextButton
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 6)

                        stepDots
                            .padding(.top, 2)

                        if existing != nil && currentStep == .text {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("날짜")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray.opacity(0.55))
                                DatePicker("", selection: $date, displayedComponents: [.date])
                                    .datePickerStyle(.compact)
                                    .colorScheme(.dark)
                                    .tint(.orange)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 22)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $showCreateUrn) {
            UrnEditView(editing: nil)
                .environmentObject(reflectionManager)
        }
        .presentationDetents(detentSet, selection: $sheetDetent)
        .presentationDragIndicator(.visible)
        .onAppear { setup() }
        .onDisappear { flushPendingSave() }
        .onChange(of: text) { _ in scheduleAutoSave() }
        .onChange(of: keyword) { _ in scheduleAutoSave() }
        .onChange(of: tomorrowIntent) { _ in scheduleAutoSave() }
        .onChange(of: hasIntent) { _ in scheduleAutoSave() }
        .onChange(of: spentTime) { _ in scheduleAutoSave() }
        .onChange(of: driftFeeling) { _ in scheduleAutoSave() }
        .onChange(of: selectedUrnId) { _ in scheduleAutoSave() }
        .onChange(of: classificationPoint) { _ in scheduleAutoSave() }
    }

    private var detentSet: Set<PresentationDetent> {
        [.height(340), .large]
    }

    // MARK: - Chrome Bar (작은 상단)

    private var chromeBar: some View {
        HStack {
            Button {
                flushPendingSave()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.75))
                    .frame(width: 38, height: 38)
            }
            .accessibilityLabel("닫기 — 지금까지 적은 내용은 저장됩니다")

            Spacer()

            saveIndicator
                .padding(.trailing, 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var saveIndicator: some View {
        switch saveStatus {
        case .idle:
            // 비어 있을 때 — 자리를 잡고 있되 거의 안 보이게
            HStack(spacing: 5) {
                Image(systemName: "circle.dotted")
                    .font(.system(size: 15))
                Text("자동 저장")
                    .font(.system(size: 11, design: .serif))
            }
            .foregroundColor(.gray.opacity(0.35))
            .accessibilityLabel("아직 적힌 내용이 없습니다")

        case .scheduled:
            HStack(spacing: 5) {
                Image(systemName: "circle.dotted")
                    .font(.system(size: 15))
                Text("저장 중…")
                    .font(.system(size: 11, design: .serif))
            }
            .foregroundColor(.orange.opacity(0.7))
            .accessibilityLabel("저장 중")

        case .saved:
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                Text("저장됨")
                    .font(.system(size: 11, weight: .medium, design: .serif))
            }
            .foregroundColor(Color(red: 0.30, green: 0.78, blue: 0.42))
            .accessibilityLabel("저장됨")
        }
    }

    // MARK: - Wizard Steps

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .text:
            textEditor
        case .category:
            classificationSection
        case .tomorrow:
            tomorrowIntentSection
        }
    }

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(InputStep.allCases, id: \.rawValue) { step in
                Button {
                    goTo(step)
                } label: {
                    Circle()
                        .fill(step == currentStep ? Color.orange : Color.orange.opacity(0.18))
                        .frame(width: step == currentStep ? 8 : 5,
                               height: step == currentStep ? 8 : 5)
                }
                .accessibilityLabel(accessibilityLabel(for: step))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func accessibilityLabel(for step: InputStep) -> String {
        switch step {
        case .text: return "본문 단계"
        case .category: return "분류 단계"
        case .tomorrow: return "내일 메모 단계"
        }
    }

    private var nextButton: some View {
        Button {
            advance()
        } label: {
            HStack(spacing: 6) {
                Text(nextLabel)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                Image(systemName: nextIcon)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(canAdvance ? .white : .gray.opacity(0.4))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(canAdvance ? Color.orange.opacity(0.85) : Color.white.opacity(0.04))
            )
        }
        .disabled(!canAdvance)
        .accessibilityLabel(nextLabel)
        .accessibilityHint(nextHint)
    }

    /// .tomorrow step 좌측 — 현재 입력을 저장하고 새 회고 시작
    private var newEntryButton: some View {
        Button {
            startNewEntry()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 11, weight: .semibold))
                Text("새 회고")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
            }
            .foregroundColor(canAdvance ? .orange.opacity(0.9) : .gray.opacity(0.4))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        Capsule().stroke(
                            canAdvance ? Color.orange.opacity(0.45) : Color.orange.opacity(0.15),
                            lineWidth: 1
                        )
                    )
            )
        }
        .disabled(!canAdvance)
        .accessibilityLabel("새 회고")
        .accessibilityHint("지금까지 적은 회고를 저장하고 빈 입력칸으로 넘어갑니다")
    }

    /// .tomorrow step 우측 — 시트를 닫고 마침
    private var closeButton: some View {
        Button {
            flushPendingSave()
            dismiss()
        } label: {
            HStack(spacing: 6) {
                Text("닫기")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(Color.orange.opacity(0.85))
            )
        }
        .accessibilityLabel("닫기")
        .accessibilityHint("저장하고 시트를 닫습니다")
    }

    private var nextLabel: String {
        currentStep == .tomorrow ? "새 회고" : "다음"
    }

    private var nextIcon: String {
        currentStep == .tomorrow ? "plus.circle" : "arrow.right"
    }

    private var nextHint: String {
        switch currentStep {
        case .text:     return "본문을 저장하고 분류 단계로 이동합니다"
        case .category: return "분류를 저장하고 내일 메모 단계로 이동합니다"
        case .tomorrow: return "저장하고 새 회고를 시작합니다"
        }
    }

    private var canAdvance: Bool {
        // text 단계에서만 본문 필수. 나머지는 비워두고 건너뛰기 가능.
        if currentStep == .text {
            return !trimmed.isEmpty && selectedUrnId != nil
        }
        return selectedUrnId != nil
    }

    private func advance() {
        flushPendingSave()

        if let next = InputStep(rawValue: currentStep.rawValue + 1) {
            let gen = UISelectionFeedbackGenerator()
            gen.selectionChanged()
            // 키보드를 같은 자리에 유지하기 위해 transition 전에 다음 step의 focus로 미리 전환
            focusedField = focusField(for: next)
            withAnimation(.easeInOut(duration: 0.22)) {
                currentStep = next
            }
        } else {
            // .tomorrow → 새 회고
            startNewEntry()
        }
    }

    private func goTo(_ step: InputStep) {
        guard step != currentStep else { return }
        flushPendingSave()
        let gen = UISelectionFeedbackGenerator()
        gen.selectionChanged()
        focusedField = focusField(for: step)
        withAnimation(.easeInOut(duration: 0.22)) {
            currentStep = step
        }
    }

    private func startNewEntry() {
        flushPendingSave()

        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)

        withAnimation(.easeInOut(duration: 0.2)) {
            text = ""
            keyword = ""
            tomorrowIntent = ""
            hasIntent = nil
            spentTime = nil
            driftFeeling = nil
            classificationPoint = nil
            currentStep = .text
        }

        savedReflectionId = nil
        saveStatus = .idle

        focusedField = .body
    }

    // MARK: - Sections

    private var textEditor: some View {
        TextField(
            existing == nil ? "오늘 하루, 한 줄로 남겨봐요." : "회고를 수정합니다.",
            text: $text,
            axis: .vertical
        )
        .lineLimit(1...8)
        .focused($focusedField, equals: .body)
        .font(.system(size: 20, design: .serif))
        .foregroundColor(.orange.opacity(0.95))
        .tint(.orange)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(focusedField == .body ? 0.35 : 0.18), lineWidth: 1)
                )
        )
    }

    // MARK: - Urn Hint (작은 라벨)

    @ViewBuilder
    private var urnHintLabel: some View {
        if let urn = reflectionManager.urns.first(where: { $0.id == selectedUrnId }) {
            Button {
                // 현재 입력한 옵션이 어디까지인지 한눈에 볼 수 있게 본문 단계로 돌아감
                goTo(.text)
            } label: {
                HStack(spacing: 6) {
                    Text(urn.emoji).font(.system(size: 13))
                    Text(urn.name)
                        .font(.system(size: 13, weight: .medium, design: .serif))

                    if let cat = previewCategory {
                        let rgb = cat.particleColor
                        Circle()
                            .fill(Color(red: rgb.0, green: rgb.1, blue: rgb.2))
                            .frame(width: 6, height: 6)
                    }
                    if !keyword.isEmpty {
                        Text("#")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    if !tomorrowIntent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Image(systemName: "sunrise")
                            .font(.system(size: 10))
                    }
                }
                .foregroundColor(.orange.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.04))
                        .overlay(Capsule().stroke(Color.orange.opacity(0.22), lineWidth: 1))
                )
            }
            .accessibilityLabel("\(urn.name) 항아리")
            .accessibilityHint("탭하여 본문 단계로 돌아감")
        }
    }

    private var urnPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("어느 항아리에 담을까요?")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray.opacity(0.55))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(reflectionManager.urns) { urn in
                        Button {
                            selectedUrnId = urn.id
                        } label: {
                            HStack(spacing: 5) {
                                Text(urn.emoji).font(.system(size: 14))
                                Text(urn.name)
                                    .font(.system(size: 13, weight: selectedUrnId == urn.id ? .semibold : .regular))
                            }
                            .foregroundColor(selectedUrnId == urn.id ? .orange : .gray.opacity(0.65))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                Capsule()
                                    .fill(selectedUrnId == urn.id
                                          ? Color.orange.opacity(0.15)
                                          : Color.white.opacity(0.04))
                                    .overlay(Capsule().stroke(selectedUrnId == urn.id
                                        ? Color.orange.opacity(0.45)
                                        : Color.orange.opacity(0.10), lineWidth: 1))
                            )
                        }
                    }
                    Button { showCreateUrn = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                            Text("새 항아리")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.03))
                                .overlay(Capsule().stroke(Color.gray.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3])))
                        )
                    }
                }
            }
        }
    }

    private var classificationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더 자리에 안내 또는 카테고리 미리보기 — 그래프 아래엔 아무것도 추가 안 함
            classificationHeader

            ClassificationGraph(
                point: $classificationPoint,
                onPick: applyClassificationPoint
            )
            .frame(height: 220)
        }
    }

    @ViewBuilder
    private var classificationHeader: some View {
        if let cat = previewCategory {
            HStack(spacing: 6) {
                let rgb = cat.particleColor
                Circle()
                    .fill(Color(red: rgb.0, green: rgb.1, blue: rgb.2))
                    .frame(width: 9, height: 9)
                Text("→ \(cat.title)")
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundColor(.orange.opacity(0.85))
            }
        } else {
            Text("오늘은 어떤 하루였나요? — 콕 찍어보세요")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray.opacity(0.6))
        }
    }

    private func applyClassificationPoint(_ p: CGPoint) {
        hasIntent = p.x > 0.5
        spentTime = p.y > 0.5
        // 좌상 분면 (의지❌ 시간⭕️)은 accept 고정.  stop은 신규 작성에서 더 이상 만들어지지 않음.
        driftFeeling = (p.x < 0.5 && p.y > 0.5) ? .accept : nil
    }

    private func classificationToggle(title: String,
                                      yesLabel: String,
                                      noLabel: String,
                                      value: Binding<Bool?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.orange.opacity(0.75))
            HStack(spacing: 8) {
                togglePill(label: yesLabel, isOn: value.wrappedValue == true) { value.wrappedValue = true }
                togglePill(label: noLabel,  isOn: value.wrappedValue == false) { value.wrappedValue = false }
            }
        }
    }

    private func togglePill(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isOn ? .semibold : .regular))
                .foregroundColor(isOn ? .orange : .gray.opacity(0.65))
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(isOn ? Color.orange.opacity(0.15) : Color.white.opacity(0.04))
                        .overlay(Capsule().stroke(isOn ? Color.orange.opacity(0.45) : Color.orange.opacity(0.10), lineWidth: 1))
                )
        }
    }

    private var keywordSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("키워드 (선택)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray.opacity(0.55))

            TextField("", text: $keyword)
                .font(.system(size: 14))
                .foregroundColor(.orange.opacity(0.9))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.orange.opacity(0.15), lineWidth: 1))
                )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { s in
                        Button { keyword = s } label: {
                            Text("#\(s)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(keyword == s ? .orange : .gray.opacity(0.6))
                                .padding(.vertical, 5)
                                .padding(.horizontal, 10)
                                .background(
                                    Capsule().fill(keyword == s
                                        ? Color.orange.opacity(0.15)
                                        : Color.white.opacity(0.05))
                                )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tomorrow Intent

    private var tomorrowIntentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sunrise")
                    .font(.system(size: 11))
                    .foregroundColor(.orange.opacity(0.7))
                Text(tomorrowQuestion)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.65))
            }

            TextField(tomorrowPlaceholder, text: $tomorrowIntent)
                .font(.system(size: 14, design: .serif))
                .foregroundColor(.orange.opacity(0.9))
                .focused($focusedField, equals: .tomorrow)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.orange.opacity(0.18), lineWidth: 1))
                )

            Text("내일 아침, 양피지 상단에 띠로 떠올라 하루와 함께 타들어가요.")
                .font(.system(size: 10))
                .foregroundColor(.gray.opacity(0.45))
        }
    }

    /// 사용자가 그래프에서 찍은 분류에 따라 "내일 어떻게?" 질문 자체가 달라짐.
    private var tomorrowQuestion: String {
        guard let cat = previewCategory else { return "내일 어떻게 해볼까요?" }
        switch cat {
        case .forged:    return "더 잘 하려면 내일 무엇을 할까요?"
        case .missed:    return "내일 새롭게 어떤 걸 시도해볼까요?"
        case .accept:    return "이 시간을 내일은 어떻게 다룰까요?"
        case .stop:      return "내일은 무엇을 끊어낼까요?"
        case .scattered: return "내일은 어떻게 다르게 보낼까요?"
        case .uncategorized: return "내일 어떻게 해볼까요?"
        }
    }

    private var tomorrowPlaceholder: String {
        guard let cat = previewCategory else { return "예: 점심 직후 운동 30분" }
        switch cat {
        case .forged:    return "예: 운동 시간을 30분 늘리기"
        case .missed:    return "예: 점심 직후 운동 30분"
        case .accept:    return "예: 산책 20분으로 바꾸기"
        case .stop:      return "예: SNS 사용 15분 제한"
        case .scattered: return "예: 책 한 챕터 읽기"
        case .uncategorized: return "예: 점심 직후 운동 30분"
        }
    }

    // MARK: - Helpers

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var previewCategory: ReflectionCategory? {
        guard let i = hasIntent, let t = spentTime else { return nil }
        switch (i, t) {
        case (true, true):   return .forged
        case (true, false):  return .missed
        case (false, true):  return nil  // 분기 필요 (stop/accept)
        case (false, false): return .scattered
        }
    }

    private var canSave: Bool {
        guard !trimmed.isEmpty else { return false }
        guard selectedUrnId != nil else { return false }
        return true
    }

    private func setup() {
        if let e = existing {
            text = e.text
            keyword = e.keyword ?? ""
            date = e.date
            selectedUrnId = e.urnId
            switch e.category {
            case .forged:    hasIntent = true;  spentTime = true
            case .missed:    hasIntent = true;  spentTime = false
            case .stop:      hasIntent = false; spentTime = true; driftFeeling = .stop
            case .accept:    hasIntent = false; spentTime = true; driftFeeling = .accept
            case .scattered: hasIntent = false; spentTime = false
            case .uncategorized: break
            }
            tomorrowIntent = e.tomorrowIntent ?? ""
            savedReflectionId = e.id
            saveStatus = .saved
            // 저장된 정확한 좌표가 있으면 그걸 복원.  없으면 카테고리에서 분면 대표 좌표로 역산.
            if let saved = e.classificationPoint {
                classificationPoint = saved
            } else {
                switch e.category {
                case .forged:    classificationPoint = CGPoint(x: 0.75, y: 0.75)
                case .missed:    classificationPoint = CGPoint(x: 0.75, y: 0.25)
                case .stop, .accept:
                                    classificationPoint = CGPoint(x: 0.25, y: 0.75)
                case .scattered: classificationPoint = CGPoint(x: 0.25, y: 0.25)
                case .uncategorized: classificationPoint = nil
                }
            }
        } else {
            date = Date()
            if reflectionManager.urns.count == 1 {
                selectedUrnId = reflectionManager.urns.first?.id
            } else if let first = reflectionManager.urns.first {
                selectedUrnId = first.id
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            focusedField = focusField(for: currentStep)
        }
    }


    // MARK: - Autosave

    private func canAutoSave() -> Bool {
        guard !trimmed.isEmpty, selectedUrnId != nil else { return false }
        // 분류가 (의지❌, 시간⭕️)인데 drift 미선택이면 카테고리 확정 불가 → 저장 보류
        if hasIntent == false, spentTime == true, driftFeeling == nil {
            return false
        }
        return true
    }

    private func scheduleAutoSave() {
        saveWorkItem?.cancel()

        guard canAutoSave() else {
            // 텍스트가 비어 있거나 조건 미충족이면 인디케이터를 idle로 되돌림
            // 단, 이미 저장된 회고가 있고 사용자가 더 입력 중이면 saved 상태 유지
            if savedReflectionId == nil {
                saveStatus = .idle
            }
            return
        }

        saveStatus = .scheduled
        let work = DispatchWorkItem { performAutoSave() }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
    }

    private func flushPendingSave() {
        // 시트가 닫히거나 명시적 flush가 필요할 때 debounce를 건너뛰고 즉시 저장
        saveWorkItem?.cancel()
        saveWorkItem = nil
        guard canAutoSave() else { return }
        performAutoSave()
    }

    private func performAutoSave() {
        guard let urnId = selectedUrnId, !trimmed.isEmpty else { return }

        let cat: ReflectionCategory = {
            if let i = hasIntent, let t = spentTime,
               let resolved = ReflectionCategory.from(intent: i, spentTime: t, drift: driftFeeling) {
                return resolved
            }
            return .uncategorized
        }()

        let trimmedIntent = tomorrowIntent.trimmingCharacters(in: .whitespacesAndNewlines)
        let intentToSave: String? = trimmedIntent.isEmpty ? nil : trimmedIntent
        let kw = keyword.isEmpty ? nil : keyword

        if let id = savedReflectionId,
           let existingRec = reflectionManager.reflections.first(where: { $0.id == id }) {
            // 이미 저장된 회고를 갱신
            var updated = existingRec
            updated.text = trimmed
            updated.urnId = urnId
            updated.category = cat
            updated.keyword = kw
            updated.tomorrowIntent = intentToSave
            updated.classificationPoint = classificationPoint
            updated.date = DayReflection.normalize(date)
            reflectionManager.update(updated)
        } else {
            // 새 회고 생성
            let created = reflectionManager.add(
                text: trimmed,
                urnId: urnId,
                category: cat,
                keyword: keyword,
                tomorrowIntent: intentToSave,
                classificationPoint: classificationPoint,
                date: date
            )
            savedReflectionId = created.id
        }

        saveStatus = .saved
    }
}

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
                quadrants(size: s)
                quadrantLabels(size: s)
                axisLines(size: s)
                axisLabels(size: s)

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
            .accessibilityHint("두 축에 따라 손가락으로 콕 찍어 분류합니다")
        }
    }

    private func quadrants(size: CGFloat) -> some View {
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
                .stroke(Color.orange.opacity(0.20), lineWidth: 1)
                .frame(width: size, height: size)
        )
    }

    private func axisLines(size: CGFloat) -> some View {
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
            .stroke(Color.orange.opacity(0.10), style: StrokeStyle(lineWidth: 0.4, dash: [1, 3]))

            // 4분면 주축 — 더 진하게
            Path { p in
                p.move(to: CGPoint(x: size / 2, y: 0))
                p.addLine(to: CGPoint(x: size / 2, y: size))
                p.move(to: CGPoint(x: 0, y: size / 2))
                p.addLine(to: CGPoint(x: size, y: size / 2))
            }
            .stroke(Color.orange.opacity(0.22), style: StrokeStyle(lineWidth: 0.6, dash: [3, 3]))
        }
    }

    private func quadrantLabels(size: CGFloat) -> some View {
        ZStack {
            // 우상: forged — 잘 하고 있어
            quadrantLabel("잘 하고 있어",
                          rgb: (0.92, 0.55, 0.25),
                          at: CGPoint(x: size * 0.74, y: size * 0.32))
            // 좌상: accept — 의지 없이 시간만 들였음
            quadrantLabel("받아들임",
                          rgb: (0.95, 0.78, 0.42),
                          at: CGPoint(x: size * 0.26, y: size * 0.32))
            // 우하: missed — 의지는 있는데 시간을 못 냈음
            quadrantLabel("못 하고 있어",
                          rgb: (0.78, 0.66, 0.46),
                          at: CGPoint(x: size * 0.74, y: size * 0.68))
            // 좌하: scattered — 흘려보낸 시간
            quadrantLabel("흘려보냄",
                          rgb: (0.72, 0.70, 0.66),
                          at: CGPoint(x: size * 0.26, y: size * 0.68))
        }
        .allowsHitTesting(false)
    }

    private func quadrantLabel(_ text: String,
                               rgb: (Double, Double, Double),
                               at: CGPoint) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .serif))
            .foregroundColor(Color(red: rgb.0, green: rgb.1, blue: rgb.2).opacity(0.85))
            .position(at)
    }

    private func axisLabels(size: CGFloat) -> some View {
        ZStack {
            Text("시간을 들였다")
                .font(.system(size: 10, design: .serif))
                .foregroundColor(.gray.opacity(0.7))
                .position(x: size / 2, y: 12)

            Text("시간을 안 들였다")
                .font(.system(size: 10, design: .serif))
                .foregroundColor(.gray.opacity(0.7))
                .position(x: size / 2, y: size - 12)

            Text("의지\n없음")
                .font(.system(size: 10, design: .serif))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .position(x: 22, y: size / 2)

            Text("의지\n있음")
                .font(.system(size: 10, design: .serif))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .position(x: size - 22, y: size / 2)
        }
    }

    private var pinView: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.35))
                .frame(width: 28, height: 28)
                .blur(radius: 4)
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.orange, lineWidth: 2.5))
                .shadow(color: .orange.opacity(0.6), radius: 4)
        }
    }
}

#Preview {
    ReflectionUrnView()
        .environmentObject(ReflectionManager())
        .preferredColorScheme(.dark)
}
