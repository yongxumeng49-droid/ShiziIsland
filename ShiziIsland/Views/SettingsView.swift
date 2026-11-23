import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speech = SpeechService()

    var body: some View {
        AdaptiveScreen(imageName: "HomeBackground", dim: 0.34, usesHomePair: true) {
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        voiceSection
                        planSection
                        aboutSection
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 16)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { speech.voice = settings.voice }
        .onDisappear { speech.stop() }
    }

    private var topBar: some View {
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
                Text("设置")
                    .font(Theme.ui(28, .bold))
                    .foregroundStyle(Theme.ink)
                Text("给爸爸妈妈看也合适")
                    .font(Theme.ui(16, .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.card.opacity(0.92))
    }

    private var voiceSection: some View {
        SettingsCard(title: "声音", footnote: "点喇叭听一段样音。字和表扬如果还没有配好录音，就用这台 iPad 自己的普通话，不需要联网。") {
            ForEach(StudyVoice.allCases) { voice in
                HStack(spacing: 12) {
                    Button {
                        settings.voice = voice
                        speech.voice = voice
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: settings.voice == voice ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(settings.voice == voice ? Theme.sea : Theme.inkSoft)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(voice.title)
                                    .font(Theme.ui(22, .bold))
                                    .foregroundStyle(Theme.ink)
                                Text(voice.detail)
                                    .font(Theme.ui(15, .medium))
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    Button {
                        settings.voice = voice
                        speech.voice = voice
                        speech.playPreview(voice)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Theme.card)
                            .frame(width: 52, height: 52)
                            .background(Theme.sea, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("听\(voice.title)的样音")
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var planSection: some View {
        SettingsCard(title: "每日计划", footnote: "只算新字。已经学过的课、小岛测验和今日复习都不占名额。今天的新课学完了，要到明天才能再开新课。") {
            ForEach(DailyNewCharacterPlan.allCases) { plan in
                Button {
                    settings.dailyPlan = plan
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: settings.dailyPlan == plan ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(settings.dailyPlan == plan ? Theme.sea : Theme.inkSoft)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.title)
                                .font(Theme.ui(22, .bold))
                                .foregroundStyle(Theme.ink)
                            Text(plan.detail)
                                .font(Theme.ui(15, .medium))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var aboutSection: some View {
        SettingsCard(title: "关于", footnote: "进度只留在这台 iPad 上。删掉应用，星星和复习记录会一起消失。") {
            VStack(alignment: .leading, spacing: 8) {
                Text("识字小岛")
                    .font(Theme.ui(24, .bold))
                    .foregroundStyle(Theme.ink)
                Text("给小学一、二年级孩子看字、听读音、做练习。不需要账号，也不需要联网。")
                    .font(Theme.ui(17, .medium))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Text("版本 1.0 · MIT")
                    .font(Theme.ui(15, .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    var title: String
    var footnote: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.ui(20, .bold))
                .foregroundStyle(Theme.seaDeep)
            content()
            Text(footnote)
                .font(Theme.ui(14, .medium))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card.opacity(0.95), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
