// BurningParchmentWidgetsBundle.swift
// 위젯 번들 (일간 / 주간 / 월간 / 연간 / 데드라인)

import SwiftUI
import WidgetKit

@main
struct BurningParchmentWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BedtimeHomeWidget()
        WeeklyParchmentWidget()
        MonthlyParchmentWidget()
        YearlyParchmentWidget()
        DeadlineWidget()
    }
}
