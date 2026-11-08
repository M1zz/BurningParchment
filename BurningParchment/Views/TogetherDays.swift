// TogetherDays.swift
// 함께한 날 남기기 — 남은 날이 줄어드는 것만 보지 않고, 함께한 날이 쌓이는 것도 본다.
//
// 세어 둔 것(소중한 사람 · 반려동물 · 여행 …) 화면에 한 줄로 선다: 쌓인 날 수 · 오늘 남기기.
// 하루는 하루다 — 같은 날을 두 번 남기면 한 줄만 고친다. 한 줄 메모는 안 써도 된다.
// 저장은 그 세어 둔 것 안(`RemainingItem.moments`)에 같이 한다. 따로 저장하는 곳은 없다.

import SwiftUI

/// 세어 둔 것 화면의 "쌓인 날" 줄
struct TogetherRow: View {
    let item: RemainingItem
    @AppStorage(RemainingItemStore.key) private var itemsData = Data()
    @State private var showKeep = false
    @State private var showList = false

    var body: some View {
        let keptToday = item.hasMoment(on: Date())
        HStack(spacing: 12) {
            Button { showList = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.ember)
                    Text("쌓인 날 \(item.kept.count)일")
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(String(localized: "남긴 날 보기"))

            Spacer(minLength: 0)

            Button { showKeep = true } label: {
                Label(keptToday ? String(localized: "오늘 남겼어요") : String(localized: "오늘 남기기"),
                      systemImage: keptToday ? "checkmark" : "plus")
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundColor(keptToday ? .ember : .onEmber)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(keptToday ? Color.ember.opacity(0.12) : Color.ember))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.ink.opacity(0.03)))
        .sheet(isPresented: $showKeep) {
            KeepDaySheet(note: item.kept.first { Calendar.current.isDateInToday($0.date) }?.note ?? "") { day, note in
                update { $0.keep(day, note: note) }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showList) {
            KeptDaysList(moments: item.kept) { id in update { $0.forget(id) } }
        }
    }

    private func update(_ change: (inout RemainingItem) -> Void) {
        // 화면이 들고 있는 값이 아니라 저장된 최신 값을 고친다
        var current = RemainingItemStore.decode(itemsData).first { $0.id == item.id } ?? item
        change(&current)
        withAnimation { itemsData = RemainingItemStore.upsert(current, in: itemsData) }
    }
}

/// 하루 남기기 — 날짜(오늘까지) · 한 줄
private struct KeepDaySheet: View {
    @State var note: String
    var onKeep: (Date, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var day = Date()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                DatePicker(String(localized: "날짜"), selection: $day, in: ...Date(), displayedComponents: .date)
                    .font(.system(.body, design: .serif))
                TextField(String(localized: "한 줄 남기기 (안 써도 돼요)"), text: $note, axis: .vertical)
                    .font(.system(.body, design: .serif))
                    .lineLimit(1...3)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.ink.opacity(0.04)))
                Spacer(minLength: 0)
                Button {
                    onKeep(day, note)
                    dismiss()
                } label: {
                    Text("남기기")
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .foregroundColor(.onEmber)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.ember))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .navigationTitle(String(localized: "하루 남기기"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "취소")) { dismiss() }
                }
            }
        }
        .tint(.ember)
    }
}

/// 쌓인 날 — 최근 것부터. 밀어서 지운다.
private struct KeptDaysList: View {
    @State var moments: [RemainingItem.Moment]
    var onForget: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if moments.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "아직 쌓인 날이 없어요"), systemImage: "flame")
                    } description: {
                        Text("함께한 하루를 남기면 여기에 불씨로 쌓여요.")
                    }
                } else {
                    List {
                        ForEach(moments) { m in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(m.date, format: .dateTime.year().month().day().weekday())
                                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                                    .foregroundColor(.ember)
                                if let note = m.note {
                                    Text(note)
                                        .font(.system(.body, design: .serif))
                                        .foregroundColor(.ink)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete { offsets in
                            for i in offsets { onForget(moments[i].id) }
                            moments.remove(atOffsets: offsets)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "쌓인 날"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "닫기")) { dismiss() }
                }
            }
        }
        .tint(.ember)
    }
}
