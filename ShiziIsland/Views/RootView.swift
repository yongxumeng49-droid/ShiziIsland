import SwiftUI

enum AppRoute: Hashable {
    case stage(Int)
    case island(String)
    case lesson(String)
    case review
}

struct RootView: View {
    @EnvironmentObject private var corpus: CorpusStore
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let message = corpus.loadError {
                    LoadFailureView(message: message)
                } else {
                    HomeView(path: $path)
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .stage(let stage):
                    IslandPathView(stage: stage, path: $path)
                case .island(let id):
                    LessonPathView(islandID: id, path: $path)
                case .lesson(let id):
                    LessonPlayerView(lessonID: id, path: $path)
                        .id(id)
                case .review:
                    ReviewSessionView()
                }
            }
        }
    }
}

struct LoadFailureView: View {
    var message: String

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 16) {
                Text("识字小岛")
                    .font(Theme.ui(40, .bold))
                    .foregroundStyle(Theme.ink)
                Text(message)
                    .font(Theme.ui(22, .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }
}
