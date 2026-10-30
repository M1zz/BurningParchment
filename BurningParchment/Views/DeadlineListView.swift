// DeadlineListView.swift

import SwiftUI
import Combine

// MARK: - List View

struct DeadlineListView: View {
    @EnvironmentObject var deadlineManager: DeadlineManager
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var selectedDeadline: Deadline?

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackgroundWarm.ignoresSafeArea()

                if deadlineManager.deadlines.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(deadlineManager.deadlines) { deadline in
                                // 버튼이어야 VoiceOver·음성 명령으로도 열린다
                                Button { selectedDeadline = deadline } label: {
                                    DeadlineRow(deadline: deadline)
                                }
                                .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            delete(deadline)
                                        } label: {
                                            Label("삭제", systemImage: "trash")
                                        }
                                    }
                                    // 길게 눌러 여는 메뉴를 VoiceOver 동작으로도
                                    .accessibilityAction(named: Text("삭제")) { delete(deadline) }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("데드라인")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if storeManager.canAddDeadline(currentCount: deadlineManager.deadlines.count) {
                            showAdd = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.ember)
                            .scaledFont(size: 16, weight: .semibold)
                    }
                    .accessibilityLabel("데드라인 추가")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Label("닫기", systemImage: "xmark") }
                        .foregroundColor(.inkMuted)
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            DeadlineFormView()
                .environmentObject(deadlineManager)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .deadline)
                .environmentObject(storeManager)
        }
        .sheet(item: $selectedDeadline) { deadline in
            DeadlineDetailView(deadline: deadline)
                .environmentObject(deadlineManager)
        }
    }

    private func delete(_ deadline: Deadline) {
        deadlineManager.delete(id: deadline.id)
        Moments.deadlineDeleted(deadline.title)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("데드라인이 없어요")
                    .font(.system(.title3, design: .serif).weight(.medium))
                    .foregroundColor(.inkMuted.opacity(0.8))
            } icon: {
                Image(systemName: "flag.fill")
                    .foregroundColor(.ember.opacity(0.35))
            }
        } description: {
            Text("+ 버튼으로 새 데드라인을 추가하세요")
                .foregroundColor(.inkMuted.opacity(0.7))
        } actions: {
            Button("데드라인 추가") { showAdd = true }
                .buttonStyle(.borderedProminent)
                .tint(.ember)
                .accessibilityIdentifier("deadline.emptyAdd")
        }
    }
}

// MARK: - Row

struct DeadlineRow: View {
    let deadline: Deadline
    @State private var now = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 14) {
            Text(deadline.emoji)
                .scaledFont(size: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(deadline.title)
                    .scaledFont(size: 15, weight: .semibold, design: .serif)
                    .foregroundColor(.ember.opacity(0.9))
                    .lineLimit(2)
                Text(deadline.targetDateString)
                    .scaledFont(size: 11)
                    .foregroundColor(.inkMuted.opacity(0.45))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if deadline.isExpired(at: now) {
                    Text("완료")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundColor(.inkMuted.opacity(0.45))
                } else {
                    Text(deadline.remainingString(at: now))
                        .scaledFont(size: 13, weight: .medium, design: .monospaced)
                        .foregroundColor(.ember)
                        .lineLimit(1)
                    Text("남음")
                        .scaledFont(size: 10)
                        .foregroundColor(.inkMuted.opacity(0.45))
                }
            }

            // 미니 프로그레스 링
            ZStack {
                Circle()
                    .stroke(Color.ember.opacity(0.12), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: min(deadline.progress(at: now), 1))
                    .stroke(Color.ember.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 28, height: 28)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.ink.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.ember.opacity(0.10), lineWidth: 1)
                )
        )
        .onReceive(ticker) { now = $0 }
    }
}

// MARK: - Form (Add / Edit)

struct DeadlineFormView: View {
    @EnvironmentObject var deadlineManager: DeadlineManager
    @Environment(\.dismiss) private var dismiss

