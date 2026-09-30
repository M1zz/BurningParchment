// FragmentCollectionView.swift
// 불을 끄고 모아둔 양피지 조각들 — 조각을 뒤집으면 뒷면에 적어 둔 한 줄이 있다.

import SwiftUI

struct FragmentCollectionView: View {
    @EnvironmentObject var fragmentManager: FragmentManager
    @Environment(\.dismiss) private var dismiss

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

                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(fragmentManager.fragments) { fragment in
                                    NavigationLink(value: fragment) {
                                        FragmentCard(fragment: fragment)
                                    }
                                    .buttonStyle(.plain)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundColor(.ember)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "wind")
                .font(.system(size: 40))
                .foregroundColor(.ember.opacity(0.5))
            Text("아직 모은 조각이 없어요")
                .font(.system(size: 17, weight: .medium, design: .serif))
                .foregroundColor(.ember.opacity(0.85))
            Text("취침 30분 전부터 타는 양피지에 후 불어\n불을 끄고 남은 조각을 모아둘 수 있어요")
                .font(.body)
                .foregroundColor(.inkMuted.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
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
                Button(role: .destructive) { confirmDelete = true } label: {
                    Image(systemName: "trash")
                }
                .foregroundColor(.inkMuted)
                .accessibilityLabel("조각 버리기")
            }
        }
        .onAppear { showsBack = fragment?.isBackWritten ?? false }
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
