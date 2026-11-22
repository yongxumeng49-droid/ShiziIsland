import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var corpus: CorpusStore
    @EnvironmentObject private var progress: ProgressStore
    @Binding var path: [AppRoute]
    @State private var hint: String?

    var body: some View {
        AdaptiveScreen(imageName: "HomeBackground", dim: 0.06, usesHomePair: true) {
            GeometryReader { geo in
                let landscape = geo.size.width > geo.size.height
                let due = progress.dueCount(in: corpus)
                ZStack(alignment: .bottom) {
                    if landscape {
                        landscapeLayout(due: due, width: geo.size.width)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    } else {
                        ScrollView {
                            portraitLayout(due: due, width: geo.size.width)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .padding(.bottom, 20)
                        }
                    }
                    if let hint {
                        HintBanner(text: hint)
                            .padding(.bottom, 12)
                            .task(id: hint) {
                                try? await Task.sleep(nanoseconds: 1_800_000_000)
                                if self.hint == hint { self.hint = nil }
                            }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func landscapeLayout(due: Int, width: CGFloat) -> some View {
        let column = min(340, max(250, width * 0.30))
        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                if due > 0 {
                    reviewCard(due: due)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
                header
                statCard
                if due == 0 {
                    reviewCard(due: due)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: column, alignment: .top)
            stageBoard
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func portraitLayout(due: Int, width: CGFloat) -> some View {
        let cardWidth = max(width - 32, 1)
        return VStack(alignment: .leading, spacing: 14) {
            header
            statRow
            reviewCard(due: due)
                .frame(height: cardWidth * (due > 0 ? 0.72 : 0.58))
            progressBar
            ForEach(corpus.stages) { stage in
                stageCard(stage)
                    .frame(height: cardWidth * 0.48)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("识字小岛")
                .font(Theme.ui(40, .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("看见字，听见字，认出字")
                .font(Theme.ui(18, .semibold))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var statRow: some View {
        HStack(spacing: 10) {
            statPill(icon: "sun.max.fill", tint: Theme.coral, title: streakTitle, detail: streakDetail)
            statPill(icon: "star.fill", tint: Theme.gold, title: "\(progress.totalStars()) 颗星", detail: learnedDetail)
        }
    }

    private var statCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            statPill(icon: "sun.max.fill", tint: Theme.coral, title: streakTitle, detail: streakDetail)
            statPill(icon: "star.fill", tint: Theme.gold, title: "\(progress.totalStars()) 颗星", detail: learnedDetail)
            progressBar
        }
    }

    private var progressBar: some View {
        let learned = progress.learnedCount(in: corpus)
        let total = max(corpus.playableCount, 1)
        return VStack(alignment: .leading, spacing: 6) {
            Text("认识了 \(learned) / \(corpus.playableCount) 个字")
                .font(Theme.ui(15, .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            FractionBar(fraction: CGFloat(learned) / CGFloat(total), height: 10)
        }
        .padding(12)
        .background(Theme.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var streakTitle: String {
        let streak = progress.displayedStreak()
        return streak > 0 ? "连续 \(streak) 天" : "今天出发"
    }

    private var streakDetail: String {
        if progress.practicedToday() { return "今天已经学过" }
        if progress.displayedStreak() > 0 { return "今天还没开始" }
        return "学完一课就记上一天"
    }

    private var learnedDetail: String {
        "认识了 \(progress.learnedCount(in: corpus)) 个字"
    }

    private func statPill(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.ui(17, .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(detail)
                    .font(Theme.ui(13, .medium))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func reviewCard(due: Int) -> some View {
        Button {
            if due > 0 {
                path.append(.review)
            } else {
                hint = "先去认几个新字吧"
            }
        } label: {
            ZStack(alignment: .bottomLeading) {
                ArtworkFill(name: "ReviewOtter")
                LinearGradient(
                    colors: [Color.black.opacity(0.02), Color.black.opacity(0.62)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日复习")
                        .font(Theme.ui(28, .bold))
                        .foregroundStyle(Color.white)
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    Text(due > 0 ? "有 \(due) 个字想再见面" : "今天的字都记得牢")
                        .font(Theme.ui(16, .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(due > 0 ? (due > 8 ? "先认 8 个" : "开始复习") : "先去小岛认新字")
                        .font(Theme.ui(15, .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.card, in: Capsule())
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.7), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var stageBoard: some View {
        let stages = corpus.stages
        return VStack(spacing: 12) {
            if stages.count >= 4 {
                HStack(spacing: 12) {
                    stageCard(stages[0])
                    stageCard(stages[1])
                }
                .frame(maxHeight: .infinity)
                HStack(spacing: 12) {
                    stageCard(stages[2])
                    stageCard(stages[3])
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func stageCard(_ stage: StageCurriculum) -> some View {
        let unlocked = progress.isStageUnlocked(stage.stage, in: corpus)
        let done = progress.completedIslandCount(stage)
        let total = stage.islands.count
        return Button {
            if unlocked {
                path.append(.stage(stage.stage))
            } else {
                hint = "先完成上一阶段"
            }
        } label: {
            ZStack(alignment: .bottomLeading) {
                ArtworkFill(
                    name: StageArt.imageName(stage.stage),
                    saturation: unlocked ? 1 : 0.35,
                    brightness: unlocked ? 0 : -0.06
                )
                LinearGradient(
                    colors: [Color.black.opacity(0.05), Color.black.opacity(0.68)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(StageInfo.name(stage.stage))
                            .font(Theme.ui(30, .bold))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 8)
                        if unlocked {
                            Text("\(done)/\(total) 岛")
                                .font(Theme.ui(14, .bold))
                                .foregroundStyle(Color.white)
                                .lineLimit(1)
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.white)
                                .padding(8)
                                .background(Color.black.opacity(0.35), in: Circle())
                        }
                    }
                    Text(StageInfo.detail(stage.stage))
                        .font(Theme.ui(15, .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                    FractionBar(
                        fraction: total == 0 ? 0 : CGFloat(done) / CGFloat(total),
                        tint: Color.white.opacity(0.95)
                    )
                }
                .padding(14)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.75), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
