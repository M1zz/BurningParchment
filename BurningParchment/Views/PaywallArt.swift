// PaywallArt.swift
// 페이월에서 옆으로 넘겨 보는 기능 그림(LeeoKit `LeeoShowcase` 의 art) — 클립키보드와 같은 방식.
//
// 그 기능이 열린 화면을 SwiftUI 로 줄여 그린다. 스크린샷이 아니라 그림이라 언어 · 다크 모드를 따라가고 용량이 늘지 않는다.
// ⚠️ 그림 속 글자는 숫자 · 기호만. 문장은 그림 아래 한 줄 설명이 맡는다.
// 인생의 시간은 실제 곡선 차트(`CountCurveChart`)를 그대로 보여 준다 — 무엇을 사는지 가장 바로 보인다.

import SwiftUI

// MARK: - 공용 조각

/// 그림 속 양피지 한 장
private struct ArtPaper: View {
    var style: ParchmentStyle = .classic
    var corner: CGFloat = 12
    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(style.paperGradient)
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(Color.brown.opacity(0.3), lineWidth: 0.8))
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
    }
}

/// 글자 자리(막대)
private struct ArtLine: View {
    let width: CGFloat
    var opacity: Double = 0.45
    var body: some View {
        Capsule().fill(ArtInk.brown.opacity(opacity)).frame(width: width, height: 6)
    }
}

/// 모서리 둥근 배지 — ∞ · 3 · PDF 처럼 한눈에 읽히는 것
private struct ArtBadge: View {
    let text: String
    var symbol: String? = nil
    var body: some View {
        Group {
            if let symbol {
                Image(systemName: symbol).font(.title3.weight(.bold))
            } else {
                Text(verbatim: text).font(.headline.weight(.heavy))
            }
        }
        .foregroundStyle(.white)
        .frame(minWidth: 44, minHeight: 44)
        .padding(.horizontal, symbol == nil && text.count > 1 ? 6 : 0)
        .background(Color.ember, in: Capsule())
        .shadow(color: Color.ember.opacity(0.45), radius: 6, y: 2)
    }
}

private enum ArtInk {
    static let brown = Color(red: 0.42, green: 0.28, blue: 0.16)
    static let ash = Color(red: 0.55, green: 0.52, blue: 0.50)
}

// MARK: - 인생의 시간

/// 부모님과 함께하는 날 — 앱이 그리는 곡선 그대로(서른다섯 살, 부모님 예순다섯, 1년에 10일)
private enum ArtSample {
    static let parents: RemainingItem = {
        let template = LifeTemplate.all(myAge: 35, expectancy: 83).first { $0.id == "parents" }
        return template.map { $0.item(["me": 35, "parent": 65, "perYear": 10]).0 }
            ?? RemainingItem(name: "", symbol: "person.2.fill", unit: .day, phases: [], startDate: Date(), spanYears: 1)
    }()
}

/// 인생의 시간 3개: 곡선 한 장 + 세 가지 시간
struct CountThreeArt: View {
    var body: some View {
        VStack(spacing: 12) {
            CountCurveChart(item: ArtSample.parents)
                .frame(height: 130)
                .padding(14)
                .background(ArtPaper())
            HStack(spacing: 14) {
                ForEach(["person.2.fill", "figure.2.and.child.holdinghands", "airplane"], id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.ember)
                        .frame(width: 52, height: 52)
                        .background(Color.ember.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(16)
        .overlay(alignment: .topTrailing) { ArtBadge(text: "3").padding(4) }
    }
}

/// 인생의 시간 무제한: 곡선 카드가 겹겹이, 모서리에 ∞
struct CountUnlimitedArt: View {
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                ArtPaper()
                    .frame(height: 170)
                    .offset(x: CGFloat(2 - i) * 10, y: CGFloat(2 - i) * -12)
                    .opacity(i == 2 ? 1 : 0.7)
            }
            CountCurveChart(item: ArtSample.parents)
                .frame(height: 140)
                .padding(14)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .overlay(alignment: .topTrailing) { ArtBadge(text: "", symbol: "infinity").padding(4) }
    }
}

// MARK: - 나만의 시간

/// 일주일 칸 — 나만의 시간(불씨)만 타고, 나머지(일 · 잠)는 재빛으로 그대로
struct FreeTimeArt: View {
    /// 요일마다 (시작, 끝) 비율 — 평일 저녁 몇 시간, 주말은 길게
    private static let mine: [(CGFloat, CGFloat)] = [
        (0.70, 0.86), (0.72, 0.84), (0.70, 0.88), (0.74, 0.86), (0.66, 0.90), (0.30, 0.88), (0.36, 0.84),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(Self.mine.enumerated()), id: \.offset) { _, span in
                GeometryReader { g in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ArtInk.ash.opacity(0.22))
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(LinearGradient(colors: [.emberGlow, .ember], startPoint: .top, endPoint: .bottom))
                                .frame(height: g.size.height * (span.1 - span.0))
                                .offset(y: g.size.height * span.0)
                                .shadow(color: Color.ember.opacity(0.5), radius: 5)
                        }
                }
                .frame(width: 26)
            }
        }
        .frame(height: 170)
        .padding(18)
        .background(ArtPaper())
        .overlay(alignment: .topTrailing) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.ember, in: Circle())
                .offset(x: 12, y: -12)
        }
        .padding(16)
    }
}

// MARK: - 테마

