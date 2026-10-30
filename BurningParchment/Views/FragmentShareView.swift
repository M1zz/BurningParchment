// FragmentShareView.swift
// 모은 조각을 이미지로 꺼내 간직한다 (프로).
//
// 조각 한 장은 카드로, 모은 조각 전체는 포스터로. 둘 다 ImageRenderer 로 그려 공유 시트에 넘긴다.
// 이미지는 화면의 라이트/다크와 상관없이 고른 바탕으로 그린다 — 밖으로 나가는 그림은 늘 같아야 한다.

import SwiftUI

// MARK: - 바탕

enum FragmentBackdrop: String, CaseIterable, Identifiable {
    case night, parchment, ash

    var id: String { rawValue }

    var label: String {
        switch self {
        case .night:     return String(localized: "밤")
        case .parchment: return String(localized: "양피지")
        case .ash:       return String(localized: "재")
        }
    }

    var background: Color {
        switch self {
        case .night:     return Color(red: 0.07, green: 0.05, blue: 0.04)
        case .parchment: return Color(red: 0.95, green: 0.92, blue: 0.86)
        case .ash:       return Color(red: 0.24, green: 0.23, blue: 0.22)
        }
    }

    /// 이 바탕 위의 글자는 어느 쪽 화면 모드로 읽혀야 하나
    var colorScheme: ColorScheme { self == .parchment ? .light : .dark }

    var ink: Color {
        self == .parchment ? Color(red: 0.16, green: 0.12, blue: 0.08) : Color(red: 0.96, green: 0.92, blue: 0.85)
    }

    var accent: Color {
        self == .parchment ? Color(red: 0.68, green: 0.30, blue: 0.08) : Color(red: 1.0, green: 0.62, blue: 0.22)
    }
}

// MARK: - 조각 한 장 카드

struct FragmentCardImage: View {
    let fragment: ParchmentFragment
    let backdrop: FragmentBackdrop

    static let size = CGSize(width: 360, height: 450)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FragmentScrapView(fragment: fragment)
                .frame(height: 170)
                .padding(.top, 8)

            Text(fragment.isBackWritten ? fragment.phrase : fragment.longCaption)
                .font(.system(size: 21, weight: .medium, design: .serif))
                .foregroundColor(backdrop.ink)
                .lineSpacing(5)
                .lineLimit(5)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(fragment.dateString)
                    Text(fragment.shortCaption)
                }
                .font(.system(size: 12, design: .serif))
                .foregroundColor(backdrop.ink.opacity(0.6))
                Spacer()
                brandMark
            }
        }
        .padding(28)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(backdrop.background)
        .environment(\.colorScheme, backdrop.colorScheme)
    }

    private var brandMark: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
            Text("불타는 내인생")
        }
        .font(.system(size: 11, weight: .medium, design: .serif))
        .foregroundColor(backdrop.accent.opacity(0.85))
    }
}

// MARK: - 모은 조각 포스터

struct FragmentPosterImage: View {
    let fragments: [ParchmentFragment]
    let backdrop: FragmentBackdrop

    /// 포스터에 담는 최대 조각 수 (최근 것부터)
    static let maxCount = 24
    static let size = CGSize(width: 360, height: 640)

    private var shown: [ParchmentFragment] { Array(fragments.prefix(Self.maxCount)) }

    private var columnCount: Int { shown.count <= 4 ? 2 : (shown.count <= 12 ? 3 : 4) }

    /// ImageRenderer 는 Lazy 컨테이너를 그리지 못하므로 줄을 직접 나눈다.
    private var rows: [[ParchmentFragment]] {
        stride(from: 0, to: shown.count, by: columnCount).map {
            Array(shown[$0..<min($0 + columnCount, shown.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(fragments.count)번의 밤을 끄고")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundColor(backdrop.ink)
                if let range = rangeText {
                    Text(range)
                        .font(.system(size: 12, design: .serif))
                        .foregroundColor(backdrop.ink.opacity(0.55))
                }
            }

            VStack(spacing: 12) {
                ForEach(rows.indices, id: \.self) { r in
                    HStack(spacing: 10) {
                        ForEach(rows[r]) { fragment in
                            VStack(spacing: 5) {
                                FragmentScrapView(fragment: fragment)
                                    .aspectRatio(1.1, contentMode: .fit)
                                // 뒷면에 적은 한 줄이 있으면 조각 밑에 작게
                                Text(fragment.isBackWritten ? fragment.phrase : " ")
                                    .font(.system(size: columnCount >= 4 ? 7 : 9, design: .serif))
                                    .foregroundColor(backdrop.ink.opacity(0.7))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, minHeight: 22, alignment: .top)
                            }
                        }
                        // 마지막 줄이 덜 차도 조각 크기는 같게
                        ForEach(0..<(columnCount - rows[r].count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Text("남은 조각을 모아 둡니다")
                    .font(.system(size: 11, design: .serif))
                    .foregroundColor(backdrop.ink.opacity(0.5))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                    Text("불타는 내인생")
                }
                .font(.system(size: 11, weight: .medium, design: .serif))
                .foregroundColor(backdrop.accent.opacity(0.85))
            }
        }
        .padding(28)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(backdrop.background)
        .environment(\.colorScheme, backdrop.colorScheme)
    }

    private var rangeText: String? {
        guard let newest = fragments.first, let oldest = fragments.last else { return nil }
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("yMMMd")
        if fragments.count == 1 { return f.string(from: newest.bedtimeDate) }
        return "\(f.string(from: oldest.bedtimeDate)) – \(f.string(from: newest.bedtimeDate))"
    }
}

// MARK: - 공유 시트 (미리보기 + 바탕 고르기 + 공유)

struct FragmentShareSheet: View {
    enum Content {
        case card(ParchmentFragment)
        case poster([ParchmentFragment])
    }

    let content: Content
    @Environment(\.dismiss) private var dismiss
    @Environment(\.parchmentStyle) private var style
    @State private var backdrop: FragmentBackdrop = .night
    @State private var rendered: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundWarm.ignoresSafeArea()

                VStack(spacing: 20) {
                    preview
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Picker("바탕", selection: $backdrop) {
                        ForEach(FragmentBackdrop.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if let rendered {
                        ShareLink(item: Image(uiImage: rendered),
                                  preview: SharePreview(shareTitle, image: Image(uiImage: rendered))) {
                            Label("이미지 공유", systemImage: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                                .foregroundColor(.onEmber)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.ember))
                        }
                    } else {
                        ProgressView().frame(height: 50)
                    }
                }
                .padding(20)
            }
            .navigationTitle(shareTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: { Label("닫기", systemImage: "xmark") }
                        .foregroundColor(.ember)
                }
            }
        }
        .task(id: backdrop) { render() }
    }

    private var shareTitle: String {
        switch content {
        case .card:   return String(localized: "조각 카드")
        case .poster: return String(localized: "조각 포스터")
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let rendered {
            Image(uiImage: rendered)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .appShadow.opacity(0.4), radius: 12, y: 6)
                .accessibilityLabel(shareTitle)
        } else {
            Color.clear
        }
    }

    @MainActor
    private func render() {
        let view: AnyView
        switch content {
        case .card(let fragment):
            view = AnyView(FragmentCardImage(fragment: fragment, backdrop: backdrop))
        case .poster(let fragments):
            view = AnyView(FragmentPosterImage(fragments: fragments, backdrop: backdrop))
        }
        let renderer = ImageRenderer(content: view.environment(\.parchmentStyle, style))
        renderer.scale = 3
        rendered = renderer.uiImage
    }
}
