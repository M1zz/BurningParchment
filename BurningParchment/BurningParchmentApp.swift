// BurningParchmentApp.swift
// 취침시간 카운트다운 앱 - 불타는 양피지
// 밤 9시 이후 취침시간까지 남은 시간을 양피지가 타들어가는 효과로 보여줍니다.

import SwiftUI

@main
struct BurningParchmentApp: App {
    @StateObject private var bedtimeManager = BedtimeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bedtimeManager)
                .preferredColorScheme(.dark)
        }
    }
}