    var editing: Deadline? = nil

    @State private var title = ""
    @State private var emoji = "🎯"
    @State private var targetDate: Date
    @State private var startDate: Date

    private let emojis = ["🎯", "🚀", "📚", "💼", "🏆", "❤️", "🔥", "⭐️", "🎓", "✈️", "🎮", "💡", "🎵", "🌏", "💪", "🖥️"]

    init(editing: Deadline? = nil) {
        self.editing = editing
        if let d = editing {
            _title      = State(initialValue: d.title)
            _emoji      = State(initialValue: d.emoji)
            _targetDate = State(initialValue: d.targetDate)
            _startDate  = State(initialValue: d.startDate)
        } else {
            _targetDate = State(initialValue: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date())
            _startDate  = State(initialValue: Date())
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackgroundWarm.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 이모지 선택
                        VStack(alignment: .leading, spacing: 8) {
                            Text("이모지")
                                .scaledFont(size: 13, weight: .medium)
                                .foregroundColor(.inkMuted.opacity(0.6))
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(emojis, id: \.self) { e in
                                        Button { emoji = e } label: {
                                            Text(e)
                                                .scaledFont(size: 26)
                                                .padding(9)
                                                .background(
                                                    Circle().fill(emoji == e
                                                        ? Color.ember.opacity(0.2)
                                                        : Color.ink.opacity(0.05))
                                                )
                                                .overlay(
                                                    Circle().stroke(emoji == e
                                                        ? Color.ember.opacity(0.5)
                                                        : Color.clear, lineWidth: 2)
                                                )
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // 제목
                        VStack(alignment: .leading, spacing: 8) {
                            Text("제목")
                                .scaledFont(size: 13, weight: .medium)
                                .foregroundColor(.inkMuted.opacity(0.6))
                            TextField("예: 프로젝트 제출", text: $title)
                                .accessibilityIdentifier("deadline.title")
                                .scaledFont(size: 17)
                                .foregroundColor(.ember.opacity(0.9))
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.ink.opacity(0.04))
                                        .overlay(RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.ember.opacity(0.15), lineWidth: 1))
                                )
                        }
                        .padding(.horizontal, 20)

                        // 시작 시간
                        VStack(alignment: .leading, spacing: 8) {
                            Text("시작 시간")
                                .scaledFont(size: 13, weight: .medium)
                                .foregroundColor(.inkMuted.opacity(0.6))
                            DatePicker("", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .tint(.ember)
                                .labelsHidden()
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.ink.opacity(0.04))
                                        .overlay(RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.ember.opacity(0.15), lineWidth: 1))
                                )
                        }
                        .padding(.horizontal, 20)

                        // 마감일
                        VStack(alignment: .leading, spacing: 8) {
                            Text("마감일")
                                .scaledFont(size: 13, weight: .medium)
                                .foregroundColor(.inkMuted.opacity(0.6))
                            DatePicker("", selection: $targetDate)
                                .datePickerStyle(.graphical)
                                .tint(.ember)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.ink.opacity(0.04))
                                )
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(editing == nil ? "새 데드라인" : "데드라인 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        guard !title.isEmpty else { return }
                        if let d = editing {
                            var updated = d
                            updated.title = title
                            updated.emoji = emoji
                            updated.targetDate = targetDate
                            updated.startDate = startDate
                            deadlineManager.update(updated)
                        } else {
                            deadlineManager.add(Deadline(title: title, emoji: emoji, targetDate: targetDate, startDate: startDate))
                            Moments.deadlineAdded(title)
                        }
                        dismiss()
                    } label: {
                        if editing == nil {
                            Label("추가", systemImage: "plus")
                        } else {
                            Label("저장", systemImage: "checkmark")
                        }
                    }
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundColor(title.isEmpty ? .inkMuted : .ember)
                    .disabled(title.isEmpty)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Label("취소", systemImage: "xmark") }
                        .foregroundColor(.inkMuted)
                }
            }
        }
    }
}
