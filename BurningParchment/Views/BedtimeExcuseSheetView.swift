// BedtimeExcuseSheetView.swift
// 취침 시간을 지키지 못했을 때 이유와 다음 계획을 기록하는 시트

import SwiftUI

struct BedtimeExcuseSheetView: View {
    @EnvironmentObject var excuseManager: BedtimeExcuseManager
    @Environment(\.dismiss) private var dismiss

    @State private var reason     = ""
    @State private var nextAction = ""
    @FocusState private var focus: Field?

    enum Field { case reason, nextAction }

    private var pastExcuses: [BedtimeExcuse] { excuseManager.thisWeekPastExcuses }
    private var canSave: Bool { !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.05, blue: 0.03).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        headerSection
                        if !pastExcuses.isEmpty { pastSection }
                        newEntrySection
                        actionButtons
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundColor(.gray.opacity(0.6))
                        .font(.system(size: 15))
                }
            }
        }
        .onAppear { focus = .reason }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("🕯️")
                .font(.system(size: 38))
                .padding(.top, 8)

            Text("오늘 하루를\n마치지 못 했군요")
                .font(.system(size: 26, weight: .light, design: .serif))
                .foregroundColor(.orange.opacity(0.88))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text("오늘 하루를 마치지 못 한 이유는\n무엇인가요?")
                .font(.system(size: 14, design: .serif))
                .foregroundColor(.gray.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    // MARK: - Past This-Week Excuses

    private var pastSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11))
                    .foregroundColor(.orange.opacity(0.55))
                Text("이번 주에도 반복되고 있어요")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(.orange.opacity(0.65))
            }

            VStack(spacing: 8) {
                ForEach(pastExcuses) { excuse in
                    PastExcuseCard(excuse: excuse)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.13), lineWidth: 1)
                )
        )
    }

    // MARK: - New Entry

    private var newEntrySection: some View {
        VStack(spacing: 18) {
            excuseField(
                title: String(localized: "오늘 마치지 못한 이유"),
                placeholder: String(localized: "솔직하게 적어보세요..."),
                text: $reason,
                field: .reason
            )
            excuseField(
                title: String(localized: "다음엔 어떻게 하면 마칠 수 있을까요?"),
                placeholder: String(localized: "작은 변화부터 시작해도 괜찮아요..."),
                text: $nextAction,
                field: .nextAction
            )
        }
    }

    private func excuseField(title: String, placeholder: String,
                             text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray.opacity(0.55))

            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15, design: .serif))
                        .foregroundColor(.gray.opacity(0.28))
                        .padding(.top, 12)
                        .padding(.leading, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: text)
                    .font(.system(size: 15, design: .serif))
                    .foregroundColor(.orange.opacity(0.85))
                    .scrollContentBackground(.hidden)
                    .focused($focus, equals: field)
                    .frame(minHeight: 90)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.035))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                focus == field
                                    ? Color.orange.opacity(0.45)
                                    : Color.orange.opacity(0.13),
                                lineWidth: 1
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: focus == field)
        }
    }

    // MARK: - Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                excuseManager.add(reason: reason, nextAction: nextAction)
                dismiss()
            } label: {
                Text("기록하기")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(canSave ? .black : .gray.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        Capsule()
                            .fill(canSave ? Color.orange : Color.gray.opacity(0.15))
                    )
            }
            .disabled(!canSave)
            .animation(.easeInOut(duration: 0.15), value: canSave)

            Button("오늘은 건너뛸게요") { dismiss() }
                .font(.system(size: 13, design: .serif))
                .foregroundColor(.gray.opacity(0.4))
        }
    }
}

// MARK: - Past Excuse Card

private struct PastExcuseCard: View {
    let excuse: BedtimeExcuse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(excuse.dateString)
                .font(.system(size: 11))
                .foregroundColor(.orange.opacity(0.45))

            Text(excuse.reason)
                .font(.system(size: 13, design: .serif))
                .foregroundColor(.gray.opacity(0.72))
                .lineLimit(3)

            if !excuse.nextAction.isEmpty {
                HStack(alignment: .top, spacing: 5) {
                    Text("→")
                        .font(.system(size: 12))
                        .foregroundColor(.orange.opacity(0.38))
                    Text(excuse.nextAction)
                        .font(.system(size: 12, design: .serif))
                        .foregroundColor(.orange.opacity(0.52))
                        .lineLimit(2)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.02))
        )
    }
}
