// ReflectionBookView.swift
// 모든 항아리의 회고를 일자별로 묶어 양피지 페이지로 책처럼 넘기는 뷰.
// 좌→우 스와이프로 과거↔현재 이동. 최신 일자가 마지막 페이지.

import SwiftUI

struct ReflectionBookView: View {
    @EnvironmentObject var reflectionManager: ReflectionManager
    @Environment(\.dismiss) private var dismiss

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
            Color(red: 0.06, green: 0.05, blue: 0.03).ignoresSafeArea()

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
                    Text("\(currentPage + 1) / \(pages.count)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.orange.opacity(0.6))
                }
            }
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
        VStack(spacing: 14) {
            Image(systemName: "book.closed")
                .font(.system(size: 52))
                .foregroundColor(.orange.opacity(0.3))
            Text("아직 첫 페이지에요")
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundColor(.gray.opacity(0.6))
            Text("회고를 하나라도 담으면\n이 책이 채워져요.")
                .font(.system(size: 12, design: .serif))
                .foregroundColor(.gray.opacity(0.45))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 5) {
            ForEach(0..<min(pages.count, 30), id: \.self) { i in
                Circle()
                    .fill(i == currentPage ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: i == currentPage ? 7 : 5,
                           height: i == currentPage ? 7 : 5)
            }
            if pages.count > 30 {
                Text("…")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.5))
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
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundColor(Color(red: 0.42, green: 0.28, blue: 0.16))
                Spacer()
                Text("\(page.items.count)개")
                    .font(.system(size: 10, design: .monospaced))
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
                .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
        )
    }

    private func reflectionCard(_ item: DayReflection) -> some View {
        let urn = reflectionManager.urns.first(where: { $0.id == item.urnId })
        let rgb = item.category.particleColor
        return VStack(alignment: .leading, spacing: 6) {
            // 항아리 + 카테고리 + 시간
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(red: rgb.0, green: rgb.1, blue: rgb.2))
                    .frame(width: 6, height: 6)
                if let urn {
                    Text("\(urn.emoji) \(urn.name)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(red: 0.42, green: 0.28, blue: 0.16).opacity(0.75))
                }
                if item.category != .uncategorized {
                    Text(item.category.shortLabel)
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: rgb.0 * 0.7, green: rgb.1 * 0.6, blue: rgb.2 * 0.5))
                }
                Spacer()
                Text(timeString(item.createdAt))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(red: 0.42, green: 0.28, blue: 0.16).opacity(0.45))
            }

            // 본문
            Text(item.text)
                .font(.system(size: 15, design: .serif))
                .foregroundColor(Color(red: 0.28, green: 0.18, blue: 0.10))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            // 키워드
            if let kw = item.keyword, !kw.isEmpty {
                Text("#\(kw)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(red: 0.55, green: 0.32, blue: 0.10))
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(
                        Capsule().fill(Color(red: 0.55, green: 0.32, blue: 0.10).opacity(0.10))
                    )
            }

            // 내일 메모
            if let intent = item.tomorrowIntent, !intent.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "sunrise")
                        .font(.system(size: 9))
                    Text(intent)
                        .font(.system(size: 11, design: .serif))
                }
                .foregroundColor(Color(red: 0.62, green: 0.38, blue: 0.14))
                .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.95, green: 0.88, blue: 0.74).opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.brown.opacity(0.15), lineWidth: 0.5))
        )
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
        .accessibilityLabel("\(urn?.name ?? "") 회고")
        .accessibilityValue(item.text)
        .accessibilityHint("탭하여 수정")
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
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일 (EEEE)"
        return f.string(from: date)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "HH:mm"
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
            .preferredColorScheme(.dark)
    }
}
