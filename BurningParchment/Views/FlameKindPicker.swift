// FlameKindPicker.swift
// 설정 ▸ 불꽃 종류. 알약 모양 카드가 옆으로 늘어선 캐러셀이다.
// 가운데 카드가 크고 밝고, 양옆은 작고 어둡다. 카드마다 그 종류의 불꽃이 실제로 타서
// 고르기 전에 결을 볼 수 있다. 탭하면 고른다 — 잠긴 종류는 페이월을 연다.
// 지금 고른 양피지·불꽃 테마의 빛깔도 그대로 입혀 보여 준다.

import SwiftUI

struct FlameKindPicker: View {
    /// 지금 실제로 그리는 불꽃 (프로가 아니면 촛불)
    let current: FlameKind
    let style: ParchmentStyle
    let isPro: Bool
    let onSelect: (FlameKind) -> Void

    @State private var focused: FlameKind?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let cardSize = CGSize(width: 104, height: 156)
    /// 카드 위로 불꽃이 솟을 자리
    static let flameRoom: CGFloat = 64

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let width = geo.size.width
                // 스크롤 좌표는 contentMargins 만큼 밀려 있어서, 화면 좌표로 가운데를 잰다
                let centerX = geo.frame(in: .global).midX
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 800) * 1.5
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            ForEach(FlameKind.allCases) { kind in
                                card(kind, phase: phase)
                                    .id(kind)
                                    .visualEffect { content, proxy in
                                        let d = proxy.frame(in: .global).midX - centerX
                                        let t = min(abs(d) / 170, 1)
                                        return content
                                            .scaleEffect(1 - 0.24 * t, anchor: .bottom)
                                            .opacity(1 - 0.5 * t)
                                    }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, max((width - Self.cardSize.width) / 2, 0), for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $focused, anchor: .center)
                }
            }
            .frame(height: Self.cardSize.height + Self.flameRoom)
            .background(alignment: .bottom) { floorGlow }

            caption
        }
        .onAppear { if focused == nil { focused = current } }
    }

    // MARK: - Card

    private func card(_ kind: FlameKind, phase: Double) -> some View {
        let size = Self.cardSize
        let room = Self.flameRoom
        let isSelected = current == kind
        let locked = kind.isPro && !isPro
        let edge = Self.arcPoints(in: CGRect(x: 0, y: room, width: size.width, height: size.height))

        return Button {
            withAnimation(.snappy) { focused = kind }
            onSelect(kind)
        } label: {
            ZStack(alignment: .top) {
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.13, green: 0.08, blue: 0.07),
                                                  Color(red: 0.07, green: 0.04, blue: 0.04),
                                                  Color(red: 0.30, green: 0.06, blue: 0.04)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().stroke(isSelected ? Color.ember.opacity(0.9) : Color.white.opacity(0.08),
                                              lineWidth: isSelected ? 1.5 : 1))
                    .overlay { cardFace(kind, isSelected: isSelected, locked: locked) }
                    .frame(width: size.width, height: size.height)
                    .padding(.top, room)

                FlameView(kind: kind, points: edge, normal: CGVector(dx: 0, dy: -1), phase: phase + Double(FlameKind.allCases.firstIndex(of: kind) ?? 0) * 3.7,
                          scale: 0.8)
                    .flameTint(style)
                    .frame(width: size.width, height: size.height + room)
            }
            .frame(width: size.width, height: size.height + room)
            // 카드는 늘 어두운 바탕이라 불꽃을 어두운 쪽 합성(screen)으로 얹는다
            .environment(\.colorScheme, .dark)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.label)
        .accessibilityHint(kind.tagline)
        .accessibilityValue(locked ? String(localized: "프로에서 열려요") : "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func cardFace(_ kind: FlameKind, isSelected: Bool, locked: Bool) -> some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: kind.icon)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white.opacity(0.9))
            Text(kind.label)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
            Group {
                if locked {
                    Label("프로", systemImage: "lock.fill")
                } else if isSelected {
                    Label("사용 중", systemImage: "checkmark")
                } else {
                    Text(" ")
                }
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white.opacity(0.6))
            .labelStyle(.titleAndIcon)
            .padding(.bottom, 22)
        }
        .padding(.horizontal, 8)
    }

    /// 바닥에 번지는 붉은 반사광
    private var floorGlow: some View {
        Ellipse()
            .fill(RadialGradient(colors: [Color.emberGlow.opacity(0.35), .clear],
                                 center: .center, startRadius: 2, endRadius: 110))
            .frame(width: 240, height: 36)
            .blur(radius: 8)
            .offset(y: 14)
            .allowsHitTesting(false)
    }

    private var caption: some View {
        let kind = focused ?? current
        return HStack(spacing: 6) {
            Text(kind.label).fontWeight(.medium)
            Text("·")
            Text(kind.tagline)
        }
        .font(.system(size: 12, design: .serif))
        .foregroundColor(.inkMuted.opacity(0.65))
        .animation(.default, value: focused)
        .accessibilityHidden(true)
    }

    /// 알약 카드의 윗부분 둥근 곡선 — 불꽃이 여기서 솟는다
    static func arcPoints(in rect: CGRect) -> [CGPoint] {
        let r = rect.width / 2
        let c = CGPoint(x: rect.midX, y: rect.minY + r)
        let n = 28
        return (0...n).map { i in
            let a = Double.pi * (1.12 + 0.76 * Double(i) / Double(n))
            return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a) + 1)
        }
    }
}
