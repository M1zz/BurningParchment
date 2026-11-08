// UrnVisuals.swift
// 항아리 그림 · 날아가는 재 · 머리줄 항아리 단추. ReflectionUrnView.swift 에서 나눴다 — 한 파일이 3천 줄이면 한 줄을 고쳐도 통째로 다시 컴파일된다.

import SwiftUI
import LeeoKit

// MARK: - Mixed-Ash Urn Visual

/// 재가 쌓이는 항아리.  카테고리별 개수에 비례해 입자 수가 결정된다.
///
/// 의미가 부여되기 전(`hasMeaning == false`)에는 모든 입자가 잿빛 하나로만 그려진다 —
/// 무슨 재인지는 사용자가 적어주기 전까지 정해지지 않기 때문.
struct MixedAshUrnVisual: View {
    /// 입자 배치를 고정하는 씨앗 — 같은 항아리는 언제 열어봐도 같은 모양이다.
    let seed: String
    let fillLevel: Double
    let counts: [ReflectionCategory: Int]
    var hasMeaning: Bool = true

    /// 의미가 없는 항아리의 재 — 색이 아직 없는 그냥 재.
    private static let plainAsh: (Double, Double, Double) = (0.60, 0.58, 0.55)

    private func particleRGB(_ cat: ReflectionCategory) -> (Double, Double, Double) {
        hasMeaning ? cat.particleColor : Self.plainAsh
    }

    /// 의미가 붙기 전엔 문양도 식은 잿빛이다.
    private var engravingColor: Color {
        hasMeaning
            ? Color(red: 0.98, green: 0.72, blue: 0.32)
            : Color(red: 0.60, green: 0.58, blue: 0.55)
    }

