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

            // 4색 입자 — 카테고리별 개수에 비례
            Canvas { ctx, cSize in
                let baseSeed = UInt64(truncatingIfNeeded: urn.id.uuidString.hashValue)
                var rng = SeededRNG(seed: baseSeed == 0 ? 0xDEADBEEF : baseSeed)

                // 카테고리별로 그릴 입자 개수 (회고 1개 = 입자 약 4개)
                let categoriesInOrder: [ReflectionCategory] = [.forged, .accept, .missed, .stop, .uncategorized]
                for cat in categoriesInOrder {
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
                    .contextMenu {
                        Button {
                            // 편집은 UrnDetailView 안에서. 여기선 빠른 액션만.
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
        return HStack(spacing: 10) {
            ForEach([ReflectionCategory.forged, .missed, .stop, .accept], id: \.self) { cat in
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
    @State private var date: Date = Date()
    @State private var selectedUrnId: UUID? = nil
    @State private var hasIntent: Bool? = nil
    @State private var spentTime: Bool? = nil
    @State private var driftFeeling: DriftFeeling? = nil
    @FocusState private var focused: Bool

    @State private var showDriftBranchAlert = false
    @State private var showSkipNotice = false
    @State private var showCreateUrn = false

    private let suggestions = ["성장", "감사", "도전", "휴식", "배움", "관계", "실수", "기쁨"]

    init(existing: DayReflection?) {
        self.existing = existing
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.06, blue: 0.04).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(existing == nil ? "오늘을 보내고 얻은 것, 얻지 못 한 것은 무엇인가요?" : "회고 수정")
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                            .foregroundColor(.orange.opacity(0.9))
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        textEditor.padding(.horizontal, 20)

                        urnPicker.padding(.horizontal, 20)

                        classificationSection.padding(.horizontal, 20)

                        keywordSection.padding(.horizontal, 20)

                        if existing != nil {
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
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("담기") { trySave() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(canSave ? .orange : .gray)
                        .disabled(!canSave)
                }
            }
            .alert("의지 없이 흘러간 시간이네요", isPresented: $showDriftBranchAlert) {
                Button("그만둘 것") {
                    driftFeeling = .stop
                    finalizeSave()
                }
                Button("받아들일 것") {
                    driftFeeling = .accept
                    finalizeSave()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("이 시간을 어떻게 받아들일까요?")
            }
            .alert("그냥 흘러간 시간", isPresented: $showSkipNotice) {
                Button("닫기") { dismiss() }
            } message: {
                Text("원하지도, 시간을 들이지도 않은 일은 항아리에 담기지 않아요. 그냥 양피지와 함께 타버린 시간이에요.")
            }
        }
        .sheet(isPresented: $showCreateUrn) {
            UrnEditView(editing: nil)
                .environmentObject(reflectionManager)
        }
        .onAppear { setup() }
    }

    // MARK: - Sections

    private var textEditor: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("한 줄로 남겨보세요. 한 일, 배운 것, 후회 무엇이든 좋아요.")
                    .font(.system(size: 15, design: .serif))
                    .foregroundColor(.gray.opacity(0.35))
                    .padding(16)
            }
            TextEditor(text: $text)
                .focused($focused)
                .font(.system(size: 15, design: .serif))
                .foregroundColor(.orange.opacity(0.92))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(10)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.18), lineWidth: 1))
        )
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
        VStack(alignment: .leading, spacing: 12) {
            Text("어떤 재가 될까요?")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray.opacity(0.55))

            classificationToggle(
                title: "원해서 한 일이었나요?",
                yesLabel: "원했어요",
                noLabel: "그냥 흘렀어요",
                value: $hasIntent
            )

            classificationToggle(
                title: "시간을 들였나요?",
                yesLabel: "들였어요",
                noLabel: "안 들였어요",
                value: $spentTime
            )

            if let cat = previewCategory {
                HStack(spacing: 8) {
                    let rgb = cat.particleColor
                    Circle()
                        .fill(Color(red: rgb.0, green: rgb.1, blue: rgb.2))
                        .frame(width: 10, height: 10)
                    Text("→ \(cat.title)")
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(.orange.opacity(0.85))
                }
                .padding(.top, 4)
            } else if hasIntent == false && spentTime == false {
                Text("→ 항아리에 담기지 않아요 (그냥 흘러간 시간)")
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(.gray.opacity(0.55))
                    .padding(.top, 4)
            } else if hasIntent == false && spentTime == true {
                Text("→ 담을 때 \"그만둘 것 / 받아들일 것\"을 여쭤볼게요")
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(.gray.opacity(0.55))
                    .padding(.top, 4)
            }
        }
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

    // MARK: - Helpers

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var previewCategory: ReflectionCategory? {
        guard let i = hasIntent, let t = spentTime else { return nil }
        switch (i, t) {
        case (true, true):   return .forged
        case (true, false):  return .missed
        case (false, true):  return nil  // 분기 필요
        case (false, false): return nil
        }
    }

    private var canSave: Bool {
        guard !trimmed.isEmpty else { return false }
        guard selectedUrnId != nil else { return false }
        guard hasIntent != nil, spentTime != nil else { return false }
        return true
    }

    private func setup() {
        if let e = existing {
            text = e.text
            keyword = e.keyword ?? ""
            date = e.date
            selectedUrnId = e.urnId
            switch e.category {
            case .forged: hasIntent = true;  spentTime = true
            case .missed: hasIntent = true;  spentTime = false
            case .stop:   hasIntent = false; spentTime = true; driftFeeling = .stop
            case .accept: hasIntent = false; spentTime = true; driftFeeling = .accept
            case .uncategorized: break
            }
        } else {
            date = Date()
            // 항아리가 1개면 자동 선택
            if reflectionManager.urns.count == 1 {
                selectedUrnId = reflectionManager.urns.first?.id
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            focused = true
        }
    }

    private func trySave() {
        guard !trimmed.isEmpty, let urnId = selectedUrnId else { return }
        guard let intent = hasIntent, let time = spentTime else { return }

        switch (intent, time) {
        case (true, true), (true, false):
            finalizeSave()
        case (false, true):
            if driftFeeling == nil {
                showDriftBranchAlert = true
            } else {
                finalizeSave()
            }
        case (false, false):
            showSkipNotice = true
        }
        _ = urnId  // silence warning
    }

    private func finalizeSave() {
        guard let urnId = selectedUrnId,
              let cat = ReflectionCategory.from(
                intent: hasIntent ?? false,
                spentTime: spentTime ?? false,
                drift: driftFeeling)
        else { return }

        if let e = existing {
            var updated = e
            updated.text = trimmed
            updated.urnId = urnId
            updated.category = cat
            updated.keyword = keyword.isEmpty ? nil : keyword
            updated.date = DayReflection.normalize(date)
            reflectionManager.update(updated)
        } else {
            reflectionManager.add(text: trimmed, urnId: urnId, category: cat, keyword: keyword, date: date)
        }
        dismiss()
    }
}

#Preview {
    ReflectionUrnView()
        .environmentObject(ReflectionManager())
        .preferredColorScheme(.dark)
}
