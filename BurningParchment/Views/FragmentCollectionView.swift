// FragmentCollectionView.swift
// 불을 끄고 모아둔 양피지 조각들 — 조각마다 그날 밤 남긴 한 줄이 적혀 있다.

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
                            Text("불을 끄고 남긴 조각 \(fragmentManager.fragments.count)개")
                                .font(.system(size: 13, design: .serif))
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
                .font(.system(size: 13))
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
            FragmentScrapView(burnProgress: fragment.burnProgress, edgePhase: fragment.edgePhase)
                .frame(height: 96)

            Text(fragment.phrase)
                .font(.system(size: 14, design: .serif))
                .foregroundColor(.ink.opacity(0.85))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 2) {
                Text(fragment.dateString)
                Text("\(fragment.remainingMinutes)분 남기고")
            }
            .font(.system(size: 10))
            .foregroundColor(.inkMuted.opacity(0.6))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.ink.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.ember.opacity(0.14), lineWidth: 1))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(fragment.phrase)
        .accessibilityValue(String(localized: "\(fragment.dateString), \(fragment.remainingMinutes)분 남기고 불을 껐어요"))
    }
}

// MARK: - Detail

private struct FragmentDetailView: View {
    let fragment: ParchmentFragment
    @EnvironmentObject var fragmentManager: FragmentManager
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            Color.appBackgroundWarm.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 26) {
                    FragmentScrapView(burnProgress: fragment.burnProgress, edgePhase: fragment.edgePhase)
                        .frame(height: 220)
                        .padding(.top, 24)

                    Text(fragment.phrase)
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundColor(.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 4) {
                        Text(fragment.dateString)
                        Text("\(fragment.remainingMinutes)분을 남기고 불을 껐어요")
                    }
                    .font(.system(size: 13, design: .serif))
                    .foregroundColor(.inkMuted.opacity(0.7))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
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
        .confirmationDialog("이 조각을 버릴까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("버리기", role: .destructive) {
                fragmentManager.delete(fragment)
                dismiss()
            }
            Button("취소", role: .cancel) {}
        }
    }
}