    /// String.hashValue 는 실행마다 달라져 재 배치가 매번 바뀐다 — FNV-1a 로 고정한다.
    static func stableSeed(_ s: String) -> UInt64 {
        var h: UInt64 = 0xCBF29CE484222325
        for byte in s.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100000001B3
        }
        return h == 0 ? 0xDEADBEEF : h
    }

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
                    .overlay(UrnShape().stroke(Color.ember.opacity(0.3), lineWidth: 1))
                    .shadow(color: .ember.opacity(0.15), radius: 12)

                // 재 (안쪽 클립)
                ashLayer(in: size)
                    .clipShape(UrnInteriorShape())

                // 선각 문양 — 채울수록 진해지고 확장됨, 항아리 본체 위에만 보이게 클립
                UrnEngravingShape(fillLevel: fillLevel)
                    .stroke(
                        engravingColor.opacity((hasMeaning ? 0.20 : 0.12) + 0.55 * min(fillLevel, 1.0)),
                        style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(
                        color: Color.ember.opacity(hasMeaning && fillLevel >= 0.85 ? 0.45 : 0.0),
                        radius: hasMeaning && fillLevel >= 0.85 ? 3 : 0
                    )
                    .clipShape(UrnShape())
                    .allowsHitTesting(false)

                // 입구 빛
                UrnShape()
                    .stroke(Color.ember.opacity(0.55), lineWidth: 0.8)
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
        // 담긴 재가 한 톨도 없으면 바닥 한 줄도 그리지 않는다 — 빈 항아리는 정말 비어 보여야 한다.
        let hasAsh = counts.values.reduce(0, +) > 0
        let ashTopY = hasAsh
            ? interiorBottom - interiorHeight * CGFloat(max(0.04, fillLevel))
            : interiorBottom

        ZStack {
            // 빈 안쪽
            Rectangle().fill(Color.black.opacity(0.55))

            // 재 베이스 (입자들이 그 위에 올라감).  의미가 없으면 온기 없는 잿더미로 깔린다.
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: hasMeaning
                            ? [Color(red: 0.30, green: 0.22, blue: 0.16),
                               Color(red: 0.18, green: 0.12, blue: 0.08)]
                            : [Color(red: 0.24, green: 0.23, blue: 0.22),
                               Color(red: 0.13, green: 0.12, blue: 0.12)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(height: interiorBottom - ashTopY)
                .offset(y: (ashTopY + interiorBottom) / 2 - size.height / 2)

            // 4색 입자 — 카테고리별 개수에 비례 (바닥에 쌓임)
            Canvas { ctx, cSize in
                var rng = SeededRNG(seed: Self.stableSeed(seed))

                let settledOrder: [ReflectionCategory] = [.forged, .accept, .missed, .stop, .uncategorized]
                for cat in settledOrder {
                    let count = counts[cat] ?? 0
                    guard count > 0 else { continue }
                    let particles = min(count * 4, 60)
                    let rgb = particleRGB(cat)
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
                    let rgb = particleRGB(.scattered)
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

// MARK: - Ash Pile (날아가는 재)
// 아직 어느 항아리에도 담기지 않은 재 더미.  `blow` 를 0 → 1 로 애니메이션하면
// 입자들이 제각기 다른 시점에 떠올라 바람을 타고 오른쪽 위로 흩어지며 사라진다.
//
// Animatable 을 직접 채택해야 한다 — Canvas 에 넘긴 Double 은 그냥은 보간되지 않고 툭 튄다.

struct AshPile: View, Animatable {
    let seed: Double
    let count: Int
    var blow: Double

    var animatableData: Double {
        get { blow }
        set { blow = newValue }
    }

    /// 아직 이름 붙지 않은 재의 색 — 잿빛에서 아주 살짝 따뜻한 쪽까지.
    private static let palette: [(Double, Double, Double)] = [
        (0.62, 0.60, 0.57),
        (0.72, 0.68, 0.62),
        (0.55, 0.53, 0.51),
        (0.78, 0.66, 0.50)
    ]

    var body: some View {
        Canvas { ctx, size in
            let bits = UInt64(bitPattern: Int64(seed.rounded()))
            var rng = SeededRNG(seed: bits == 0 ? 0xA511_0000 : bits)

            for _ in 0..<count {
                // 바닥에 얕게 깔린 더미
                let x0 = CGFloat.random(in: 0...size.width, using: &rng)
                let y0 = size.height - CGFloat.random(in: 0...(size.height * 0.5), using: &rng)

                // 입자마다 다른 바람 — 뜨는 시점도, 실려가는 거리도 제각각이다.
                let delay  = Double.random(in: 0...0.45, using: &rng)
                let drift  = CGFloat.random(in: 0.5...2.4, using: &rng)
                let lift   = CGFloat.random(in: 0.4...2.6, using: &rng)
                let wobble = CGFloat.random(in: -1...1, using: &rng)
                let radius = CGFloat.random(in: 0.7...1.9, using: &rng)
                let baseAlpha = Double.random(in: 0.30...0.85, using: &rng)
                let rgb = Self.palette[Int.random(in: 0..<Self.palette.count, using: &rng)]

                let local = blow <= delay ? 0 : min(1, (blow - delay) / (1 - delay))
                // 처음엔 머뭇거리다 점점 빨라진다.
                let ease = local * local
                let x = x0 + size.width * drift * ease
                let y = y0
                      - size.height * lift * ease
                      + wobble * 5 * sin(local * .pi * 2.2)
                let alpha = baseAlpha * (1 - local)
                guard alpha > 0.02 else { continue }

                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                           width: radius * 2, height: radius * 2)),
                    with: .color(Color(red: rgb.0, green: rgb.1, blue: rgb.2).opacity(alpha))
                )
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

// MARK: - Header Mini Button

/// 헤더의 작은 항아리 — 지금 재가 담기고 있는 이번 주 항아리를 보여준다.
struct AshUrnButton: View {
    @EnvironmentObject var reflectionManager: ReflectionManager
    let action: () -> Void

    var body: some View {
        let period = reflectionManager.currentWeekPeriod
        let count = reflectionManager.reflectionCount(in: period)

        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                MixedAshUrnVisual(
                    seed: period.id,
                    fillLevel: reflectionManager.fillLevel(for: period),
                    counts: reflectionManager.categoryCounts(for: period),
                    hasMeaning: reflectionManager.hasMeaning(period)
                )
                .frame(width: 22, height: 24)

                if count > 0 {
                    Text("\(count)")
                        .scaledFont(size: 9, weight: .bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.ember))
                        .offset(x: 6, y: -2)
                }
            }
        }
        .accessibilityLabel("재 항아리")
        .accessibilityValue("\(period.title), 재 \(count)톨")
        .accessibilityHint("탭하여 항아리 열기")
        .accessibilityInputLabels([Text("재 항아리"), Text("항아리"), Text("회고")])
    }
}
