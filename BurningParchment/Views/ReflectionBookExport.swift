// ReflectionBookExport.swift
// 회고 책을 PDF 한 권으로 묶는다 (프로).
//
// A5 쪽에 표지 → 날짜 머리 + 그날의 회고를 위에서부터 채우고, 넘치면 다음 쪽으로 넘긴다.
// 조각(블록)은 SwiftUI 로 그리고 ImageRenderer 로 PDF 컨텍스트에 벡터 그대로 얹는다 — 글자가 선명하게 남는다.
// 날짜 머리는 그날의 첫 회고와 같은 쪽에 붙어 다닌다.

import SwiftUI

// MARK: - 내보낼 범위

enum BookExportScope: Hashable, Identifiable {
    case all
    case month(year: Int, month: Int)

    var id: String {
        switch self {
        case .all: return "all"
        case .month(let y, let m): return "\(y)-\(m)"
        }
    }

    var title: String {
        switch self {
        case .all: return String(localized: "전체")
        case .month(let y, let m):
            var c = DateComponents(); c.year = y; c.month = m; c.day = 1
            let date = Calendar.current.date(from: c) ?? Date()
            let f = DateFormatter()
            f.locale = .current
            f.setLocalizedDateFormatFromTemplate("yMMMM")
            return f.string(from: date)
        }
    }

    func contains(_ date: Date) -> Bool {
        switch self {
        case .all: return true
        case .month(let y, let m):
            let c = Calendar.current.dateComponents([.year, .month], from: date)
            return c.year == y && c.month == m
        }
    }
}

// MARK: - PDF 만들기

enum ReflectionBookPDF {
    static let pageSize = CGSize(width: 420, height: 595)   // A5 (pt)
    static let margin: CGFloat = 36
    static let footerHeight: CGFloat = 22
    static let blockSpacing: CGFloat = 10

    static let ink = Color(red: 0.28, green: 0.18, blue: 0.10)
    static let inkSoft = Color(red: 0.42, green: 0.28, blue: 0.16)
    static let paper = CGColor(red: 0.96, green: 0.92, blue: 0.84, alpha: 1)

    /// 범위 안의 회고로 PDF 를 만들어 임시 파일 URL 을 돌려준다. 회고가 없으면 nil.
    @MainActor
    static func make(reflections all: [DayReflection], scope: BookExportScope,
                     urnTitle: (DayReflection) -> String) -> URL? {
        let reflections = all.filter { scope.contains($0.date) }
        guard !reflections.isEmpty else { return nil }

        let days = Dictionary(grouping: reflections) { Calendar.current.startOfDay(for: $0.date) }
            .map { (date: $0.key, items: $0.value.sorted { $0.createdAt < $1.createdAt }) }
            .sorted { $0.date < $1.date }

        let contentWidth = pageSize.width - margin * 2
        let fileName = String(localized: "회고 책") + " - " + scope.title + ".pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            fileName.replacingOccurrences(of: "/", with: "-"))

        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let pdf = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { return nil }

        var pageNumber = 0
        var cursorY: CGFloat = 0   // 쪽 맨 위에서부터 내려온 거리

        func beginPage() {
            pageNumber += 1
            pdf.beginPDFPage(nil)
            pdf.setFillColor(paper)
            pdf.fill(CGRect(origin: .zero, size: pageSize))
            cursorY = margin
        }

        func endPage(footer: Bool = true) {
            if footer {
                draw(Text("\(pageNumber - 1)")
                        .font(.system(size: 9, design: .serif))
                        .foregroundColor(inkSoft.opacity(0.6))
                        .frame(width: contentWidth),
                     width: contentWidth,
                     atTop: pageSize.height - margin + 8, in: pdf)
            }
            pdf.endPDFPage()
        }

        // 표지
        beginPage()
        let cover = BookCoverBlock(scopeTitle: scope.title, days: days.count, count: reflections.count,
                                   first: days.first?.date, last: days.last?.date)
            .frame(width: contentWidth, height: pageSize.height - margin * 2)
        draw(cover, width: contentWidth, atTop: margin, in: pdf)
        endPage(footer: false)

        // 본문
        beginPage()
        let bottomLimit = pageSize.height - margin - footerHeight
        for day in days {
            let header = BookDayHeaderBlock(date: day.date, count: day.items.count)
            let headerHeight = measure(header, width: contentWidth)
            for (i, item) in day.items.enumerated() {
                let block = BookReflectionBlock(item: item, urnTitle: urnTitle(item))
                let height = measure(block, width: contentWidth)
                let needed = (i == 0 ? headerHeight + blockSpacing : 0) + height
                // 쪽 맨 위가 아니고 넘치면 다음 쪽으로. 한 쪽보다 큰 블록은 그냥 그 쪽에 둔다.
                if cursorY > margin, cursorY + needed > bottomLimit {
                    endPage()
                    beginPage()
                }
                if i == 0 {
                    draw(header, width: contentWidth, atTop: cursorY, in: pdf)
                    cursorY += headerHeight + blockSpacing
                }
                draw(block, width: contentWidth, atTop: cursorY, in: pdf)
                cursorY += height + blockSpacing
            }
            cursorY += blockSpacing   // 날짜 사이 여백
        }
        endPage()
        pdf.closePDF()
        return url
    }

    @MainActor
    private static func measure<V: View>(_ view: V, width: CGFloat) -> CGFloat {
        let renderer = ImageRenderer(content: view.frame(width: width))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        var height: CGFloat = 0
        renderer.render { size, _ in height = size.height }
        return height
    }

