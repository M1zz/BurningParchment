// ReflectionBookView.swift
// 모든 항아리의 회고를 일자별로 묶어 양피지 페이지로 책처럼 넘기는 뷰.
// 좌→우 스와이프로 과거↔현재 이동. 최신 일자가 마지막 페이지.

import SwiftUI

struct ReflectionBookView: View {
    @EnvironmentObject var reflectionManager: ReflectionManager
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var showExport = false
    @State private var showPaywall = false

    @State private var currentPage: Int = 0
    @State private var editing: DayReflection? = nil
    @State private var didInitPage: Bool = false

    /// 일자별 그룹.  오래된 → 최신 순으로 정렬.
    private var pages: [DayGroup] {
        let grouped = Dictionary(grouping: reflectionManager.reflections) { r in
            Calendar.current.startOfDay(for: r.date)
        }
        return grouped
            .map { DayGroup(date: $0.key, items: $0.value.sorted { $0.createdAt < $1.createdAt }) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ZStack {
            Color.appBackgroundWarm.ignoresSafeArea()

            if pages.isEmpty {
                emptyState
            } else {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, page in
                        pageView(page)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack {
                    Spacer()
                    pageIndicator
                        .padding(.bottom, 12)
                }
            }
        }
        .navigationTitle("회고 책")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !pages.isEmpty {
                    HStack(spacing: 14) {
                        Text("\(currentPage + 1) / \(pages.count)")
                            .scaledFont(size: 12, design: .monospaced)
                            .foregroundColor(.ember)
                        Button {
                            if storeManager.hasPlus { showExport = true } else { showPaywall = true }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.ember)
                        }
                        .accessibilityLabel("회고 책 PDF 로 내보내기")
                    }
                }
            }
        }
        .sheet(isPresented: $showExport) {
            BookExportSheet()
                .environmentObject(reflectionManager)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .bookExport)
                .environmentObject(storeManager)
        }
        .sheet(item: $editing) { item in
            ReflectionInputView(existing: item)
                .environmentObject(reflectionManager)
        }
        .onAppear {
            guard !didInitPage, !pages.isEmpty else { return }
            didInitPage = true
            // 가장 최근 페이지부터 시작
            currentPage = pages.count - 1
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("아직 첫 페이지에요")
                    .font(.system(.title3, design: .serif).weight(.medium))
                    .foregroundColor(.inkMuted.opacity(0.8))
            } icon: {
                Image(systemName: "book.closed")
                    .foregroundColor(.ember)
            }
        } description: {
            Text("회고를 하나라도 담으면\n이 책이 채워져요.")
                .font(.system(.subheadline, design: .serif))
                .foregroundColor(.inkSoft)
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 5) {
            ForEach(0..<min(pages.count, 30), id: \.self) { i in
                Circle()
                    .fill(i == currentPage ? Color.ember : Color.inkMuted.opacity(0.3))
                    .frame(width: i == currentPage ? 7 : 5,
                           height: i == currentPage ? 7 : 5)
            }
            if pages.count > 30 {
                Text("…")
                    .scaledFont(size: 10)
                    .foregroundColor(.inkSoft)
            }
        }
    }

    // MARK: - Page

    private func pageView(_ page: DayGroup) -> some View {
        ScrollView {
            parchmentPage(page)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 60)
        }
    }

    private func parchmentPage(_ page: DayGroup) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // 날짜 헤더
            HStack(alignment: .firstTextBaseline) {
                Text(headerDateString(page.date))
                    .scaledFont(size: 13, weight: .medium, design: .serif)
                    .foregroundColor(Color(red: 0.42, green: 0.28, blue: 0.16))
                Spacer()
                Text("\(page.items.count)개")
                    .scaledFont(size: 10, design: .monospaced)
                    .foregroundColor(Color(red: 0.42, green: 0.28, blue: 0.16).opacity(0.6))
            }

            Rectangle()
                .fill(Color(red: 0.42, green: 0.28, blue: 0.16).opacity(0.25))
                .frame(height: 0.5)

            ForEach(page.items) { item in
                reflectionCard(item)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(parchmentFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.brown.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .appShadow.opacity(0.45), radius: 12, y: 6)
        )
    }

    /// 카드 머리줄: 담긴 항아리 + 카테고리 + 시간
    private func cardHeader(_ item: DayReflection, period: UrnPeriod) -> some View {
        let rgb: (Double, Double, Double) = reflectionManager.hasMeaning(period)
            ? item.category.particleColor : (0.60, 0.58, 0.55)
        let dot = Color(red: rgb.0, green: rgb.1, blue: rgb.2)
        let tag = Color(red: rgb.0 * 0.7, green: rgb.1 * 0.6, blue: rgb.2 * 0.5)
        return HStack(spacing: 6) {
            Circle()
                .fill(dot)
                .frame(width: 6, height: 6)
            Text(period.title)
                .scaledFont(size: 10, weight: .medium)
                .foregroundColor(BookInk.brown.opacity(0.75))
            if item.category != .uncategorized {
                Text(item.category.shortLabel)
                    .scaledFont(size: 10)
                    .foregroundColor(tag)
            }
            Spacer()
            Text(timeString(item.createdAt))
                .scaledFont(size: 9, design: .monospaced)
                .foregroundColor(BookInk.brown.opacity(0.45))
        }
    }

    /// 카드 안쪽 — 머리줄 · 본문 · 키워드 · 내일 메모
    private func cardContent(_ item: DayReflection, period: UrnPeriod) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            cardHeader(item, period: period)

            // 본문
            Text(item.text)
                .scaledFont(size: 15, design: .serif)
                .foregroundColor(BookInk.text)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            // 키워드
            if let kw = item.keyword, !kw.isEmpty {
                Text("#\(kw)")
                    .scaledFont(size: 10, weight: .medium)
                    .foregroundColor(BookInk.keyword)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(Capsule().fill(BookInk.keyword.opacity(0.10)))
            }

            // 내일 메모
            if let intent = item.tomorrowIntent, !intent.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "sunrise")
                        .scaledFont(size: 9)
                    Text(intent)
                        .scaledFont(size: 11, design: .serif)
                }
                .foregroundColor(BookInk.intent)
                .padding(.top, 2)
            }
        }
    }

    /// 카드 한 장 — 안쪽에 바탕 · 누르기 · 메뉴 · 읽어 주기를 입힌다(식을 나눠 타입 검사가 가볍다).
    private func reflectionCard(_ item: DayReflection) -> some View {
        let period = item.weekPeriod
        return cardContent(item, period: period)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.cardBackground)
        .contentShape(Rectangle())
        .onTapGesture { editing = item }
        .contextMenu {
            Button {
                editing = item
            } label: {
                Label("수정", systemImage: "pencil")
            }
            Button(role: .destructive) {
                reflectionManager.delete(id: item.id)
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(period.title) 회고")
        .accessibilityValue(item.text)
        .accessibilityHint("탭하여 수정")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("삭제")) { reflectionManager.delete(id: item.id) }
    }

    private static var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(BookInk.card.opacity(0.55))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.brown.opacity(0.15), lineWidth: 0.5))
    }

    // MARK: - Style

    private var parchmentFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.88, green: 0.80, blue: 0.63),
                Color(red: 0.83, green: 0.73, blue: 0.55),
                Color(red: 0.77, green: 0.66, blue: 0.48)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func headerDateString(_ date: Date) -> String {
        let f = TimeFormat.formatter("yMdEEEE")
        return f.string(from: date)
    }

    private func timeString(_ date: Date) -> String {
        let f = TimeFormat.formatter("jm")
        return f.string(from: date)
    }
}

// MARK: - DayGroup

private struct DayGroup: Identifiable {
    let date: Date
    let items: [DayReflection]
    var id: Date { date }
}

#Preview {
    NavigationStack {
        ReflectionBookView()
            .environmentObject(ReflectionManager())
            .environmentObject(StoreManager())
            .preferredColorScheme(.dark)
    }
}

/// 회고 책의 잉크 색. 식 안에서 `Color(red:green:blue:)` 를 여러 번 만들면 타입 검사가 느려져 이름을 붙여 둔다.
private enum BookInk {
    static let brown = Color(red: 0.42, green: 0.28, blue: 0.16)
    static let text = Color(red: 0.28, green: 0.18, blue: 0.10)
    static let keyword = Color(red: 0.55, green: 0.32, blue: 0.10)
    static let intent = Color(red: 0.62, green: 0.38, blue: 0.14)
    static let card = Color(red: 0.95, green: 0.88, blue: 0.74)
}