/// 네 가지 양피지 · 불꽃 빛깔
struct ThemeArt: View {
    var body: some View {
        HStack(spacing: 10) {
            ForEach(ParchmentStyle.allCases) { style in
                ArtPaper(style: style, corner: 10)
                    .frame(width: 64, height: 120)
                    .overlay(alignment: .bottom) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(LinearGradient(colors: [.yellow, .orange, .red],
                                                            startPoint: .top, endPoint: .bottom))
                            .hueRotation(style.flameHue)
                            .padding(.bottom, 12)
                    }            }
        }
        .padding(16)
    }
}

// MARK: - 조각 카드 · 포스터

/// 조각 카드 두 장과 포스터, 공유 화살표
struct FragmentExportArt: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            ArtPaper()
                .frame(width: 96, height: 140)
                .overlay {
                    VStack(alignment: .leading, spacing: 7) {
                        Image(systemName: "quote.opening").foregroundStyle(ArtInk.brown.opacity(0.7))
                        ArtLine(width: 62)
                        ArtLine(width: 70)
                        ArtLine(width: 48)
                    }
                }
                .rotationEffect(.degrees(-6))
            ArtPaper()
                .frame(width: 118, height: 168)
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "flame.fill").font(.title).foregroundStyle(Color.ember)
                        ArtLine(width: 76, opacity: 0.6)
                        ArtLine(width: 56)
                        ArtLine(width: 66)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    ArtBadge(text: "", symbol: "square.and.arrow.up").offset(x: 14, y: -14)
                }
                .rotationEffect(.degrees(4))
        }
        .padding(20)
    }
}

// MARK: - 회고 책 PDF

/// 펼친 책 두 쪽과 PDF 표
struct BookExportArt: View {
    private func page(_ widths: [CGFloat]) -> some View {
        ArtPaper(corner: 6)
            .frame(width: 112, height: 150)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 9) {
                    ArtLine(width: 48, opacity: 0.7)
                    ForEach(Array(widths.enumerated()), id: \.offset) { _, w in ArtLine(width: w) }
                }
                .padding(14)
            }
    }

    var body: some View {
        HStack(spacing: 2) {
            page([80, 70, 84, 60, 76])
            page([74, 84, 56, 80, 66])
        }
        .padding(18)
        .overlay(alignment: .topTrailing) { ArtBadge(text: "PDF").padding(4) }
    }
}

// MARK: - 한 해의 재

/// 열두 달 막대 — 재가 쌓인 만큼
struct InsightsArt: View {
    private static let months: [CGFloat] = [0.35, 0.5, 0.42, 0.7, 0.55, 0.8, 0.62, 0.9, 0.66, 0.48, 0.74, 0.58]

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(Array(Self.months.enumerated()), id: \.offset) { i, h in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(i == Self.months.count - 1 ? Color.ember : ArtInk.ash.opacity(0.55))
                        .frame(width: 14, height: 140 * h)
                }
            }
            .frame(height: 140, alignment: .bottom)
            HStack {
                Text(verbatim: "1").font(.caption2.monospacedDigit())
                Spacer()
                Text(verbatim: "12").font(.caption2.monospacedDigit())
            }
            .foregroundStyle(.secondary)
        }
        .frame(width: 240)
        .padding(18)
        .background(ArtPaper())
        .padding(16)
    }
}

// MARK: - 데드라인 무제한

/// 여러 목표가 함께 줄어드는 모습
struct DeadlineArt: View {
    var body: some View {
        VStack(spacing: 9) {
            row(days: 12, fill: 0.85, width: 120)
            row(days: 45, fill: 0.55, width: 90)
            row(days: 120, fill: 0.25, width: 140)
        }
        .frame(width: 270)
        .padding(16)
        .overlay(alignment: .topTrailing) { ArtBadge(text: "", symbol: "infinity").offset(x: 10, y: -10) }
    }

    private func row(days: Int, fill: CGFloat, width: CGFloat) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "flag.fill")
                .foregroundStyle(Color.ember)
                .frame(width: 30, height: 30)
                .background(Color.ember.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                ArtLine(width: width * 0.6, opacity: 0.6)
                GeometryReader { g in
                    Capsule().fill(ArtInk.ash.opacity(0.25))
                        .overlay(alignment: .leading) {
                            Capsule().fill(Color.ember).frame(width: g.size.width * fill)
                        }
                }
                .frame(height: 6)
            }
            Text(verbatim: "D-\(days)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(ArtInk.brown)
        }
        .padding(10)
        .background(ArtPaper(corner: 10))
    }
}

// MARK: - Plus 전부

/// Plus 에서 열리는 것을 한데
struct PlusAllArt: View {
    private static let symbols = ["paintpalette.fill", "square.and.arrow.up.fill", "book.closed.fill",
                                  "chart.bar.fill", "flag.fill", "hourglass"]
    var body: some View {
        VStack(spacing: 14) {
            Text(verbatim: "Plus")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Color.ember)
                .padding(.horizontal, 14).padding(.vertical, 5)
                .background(Color.ember.opacity(0.14), in: Capsule())
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(60), spacing: 12), count: 3), spacing: 12) {
                ForEach(Self.symbols, id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.ember)
                        .frame(width: 60, height: 60)
                        .background(ArtPaper(corner: 14))
                }
            }
            Image(systemName: "checkmark.seal.fill").font(.title).foregroundStyle(.green)
        }
        .padding(16)
    }
}
