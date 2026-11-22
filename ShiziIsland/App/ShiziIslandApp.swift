import SwiftUI

@main
struct ShiziIslandApp: App {
    @StateObject private var corpus = CorpusStore()
    @StateObject private var progress = ProgressStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(corpus)
                .environmentObject(progress)
                .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
                .preferredColorScheme(.light)
        }
    }
}
