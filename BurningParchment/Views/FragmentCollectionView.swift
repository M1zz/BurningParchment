// FragmentCollectionView.swift
// 불을 끄고 모아둔 양피지 조각들 — 조각을 뒤집으면 뒷면에 적어 둔 한 줄이 있다.

import SwiftUI
import TipKit

struct FragmentCollectionView: View {
    @EnvironmentObject var fragmentManager: FragmentManager
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPoster = false
    @State private var showPaywall = false
    private let backTip = FragmentBackTip()

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundWarm.ignoresSafeArea()

                if fragmentManager.fragments.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            Text("모은 조각 \(fragmentManager.fragments.count)개")
                                .font(.system(.body, design: .serif))
                                .foregroundColor(.inkMuted.opacity(0.7))
                                .padding(.bottom, 12)

                            // 뒷면이 빈 조각이 있을 때만 — 누르면 뒷면에 적을 수 있다는 걸 모르는 사람이 많다
                            if fragmentManager.fragments.contains(where: { !$0.isBackWritten }) {
                                TipView(backTip)
                                    .tipBackground(Color.ink.opacity(0.05))
                                    .padding(.bottom, 10)
                            }

                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(fragmentManager.fragments) { fragment in
                                    NavigationLink(value: fragment) {
                                        FragmentCard(fragment: fragment)
                                    }
                                    .buttonStyle(.plain)
                                    .simultaneousGesture(TapGesture().onEnded {
                                        backTip.invalidate(reason: .actionPerformed)
                                    })
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("모은 조각")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ParchmentFragment.self) { fragment in
                FragmentDetailView(fragment: fragment)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !fragmentManager.fragments.isEmpty {
                        Button {
                            if storeManager.isPro { showPoster = true } else { showPaywall = true }
                        } label: {
                            Label("포스터", systemImage: "square.grid.3x3.square")
                        }
                        .foregroundColor(.ember)
                        .accessibilityLabel("조각 포스터 만들기")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundColor(.ember)
                }
            }
            .sheet(isPresented: $showPoster) {
                FragmentShareSheet(content: .poster(fragmentManager.fragments))
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(reason: .fragmentExport)
                    .environmentObject(storeManager)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("아직 모은 조각이 없어요")
                    .font(.system(.title3, design: .serif).weight(.medium))
                    .foregroundColor(.ember.opacity(0.85))
            } icon: {
                Image(systemName: "wind")
                    .foregroundColor(.ember.opacity(0.5))
            }
        } description: {
            Text("취침 30분 전부터 타는 양피지에 후 불어\n불을 끄고 남은 조각을 모아둘 수 있어요")
                .foregroundColor(.inkMuted.opacity(0.7))
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Card

private struct FragmentCard: View {
    let fragment: ParchmentFragment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FragmentScrapView(fragment: fragment)
                .frame(height: 96)

            Text(fragment.isBackWritten ? fragment.phrase : String(localized: "뒷면이 비어 있어요"))
                .font(.system(.body, design: .serif))
                .foregroundColor(fragment.isBackWritten ? .ink.opacity(0.85) : .inkMuted.opacity(0.6))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 2) {
                Text(fragment.dateString)
                Text(fragment.shortCaption)
            }
            .font(.body)
            .foregroundColor(.inkMuted.opacity(0.7))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.ink.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.ember.opacity(0.14), lineWidth: 1))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(fragment.isBackWritten ? fragment.phrase : String(localized: "뒷면이 비어 있어요"))
        .accessibilityValue(fragment.dateString + ", " + fragment.longCaption)
    }
}

// MARK: - Detail

private struct FragmentDetailView: View {
    let fragmentID: UUID
    @EnvironmentObject var fragmentManager: FragmentManager
    @EnvironmentObject var storeManager: StoreManager
    @State private var showCard = false
    @State private var showPaywall = false
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var showsBack = false
    @State private var editing = false

    init(fragment: ParchmentFragment) { self.fragmentID = fragment.id }

    private var fragment: ParchmentFragment? {
        fragmentManager.fragments.first { $0.id == fragmentID }
    }

    var body: some View {
        ZStack {
            Color.appBackgroundWarm.ignoresSafeArea()

            if let fragment {
                ScrollView {
                    VStack(spacing: 22) {
                        FragmentFlipCard(fragment: fragment, showsBack: $showsBack)
                            .frame(height: 220)
                            .padding(.top, 24)

                        Text("조각을 누르면 뒤집혀요")
                            .font(.body)
                            .foregroundColor(.inkMuted.opacity(0.6))

                        VStack(spacing: 4) {
                            Text(fragment.dateString)
                            Text(fragment.longCaption)
                        }
                        .font(.system(.body, design: .serif))
                        .foregroundColor(.inkMuted.opacity(0.8))
                        .multilineTextAlignment(.center)

                        if editing || !fragment.isBackWritten {
                            FragmentBackEditor(fragment: fragment) {
                                editing = false
                                showsBack = true
                            }
                            .environmentObject(fragmentManager)
                            .padding(.top, 8)
                        } else {
                            Button { editing = true } label: {
                                Label("뒷면 고쳐 쓰기", systemImage: "pencil")
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.ember.opacity(0.85))
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if storeManager.isPro { showCard = true } else { showPaywall = true }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .foregroundColor(.ember)
                .accessibilityLabel("조각 카드로 공유")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Image(systemName: "trash")
                }
                .foregroundColor(.inkMuted)
                .accessibilityLabel("조각 버리기")
            }
        }
        .onAppear { showsBack = fragment?.isBackWritten ?? false }
        .sheet(isPresented: $showCard) {
            if let fragment { FragmentShareSheet(content: .card(fragment)) }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .fragmentExport)
                .environmentObject(storeManager)
        }
        .confirmationDialog("이 조각을 버릴까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("버리기", role: .destructive) {
                if let fragment { fragmentManager.delete(fragment) }
                dismiss()
            }
            Button("취소", role: .cancel) {}
        }
    }
}

// MARK: - Captions

extension ParchmentFragment {
    var shortCaption: String {
        isFellAsleep ? String(localized: "저절로 꺼진 조각") : String(localized: "\(remainingMinutes)분 남기고")
    }

    var longCaption: String {
        isFellAsleep
            ? String(localized: "제시간에 잠들어 불이 저절로 꺼졌어요")
            : String(localized: "\(remainingMinutes)분을 남기고 불을 껐어요")
    }
}
