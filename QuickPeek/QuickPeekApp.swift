import SwiftUI

@main
struct QuickPeekApp: App {
    @StateObject private var viewModel = TrackerViewModel()
    
    var body: some Scene {
        MenuBarExtra("QuickPeek", systemImage: "chart.bar.xaxis") {
            ContentView()
                .environmentObject(viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