    /// view 를 쪽 맨 위에서 top 만큼 내려온 자리에 그린다. (PDF 좌표는 아래가 0 이다)
    @MainActor
    private static func draw<V: View>(_ view: V, width: CGFloat, atTop top: CGFloat, in pdf: CGContext) {
        let renderer = ImageRenderer(content: view.frame(width: width).environment(\.colorScheme, .light))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        renderer.render { size, render in
            pdf.saveGState()
            pdf.translateBy(x: margin, y: pageSize.height - top - size.height)
            render(pdf)
            pdf.restoreGState()
        }
    }
}

// MARK: - 블록

private struct BookCoverBlock: View {
    let scopeTitle: String
    let days: Int
    let count: Int
    let first: Date?
    let last: Date?

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 34))
                .foregroundColor(Color(red: 0.80, green: 0.38, blue: 0.10))
            Text("회고 책")
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundColor(ReflectionBookPDF.ink)
            Text(scopeTitle)
                .font(.system(size: 16, design: .serif))
                .foregroundColor(ReflectionBookPDF.inkSoft)
            Rectangle()
                .fill(ReflectionBookPDF.inkSoft.opacity(0.3))
                .frame(width: 60, height: 0.6)
            if let rangeText {
                Text(rangeText)
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(ReflectionBookPDF.inkSoft.opacity(0.8))
            }
            Text("\(days)일 · 재 \(count)톨")
                .font(.system(size: 12, design: .serif))
                .foregroundColor(ReflectionBookPDF.inkSoft.opacity(0.8))
            Spacer()
            Text("불타는 내인생")
                .font(.system(size: 10, weight: .medium, design: .serif))
                .foregroundColor(ReflectionBookPDF.inkSoft.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private var rangeText: String? {
        guard let first, let last else { return nil }
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("yMMMd")
        let a = f.string(from: first), b = f.string(from: last)
        return a == b ? a : "\(a) – \(b)"
    }
}

private struct BookDayHeaderBlock: View {
    let date: Date
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(dateString)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundColor(ReflectionBookPDF.inkSoft)
                Spacer()
                Text("\(count)개")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(ReflectionBookPDF.inkSoft.opacity(0.6))
            }
            Rectangle()
                .fill(ReflectionBookPDF.inkSoft.opacity(0.25))
                .frame(height: 0.5)
        }
    }

    private var dateString: String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("yMdEEEE")
        return f.string(from: date)
    }
}

private struct BookReflectionBlock: View {
    let item: DayReflection
    let urnTitle: String

    var body: some View {
        let rgb = item.category.particleColor
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(red: rgb.0, green: rgb.1, blue: rgb.2))
                    .frame(width: 5, height: 5)
                Text(urnTitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(ReflectionBookPDF.inkSoft.opacity(0.75))
                if item.category != .uncategorized {
                    Text(item.category.shortLabel)
                        .font(.system(size: 9))
                        .foregroundColor(Color(red: rgb.0 * 0.7, green: rgb.1 * 0.6, blue: rgb.2 * 0.5))
                }
                Spacer()
                Text(timeString)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(ReflectionBookPDF.inkSoft.opacity(0.45))
            }
            Text(item.text)
                .font(.system(size: 12, design: .serif))
                .foregroundColor(ReflectionBookPDF.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            if let kw = item.keyword, !kw.isEmpty {
                Text("#\(kw)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(red: 0.55, green: 0.32, blue: 0.10))
            }
            if let intent = item.tomorrowIntent, !intent.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "sunrise")
                        .font(.system(size: 8))
                    Text(intent)
                        .font(.system(size: 10, design: .serif))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(Color(red: 0.62, green: 0.38, blue: 0.14))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.93, green: 0.86, blue: 0.72).opacity(0.6))
        )
    }

    private var timeString: String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("jm")
        return f.string(from: item.createdAt)
    }
}

// MARK: - 내보내기 시트

struct BookExportSheet: View {
    @EnvironmentObject var reflectionManager: ReflectionManager
    @Environment(\.dismiss) private var dismiss

    @State private var scope: BookExportScope = .all
    @State private var fileURL: URL?

    /// 회고가 있는 달 (최근 달이 먼저)
    private var months: [BookExportScope] {
        let comps = Set(reflectionManager.reflections.map {
            Calendar.current.dateComponents([.year, .month], from: $0.date)
        })
        return comps
            .compactMap { c -> (Int, Int)? in
                guard let y = c.year, let m = c.month else { return nil }
                return (y, m)
            }
            .sorted { $0.0 != $1.0 ? $0.0 > $1.0 : $0.1 > $1.1 }
            .map { BookExportScope.month(year: $0.0, month: $0.1) }
    }

    private var count: Int {
        reflectionManager.reflections.filter { scope.contains($0.date) }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundWarm.ignoresSafeArea()

                VStack(spacing: 22) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.ember.opacity(0.7))
                        .padding(.top, 24)

                    Text("회고를 PDF 한 권으로 묶어요")
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .foregroundColor(.ink.opacity(0.85))

                    Picker("범위", selection: $scope) {
                        Text(BookExportScope.all.title).tag(BookExportScope.all)
                        ForEach(months) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(.ember)

                    Text("재 \(count)톨 · A5 크기")
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(.inkMuted.opacity(0.7))

                    Spacer()

                    if let fileURL {
                        ShareLink(item: fileURL) {
                            Label("PDF 공유·저장", systemImage: "square.and.arrow.up")
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
            .navigationTitle("회고 책 PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundColor(.ember)
                }
            }
        }
        .task(id: scope) { make() }
    }

    @MainActor
    private func make() {
        fileURL = nil
        let manager = reflectionManager
        fileURL = ReflectionBookPDF.make(reflections: manager.reflections, scope: scope) { item in
            manager.meaning(for: item.weekPeriod)?.displayName ?? item.weekPeriod.title
        }
    }
}
