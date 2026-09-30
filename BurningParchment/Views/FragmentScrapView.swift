// FragmentScrapView.swift
// 불을 끄고 남은 양피지 조각만 떼어 그린다.
//
// 취침 30분 전이면 하루의 3% 남짓만 남아 있어서, 양피지 전체를 그리면 조각은 모서리의 점이 된다.
// 남은 모서리(왼쪽 위)의 모양만 가져와 뷰 크기에 맞춰 키워 그린다.
// 확대한 뒤에 선을 그으면 선 굵기와 요철까지 같이 커지므로, 모양은 화면 좌표에서 바로 만든다.

import SwiftUI

struct FragmentScrapView: View {
    let burnProgress: Double
    let edgePhase: Double
    /// 저절로 꺼진 조각 — 연기에 그을린 듯 전체가 한 톤 어둡다
    var smoked: Bool = false

    init(burnProgress: Double, edgePhase: Double, smoked: Bool = false) {
        self.burnProgress = burnProgress
        self.edgePhase = edgePhase
        self.smoked = smoked
    }

    init(fragment: ParchmentFragment) {
        self.init(burnProgress: fragment.burnProgress, edgePhase: fragment.edgePhase,
                  smoked: fragment.isFellAsleep)
    }

    var body: some View {
        GeometryReader { geo in
            let scrap = ScrapGeometry(burnProgress: burnProgress, seed: edgePhase, size: geo.size)
            let shape = ScrapShape(geometry: scrap)
            let edge = Path { $0.addLines(scrap.edgePoints) }

            ZStack {
                shape.fill(BurningParchmentView.parchmentGradient)
                if smoked {
                    shape.fill(RadialGradient(
                        colors: [Color(red: 0.25, green: 0.18, blue: 0.12).opacity(0.18),
                                 Color(red: 0.14, green: 0.10, blue: 0.07).opacity(0.5)],
                        center: .topLeading, startRadius: 0, endRadius: 260))
                }
                // 타다 만 가장자리의 그을음 — 조각 안쪽으로만 번진다
                edge.stroke(Color(red: 0.30, green: 0.15, blue: 0.05).opacity(0.75),
                            style: StrokeStyle(lineWidth: scrap.charWidth, lineCap: .round, lineJoin: .round))
                    .blur(radius: scrap.charWidth * 0.35)
                    .clipShape(shape)
                edge.stroke(Color(red: 0.14, green: 0.07, blue: 0.02).opacity(0.9),
                            style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                shape.stroke(Color.brown.opacity(0.25), lineWidth: 1)
            }
            .shadow(color: .appShadow.opacity(0.45), radius: 8, y: 4)
        }
        .accessibilityHidden(true)
    }

    /// 타다 만 가장자리 위의 점들 — 이 뷰를 size 크기로 그렸을 때의 좌표.
    /// 불 끄기 화면이 이 위에 불꽃과 연기를 얹는다.
    static func edgePoints(burnProgress: Double, edgePhase: Double, in size: CGSize) -> [CGPoint] {
        ScrapGeometry(burnProgress: burnProgress, seed: edgePhase, size: size).edgePoints
    }

    /// 불꽃이 솟는 방향 (타 버린 쪽, 오른쪽 아래)
    static var edgeNormal: CGVector {
        BurningParchmentView.burnNormal(pw: ScrapGeometry.parchment.width, ph: ScrapGeometry.parchment.height)
    }
}

// MARK: - Geometry

/// 남은 조각의 꼭짓점과 타다 만 가장자리를 뷰 좌표로 계산한다.
private struct ScrapGeometry {
    /// 메인 화면 양피지의 비율 — 조각의 기울기가 메인 화면과 같아지게
    static let parchment = CGSize(width: 345, height: 390)
    private static let segments = 56

    /// 양피지 테두리를 따라가는 꼭짓점 (가장자리 양 끝 제외)
    let corners: [CGPoint]
    /// 타다 만 가장자리 — 오른쪽 위 끝에서 왼쪽 아래 끝으로
    let edgePoints: [CGPoint]
    let charWidth: CGFloat

    init(burnProgress: Double, seed: Double, size: CGSize) {
        let W = Self.parchment.width, H = Self.parchment.height
        // DiagonalBurnShape 와 같은 k — 1 보다 작으면 왼쪽 위 삼각형만 남아 있다
        let k = min(max(2.0 * (1.0 - burnProgress), 0.001), 2)

        // 양피지 좌표에서의 남은 조각
        let edgeTop, edgeBottom: CGPoint
        let refCorners: [CGPoint]
        let box: CGSize
        if k < 1 {
            edgeTop = CGPoint(x: k * W, y: 0)
            edgeBottom = CGPoint(x: 0, y: k * H)
            refCorners = [.zero]
            box = CGSize(width: k * W, height: k * H)
        } else {
            edgeTop = CGPoint(x: W, y: (k - 1) * H)
            edgeBottom = CGPoint(x: (k - 1) * W, y: H)
            refCorners = [CGPoint(x: 0, y: H), .zero, CGPoint(x: W, y: 0)]
            box = Self.parchment
        }

        // 뷰에 맞춰 키운다. 요철이 튀어나올 여백을 먼저 뺀다.
        let margin = min(size.width, size.height) * 0.08
        let scale = max(0.0001, min((size.width - margin * 2) / box.width,
                                    (size.height - margin * 2) / box.height))
        let origin = CGPoint(x: (size.width - box.width * scale) / 2,
                             y: (size.height - box.height * scale) / 2)
        func map(_ p: CGPoint) -> CGPoint {
            CGPoint(x: origin.x + p.x * scale, y: origin.y + p.y * scale)
        }

        let a = map(edgeTop), b = map(edgeBottom)
        let len = hypot(b.x - a.x, b.y - a.y)
        let amp = Double(min(margin * 0.9, len * 0.07))
        let n = BurningParchmentView.burnNormal(pw: W, ph: H)

        corners = refCorners.map(map)
        edgePoints = (0...Self.segments).map { i in
            let t = Double(i) / Double(Self.segments)
            // 끝점은 양피지 테두리에 붙어 있어야 한다
            let fade = pow(sin(.pi * t), 0.6)
            let wave = sin(t * 9 + seed * 1.3) * 0.55
                     + sin(t * 21 + seed * 2.1) * 0.30
                     + sin(t * 37 + seed * 0.7) * 0.15
            let off = wave * amp * fade
            return CGPoint(x: a.x + (b.x - a.x) * t + n.dx * off,
                           y: a.y + (b.y - a.y) * t + n.dy * off)
        }
        charWidth = max(4, min(18, len * 0.06))
    }
}

private struct ScrapShape: Shape {
    let geometry: ScrapGeometry

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = geometry.edgePoints.first, let last = geometry.edgePoints.last else { return path }
        // 가장자리 끝(왼쪽 아래) → 테두리 꼭짓점들 → 가장자리 시작(오른쪽 위) → 가장자리를 따라 되돌아온다
        path.move(to: last)
        path.addLines([last] + geometry.corners + [first])
        path.addLines(geometry.edgePoints)
        path.closeSubpath()
        return path
    }
}
