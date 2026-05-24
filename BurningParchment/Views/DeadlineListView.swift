// DeadlineListView.swift

import SwiftUI

// MARK: - List View

struct DeadlineListView: View {
    @EnvironmentObject var deadlineManager: DeadlineManager
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false
    @State private var selectedDeadline: Deadline?

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.06, blue: 0.04).ignoresSafeArea()

                if deadlineManager.deadlines.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(deadlineManager.deadlines) { deadline in
                                DeadlineRow(deadline: deadline)
                                    .onTapGesture { selectedDeadline = deadline }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deadlineManager.delete(id: deadline.id)
                                        } label: {
                                            Label("삭제", systemImage: "trash")
                                        }
                                    }
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
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.orange)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            DeadlineFormView()
                .environmentObject(deadlineManager)
        }
        .sheet(item: $selectedDeadline) { deadline in
            DeadlineDetailView(deadline: deadline)
                .environmentObject(deadlineManager)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.fill")
                .font(.system(size: 52))
                .foregroundColor(.orange.opacity(0.25))
            Text("데드라인이 없어요")
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundColor(.gray.opacity(0.5))
            Text("+ 버튼으로 새 데드라인을 추가하세요")
                .font(.system(size: 13))
                .foregroundColor(.gray.opacity(0.35))
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
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: 4) {
                Text(deadline.title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundColor(.orange.opacity(0.9))
                    .lineLimit(1)
                Text(deadline.targetDateString)
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.45))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if deadline.isExpired(at: now) {
                    Text("완료")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray.opacity(0.45))
                } else {
                    Text(deadline.remainingString(at: now))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                    Text("남음")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.45))
                }
            }

            // 미니 프로그레스 링
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.12), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: min(deadline.progress(at: now), 1))
                    .stroke(Color.orange.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 28, height: 28)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.10), lineWidth: 1)
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
                Color(red: 0.08, green: 0.06, blue: 0.04).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 이모지 선택
                        VStack(alignment: .leading, spacing: 8) {
                            Text("이모지")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(emojis, id: \.self) { e in
                                        Button { emoji = e } label: {
                                            Text(e)
                                                .font(.system(size: 26))
                                                .padding(9)
                                                .background(
                                                    Circle().fill(emoji == e
                                                        ? Color.orange.opacity(0.2)
                                                        : Color.white.opacity(0.05))
                                                )
                                                .overlay(
                                                    Circle().stroke(emoji == e
                                                        ? Color.orange.opacity(0.5)
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
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray.opacity(0.6))
                            TextField("예: 프로젝트 제출", text: $title)
                                .font(.system(size: 17))
                                .foregroundColor(.orange.opacity(0.9))
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.04))
                                        .overlay(RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.orange.opacity(0.15), lineWidth: 1))
                                )
                        }
                        .padding(.horizontal, 20)

                        // 시작 시간
                        VStack(alignment: .leading, spacing: 8) {
                            Text("시작 시간")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray.opacity(0.6))
                            DatePicker("", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .colorScheme(.dark)
                                .tint(.orange)
                                .labelsHidden()
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.04))
                                        .overlay(RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.orange.opacity(0.15), lineWidth: 1))
                                )
                        }
                        .padding(.horizontal, 20)

                        // 마감일
                        VStack(alignment: .leading, spacing: 8) {
                            Text("마감일")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray.opacity(0.6))
                            DatePicker("", selection: $targetDate)
                                .datePickerStyle(.graphical)
                                .colorScheme(.dark)
                                .tint(.orange)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.04))
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
                    Button(editing == nil ? "추가" : "저장") {
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
                        }
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(title.isEmpty ? .gray : .orange)
                    .disabled(title.isEmpty)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
    }
}
