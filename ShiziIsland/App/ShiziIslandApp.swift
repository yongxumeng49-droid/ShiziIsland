import SwiftUI

@main
struct ShiziIslandApp: App {
    @StateObject private var corpus = CorpusStore()
    @StateObject private var progress = ProgressStore()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(corpus)
                .environmentObject(progress)
                .environmentObject(settings)
                .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
                .preferredColorScheme(.light)
        }
    }
}
