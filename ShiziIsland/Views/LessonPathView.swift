import SwiftUI

struct LessonPathView: View {
    var islandID: String
    @Binding var path: [AppRoute]
    @EnvironmentObject private var corpus: CorpusStore
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @State private var hint: String?

    var body: some View {
        AdaptiveScreen(
            imageName: StageArt.imageName(corpus.island(id: islandID)?.stage ?? 1),
            dim: 0.25
        ) {
        ZStack(alignment: .bottom) {
            if let island = corpus.island(id: islandID) {
                VStack(spacing: 0) {
                    topBar(island)
                    ScrollView {
                        lessonList(island)
                            .padding(.bottom, 28)
                    }
                }
            } else {
                Text("这座小岛找不到了")
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

    private func topBar(_ island: IslandCurriculum) -> some View {
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
                Text("第 \(island.number) 岛")
                    .font(Theme.ui(28, .bold))
                    .foregroundStyle(Theme.ink)
                Text("\(StageInfo.name(island.stage)) · \(island.characters.count) 个字")
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

    private func lessonList(_ island: IslandCurriculum) -> some View {
        let columns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 16)]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(island.lessons) { lesson in
                lessonCard(lesson)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }

    private func lessonCard(_ lesson: LessonCurriculum) -> some View {
        let unlocked = progress.isLessonUnlocked(lesson, in: corpus)
        let completed = progress.isCompleted(lesson.id)
        let tint = lesson.isCheckpoint ? Theme.coral : Theme.stageColor(lesson.stage)
        let title = lesson.isCheckpoint ? "小岛测验" : "第 \(lesson.number) 课"
        let sample = lesson.isCheckpoint
            ? "把这一岛认过一遍"
            : lesson.characters.map(\.char).joined(separator: " ")
        return Button {
            if unlocked {
                path.append(.lesson(lesson.id))
            } else if lesson.isCheckpoint {
                hint = "先把这一岛的课学完"
            } else {
                hint = "先完成上一课"
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(Theme.ui(22, .bold))
                        .foregroundStyle(unlocked ? Theme.ink : Theme.locked)
                    Spacer()
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Theme.locked)
                    } else if completed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.good)
                    }
                }
                Text(sample)
                    .font(lesson.isCheckpoint ? Theme.ui(16, .medium) : Theme.glyph(28))
                    .foregroundStyle(unlocked ? Theme.ink : Theme.locked)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 40)
                if unlocked {
                    StarRow(filled: progress.stars(for: lesson.id))
                } else {
                    Text("还没打开")
                        .font(Theme.ui(14, .semibold))
                        .foregroundStyle(Theme.locked)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .bottomLeading)
            .background {
                ZStack(alignment: .bottom) {
                    ArtworkFill(
                        name: StageArt.imageName(lesson.stage),
                        saturation: unlocked ? 1 : 0.3
                    )
                    LinearGradient(
                        colors: [Theme.card.opacity(0.15), Theme.card.opacity(0.94)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(unlocked ? tint.opacity(0.8) : Theme.locked.opacity(0.5), lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
    }
}
