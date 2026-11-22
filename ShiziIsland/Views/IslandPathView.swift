import SwiftUI

struct IslandPathView: View {
    var stage: Int
    @Binding var path: [AppRoute]
    @EnvironmentObject private var corpus: CorpusStore
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @State private var hint: String?

    var body: some View {
        AdaptiveScreen(imageName: StageArt.imageName(stage), dim: 0.22) {
        ZStack(alignment: .bottom) {
            if let map = corpus.stage(stage) {
                VStack(spacing: 0) {
                    topBar(map)
                    ScrollView {
                        pathBody(map)
                            .padding(.vertical, 12)
                            .padding(.bottom, 36)
                    }
                }
            } else {
                Text("这一阶段还没有小岛")
                    .font(Theme.ui(22, .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            if let hint {
                HintBanner(text: hint)
                    .padding(.bottom, 20)
                    .task(id: hint) {
                        try? await Task.sleep(nanoseconds: 1_600_000_000)
                        if self.hint == hint { self.hint = nil }
                    }
            }
        }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func topBar(_ map: StageCurriculum) -> some View {
        HStack(spacing: 16) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 52, height: 52)
                    .background(Theme.card, in: Circle())
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(StageInfo.name(map.stage))
                    .font(Theme.ui(28, .bold))
                    .foregroundStyle(Theme.ink)
                Text("\(progress.completedIslandCount(map)) / \(map.islands.count) 座岛")
                    .font(Theme.ui(16, .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.card.opacity(0.9))
    }

    private func pathBody(_ map: StageCurriculum) -> some View {
        ZStack {
            Capsule()
                .fill(Theme.stageColor(map.stage).opacity(0.18))
                .frame(width: 12)
                .padding(.vertical, 54)
            VStack(spacing: 10) {
                if map.islands.isEmpty {
                    Text("这一阶段没有要认的字")
                        .font(Theme.ui(20, .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.top, 40)
                }
                ForEach(Array(map.islands.enumerated()), id: \.element.id) { index, island in
                    islandNode(island)
                        .offset(x: index.isMultiple(of: 2) ? -88 : 88)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func islandNode(_ island: IslandCurriculum) -> some View {
        let unlocked = progress.isIslandUnlocked(island, in: corpus)
        let completed = progress.isIslandCompleted(island)
        let sample = island.characters.prefix(3).map(\.char).joined(separator: " ")
        return Button {
            if unlocked {
                path.append(.island(island.id))
            } else {
                hint = "先走完前面的小岛"
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Image(StageArt.imageName(island.stage))
                        .resizable()
                        .scaledToFill()
                        .saturation(unlocked ? 1 : 0.25)
                        .frame(width: 108, height: 108)
                        .clipped()
                        .clipShape(Circle())
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 108, height: 108)
                    if unlocked {
                        VStack(spacing: 0) {
                            Text("\(island.number)")
                                .font(Theme.ui(32, .bold))
                            Text("岛")
                                .font(Theme.ui(14, .semibold))
                        }
                        .foregroundStyle(Color.white)
                        .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                    if completed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Theme.gold)
                            .background(Circle().fill(Theme.card).padding(2))
                            .offset(x: 40, y: 38)
                    }
                }
                Text("第 \(island.number) 岛")
                    .font(Theme.ui(18, .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 8)
                    .background(Theme.card.opacity(0.92), in: Capsule())
                Text(sample)
                    .font(Theme.glyph(18))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
                if unlocked {
                    StarRow(filled: min(3, progress.islandStars(island) == 0 ? 0 : starLevel(island)), total: 3, size: 14)
                }
            }
            .frame(width: 150)
        }
        .buttonStyle(.plain)
    }

    private func starLevel(_ island: IslandCurriculum) -> Int {
        let maxStars = max(island.lessons.count * 3, 1)
        let earned = progress.islandStars(island)
        let ratio = Double(earned) / Double(maxStars)
        if ratio >= 0.9 { return 3 }
        if ratio >= 0.5 { return 2 }
        if earned > 0 { return 1 }
        return 0
    }
}
